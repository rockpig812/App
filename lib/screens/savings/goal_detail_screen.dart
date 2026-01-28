import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/goal_model.dart';
import '../../providers/session_provider.dart';
import '../../services/goal_service.dart';

class GoalDetailScreen extends StatefulWidget {
  final String goalId;

  const GoalDetailScreen({super.key, required this.goalId});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  final _goalService = GoalService();
  bool _depositing = false;
  String? _error;

  String _formatMoney(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);

  Future<void> _showDepositDialog(GoalModel goal) async {
    final controller = TextEditingController();
    final session = context.read<SessionProvider>();
    final coupleId = session.profile?.currentCoupleId;
    final userId = session.firebaseUser?.uid;
    if (coupleId == null || userId == null) return;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Deposit money'),
          content: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _depositing
                  ? null
                  : () async {
                      final amount = double.tryParse(controller.text.trim());
                      if (amount == null || amount <= 0) {
                        setState(() {
                          _error = 'Please enter a valid amount.';
                        });
                        return;
                      }

                      setState(() {
                        _depositing = true;
                        _error = null;
                      });

                      try {
                        await _goalService.addContribution(
                          coupleId: coupleId,
                          goalId: widget.goalId,
                          userId: userId,
                          amount: amount,
                          date: DateTime.now(),
                        );
                        if (!mounted) return;
                        Navigator.of(context).pop();
                      } catch (e) {
                        setState(() => _error = e.toString());
                      } finally {
                        if (mounted) {
                          setState(() => _depositing = false);
                        }
                      }
                    },
              child: _depositing
                  ? const Text('Saving...')
                  : const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final coupleId = session.profile?.currentCoupleId;
    if (coupleId == null) {
      return const Scaffold(
        body: Center(child: Text('No couple selected.')),
      );
    }

    final goalDocStream = FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('goals')
        .doc(widget.goalId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Goal details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: goalDocStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Goal not found.'));
          }
          final data = snapshot.data!.data()!;
          final goal = GoalModel.fromMap(data, snapshot.data!.id);

          final progress = (goal.targetAmount == 0)
              ? 0.0
              : (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
          final remaining = (goal.targetAmount - goal.currentAmount).clamp(0.0, double.infinity);
          final daysLeft = (goal.deadline == null)
              ? null
              : goal.deadline!
                  .difference(DateTime.now())
                  .inDays;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  goal.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                Center(
                  child: SizedBox(
                    width: 160,
                    height: 160,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 10,
                        ),
                        Center(
                          child: Text(
                            '${(progress * 100).round()}%',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Saved: \$${_formatMoney(goal.currentAmount)} / \$${_formatMoney(goal.targetAmount)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Remaining: \$${_formatMoney(remaining)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                if (daysLeft != null)
                  Text(
                    daysLeft >= 0
                        ? 'Days left: $daysLeft'
                        : 'Deadline passed ${-daysLeft} days ago',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  Text(
                    'No deadline set',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _depositing ? null : () => _showDepositDialog(goal),
                  icon: const Icon(Icons.savings),
                  label: const Text('Deposit money'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                Expanded(
                  child: _ContributionsList(
                    coupleId: coupleId,
                    goalId: widget.goalId,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ContributionsList extends StatelessWidget {
  final String coupleId;
  final String goalId;

  const _ContributionsList({
    required this.coupleId,
    required this.goalId,
  });

  @override
  Widget build(BuildContext context) {
    final goalService = GoalService();

    return StreamBuilder(
      stream: goalService.watchContributions(coupleId, goalId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Failed to load contributions: ${snapshot.error}'));
        }

        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('No deposits yet.'));
        }

        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final c = list[index];
            final date = c.date;
            final dateText = '${date.year}-${date.month}-${date.day}';
            return ListTile(
              leading: const Icon(Icons.savings),
              title: Text('\$${c.amount.toStringAsFixed(2)}'),
              subtitle: Text(dateText),
            );
          },
        );
      },
    );
  }
}

