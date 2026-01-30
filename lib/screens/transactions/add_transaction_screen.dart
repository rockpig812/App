import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../repositories/transaction_repository.dart';
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

  // true = me, false = partner
  bool _paidByMe = true;
  String _selectedCategory = 'food'; // Default for Split Bill

  final _txRepo = TransactionRepository();

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
    final myUid = session.firebaseUser?.uid;
    final coupleId = session.profile?.currentCoupleId;
    if (myUid == null || coupleId == null) return;

    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());

    if (title.isEmpty || amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid title and amount.');
      return;
    }

    // 找 partner uid（從 couple doc 的 user_ids 取另一個）
    // MVP：我們直接從 Firestore 讀 couple 一次（避免額外 provider 依賴）
    final coupleSnap = await session.watchCurrentCoupleDoc().first; // one-shot
    final userIds = List<String>.from(coupleSnap.data()?['user_ids'] ?? []);
    final partnerUid = userIds.firstWhere((u) => u != myUid, orElse: () => myUid);

    final payerId = _paidByMe ? myUid : partnerUid;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _txRepo.addTransaction(
        coupleId: coupleId,
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
                const SizedBox(height: 12),
                Text('Category', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                CategorySelector(
                  selectedCategoryId: _selectedCategory,
                  onCategorySelected: (val) => setState(() => _selectedCategory = val),
                ),
                const SizedBox(height: 16),
                Text('Who paid?', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Me')),
                    ButtonSegment(value: false, label: Text('Partner')),
                  ],
                  selected: {_paidByMe},
                  onSelectionChanged: (s) {
                    setState(() => _paidByMe = s.first);
                  },
                ),
                const SizedBox(height: 16),
                // Split type: 固定 50/50（MVP 隱藏邏輯，只顯示提示）
                Text(
                  'Split: Equal (50/50)',
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
                    onPressed: (_saving || session.profile?.currentCoupleId == null)
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

