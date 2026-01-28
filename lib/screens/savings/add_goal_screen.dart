import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../services/goal_service.dart';

class AddGoalScreen extends StatefulWidget {
  const AddGoalScreen({super.key});

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  final _titleController = TextEditingController();
  final _targetAmountController = TextEditingController();
  DateTime? _deadline;

  bool _saving = false;
  String? _error;

  final _goalService = GoalService();

  @override
  void dispose() {
    _titleController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      initialDate: _deadline ?? now,
    );
    if (picked == null) return;
    setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    final session = context.read<SessionProvider>();
    final coupleId = session.profile?.currentCoupleId;
    if (coupleId == null) return;

    final title = _titleController.text.trim();
    final target = double.tryParse(_targetAmountController.text.trim());

    if (title.isEmpty || target == null || target <= 0) {
      setState(() => _error = 'Please enter a valid title and target amount.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _goalService.addGoal(
        coupleId: coupleId,
        title: title,
        targetAmount: target,
        deadline: _deadline,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Goal')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Goal title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _targetAmountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Target amount',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDeadline,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    _deadline == null
                        ? 'Pick deadline (optional)'
                        : 'Deadline: ${_deadline!.year}-${_deadline!.month}-${_deadline!.day}',
                  ),
                ),
                const Spacer(),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const Text('Saving...')
                        : const Text('Create goal'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

