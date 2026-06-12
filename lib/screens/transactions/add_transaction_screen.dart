import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/session_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/category_selector.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _date = DateTime.now();

  bool _saving = false;
  String? _error;

  // For MVP: Default to current user. In a group, we might want a list.
  String? _selectedPayerId;
  String _selectedCategory = 'food';

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDate: _date,
    );
    if (picked == null) return;
    setState(() => _date = picked);
  }

  Future<void> _save() async {
    final session = context.read<SessionProvider>();
    final txProvider = context.read<TransactionProvider>();
    final myUid = session.firebaseUser?.uid;
    final roomId = session.profile?.lastActiveRoomId;
    if (myUid == null || roomId == null) return;

    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());

    if (title.isEmpty || amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid title and amount.');
      return;
    }

    final payerId = _selectedPayerId ?? myUid;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await txProvider.addTransaction(
        roomId: roomId,
        payerId: payerId,
        amount: amount,
        title: title,
        date: _date,
        category: _selectedCategory,
        splitType: 'equal',
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
    final session = context.watch<SessionProvider>();
    final myUid = session.firebaseUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
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
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month),
                  label: Text('Date: ${_date.year}-${_date.month}-${_date.day}'),
                ),
                const SizedBox(height: 16),
                Text('Category', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                CategorySelector(
                  selectedCategoryId: _selectedCategory,
                  onCategorySelected: (val) => setState(() => _selectedCategory = val),
                ),
                const SizedBox(height: 16),
                
                // For MVP: Simple toggle between Me and "Someone Else" (Partner)
                // In the future, this should be a list of room members.
                Text('Who paid?', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: session.watchCurrentRoomDoc(),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data();
                    final userIds = List<String>.from(data?['user_ids'] ?? []);
                    
                    if (userIds.length <= 1) {
                      return const Text('Paid by: Me (Personal Mode)');
                    }

                    return SegmentedButton<String>(
                      segments: [
                        const ButtonSegment(value: 'me', label: Text('Me')),
                        const ButtonSegment(value: 'other', label: Text('Someone Else')),
                      ],
                      selected: {(_selectedPayerId == null || _selectedPayerId == myUid) ? 'me' : 'other'},
                      onSelectionChanged: (s) {
                        if (s.first == 'me') {
                          setState(() => _selectedPayerId = myUid);
                        } else {
                          // Pick the first non-me user as the "other" for now
                          final otherUid = userIds.firstWhere((u) => u != myUid, orElse: () => myUid as String);
                          setState(() => _selectedPayerId = otherUid);
                        }
                      },
                    );
                  },
                ),

                const SizedBox(height: 16),
                Text(
                  'Split: Equal among all members',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (_saving || !session.isJoinedRoom)
                        ? null
                        : _save,
                    icon: const Icon(Icons.save),
                    label: _saving ? const Text('Saving...') : const Text('Save'),
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
