import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/goal_model.dart';
import '../models/couple_model.dart'; // Needed to check balance for achieving
import '../services/firestore_service.dart';
import '../providers/session_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({Key? key, required this.coupleId}) : super(key: key);

  final String coupleId;

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Goals'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Achieved'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: firestoreService.watchGoals(coupleId),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('Error'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final docs = snapshot.data!.docs;
            final allGoals = docs.map((doc) => GoalModel.fromMap(doc.data(), doc.id)).toList();

            final activeGoals = allGoals.where((g) => g.status == 'active').toList();
            final achievedGoals = allGoals.where((g) => g.status == 'achieved').toList();

            // Sort Active by creation or priority? Default is fine.
            // Sort Achieved by achievedDate desc?
            achievedGoals.sort((a, b) {
              if (a.achievedDate == null || b.achievedDate == null) return 0;
              return b.achievedDate!.compareTo(a.achievedDate!);
            });

            return TabBarView(
              children: [
                _buildGoalList(context, activeGoals),
                _buildGoalList(context, achievedGoals),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddGoalDialog(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildGoalList(BuildContext context, List<GoalModel> goals) {
    if (goals.isEmpty) {
      return const Center(child: Text('No goals here'));
    }
    return ListView.builder(
      itemCount: goals.length,
      itemBuilder: (context, index) {
        return _GoalCard(goal: goals[index], coupleId: coupleId);
      },
    );
  }

  void _showAddGoalDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AddGoalDialog(coupleId: coupleId),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final GoalModel goal;
  final String coupleId;

  const _GoalCard({Key? key, required this.goal, required this.coupleId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isAchieved = goal.status == 'achieved';
    final firestoreService = context.read<FirestoreService>();
    final user = context.read<SessionProvider>().firebaseUser;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isAchieved ? Colors.green[50] : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    goal.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      decoration: isAchieved ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                Text(
                  '\$${goal.targetAmount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isAchieved) ...[
                  const Chip(
                    label: Text('Achieved', style: TextStyle(color: Colors.white)),
                    backgroundColor: Colors.green,
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => _undoAchieve(context, firestoreService, user!.uid),
                    child: const Text('Undo'),
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: () => _achieveGoal(context, firestoreService, user!.uid),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Achieve'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _achieveGoal(BuildContext context, FirestoreService service, String userId) async {
    // 1. Check Balance (Optimistic check, real check in transaction)
    try {
      final coupleSnap = await service.firestore.collection('couples').doc(coupleId).get();
      final couple = CoupleModel.fromMap(coupleSnap.data()!, coupleSnap.id);
      
      if (couple.jointPotBalance < goal.targetAmount) {
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Insufficient funds in the Pot!')),
          );
        }
        return;
      }

      await service.achieveGoal(
        coupleId: coupleId,
        goalId: goal.id,
        targetAmount: goal.targetAmount,
        goalTitle: goal.title,
        userId: userId,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _undoAchieve(BuildContext context, FirestoreService service, String userId) async {
    try {
      await service.undoAchieveGoal(
        coupleId: coupleId,
        goalId: goal.id,
        amount: goal.targetAmount,
        goalTitle: goal.title,
        userId: userId,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _AddGoalDialog extends StatefulWidget {
  final String coupleId;
  const _AddGoalDialog({Key? key, required this.coupleId}) : super(key: key);

  @override
  State<_AddGoalDialog> createState() => _AddGoalDialogState();
}

class _AddGoalDialogState extends State<_AddGoalDialog> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Goal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Goal Title'),
          ),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(labelText: 'Target Amount'),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading ? const CircularProgressIndicator() : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final title = _titleController.text;
    final amountText = _amountController.text;

    if (title.isEmpty || amountText.isEmpty) return;
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) return;

    setState(() => _isLoading = true);
    
    try {
      final service = context.read<FirestoreService>();
      final goal = GoalModel(
        id: '',
        coupleId: widget.coupleId,
        title: title,
        targetAmount: amount,
        status: 'active',
      );

      await service.addGoal(widget.coupleId, goal.toMap());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
