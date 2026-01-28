import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/goal_model.dart';
import '../../providers/session_provider.dart';
import '../../services/goal_service.dart';
import 'add_goal_screen.dart';
import 'goal_detail_screen.dart';

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  String _formatMoney(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final coupleId = session.profile?.currentCoupleId;

    if (coupleId == null) {
      return const Center(child: Text('No couple selected.'));
    }

    final goalService = GoalService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Goals'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddGoalScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Goal'),
      ),
      body: StreamBuilder<List<GoalModel>>(
        stream: goalService.watchGoals(coupleId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load goals: ${snapshot.error}'));
          }

          final goals = snapshot.data ?? [];
          if (goals.isEmpty) {
            return const Center(
              child: Text('No goals yet. Tap the + button to create one.'),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 3 / 2,
            ),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index];
              final progress = (goal.targetAmount == 0)
                  ? 0.0
                  : (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
              final percent = (progress * 100).round();

              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GoalDetailScreen(goalId: goal.id),
                    ),
                  );
                },
                child: Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$percent% achieved',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Spacer(),
                        Text(
                          '\$${_formatMoney(goal.currentAmount)} / \$${_formatMoney(goal.targetAmount)}',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

