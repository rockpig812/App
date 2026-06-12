import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/savings_transaction_model.dart';
import '../providers/joint_pot_provider.dart';
import '../providers/session_provider.dart';
import '../models/category_model.dart';
import '../widgets/category_selector.dart';

class JointPotScreen extends StatelessWidget {
  const JointPotScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JointPotProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Joint Pot'),
      ),
      body: _buildBody(context, provider),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTransactionDialog(context),
        label: const Text('Deposit / Withdraw'),
        icon: const Icon(Icons.swap_horiz),
      ),
    );
  }

  Widget _buildBody(BuildContext context, JointPotProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(child: Text('Error: ${provider.error}'));
    }

    if (provider.room == null) {
      return const Center(child: Text('Room not found'));
    }

    return Column(
      children: [
        const SizedBox(height: 20),
        // Balance Circle
        _buildBalanceCircle(provider.currentBalance),
        const SizedBox(height: 20),
        // Transaction List
        Expanded(
          child: _buildTransactionList(context, provider),
        ),
      ],
    );
  }

  Widget _buildBalanceCircle(double balance) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blueAccent.withOpacity(0.1),
        border: Border.all(color: Colors.blueAccent, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Total Balance',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Text(
            '\$${balance.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(BuildContext context, JointPotProvider provider) {
    final transactions = provider.transactions;

    if (transactions.isEmpty) {
      return const Center(child: Text('No transactions yet'));
    }

    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        final isDeposit = transaction.amount >= 0;
        final category = TransactionCategory.getById(transaction.category);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: category.color.withOpacity(0.2),
            child: Icon(category.icon, color: category.color),
          ),
          title: Text(transaction.title),
          subtitle: Text(DateFormat('yyyy/MM/dd HH:mm').format(transaction.date)),
          trailing: Text(
            '${isDeposit ? '+' : ''}${transaction.amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: isDeposit ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          onLongPress: () => _showEditDeleteDialog(context, provider, transaction),
        );
      },
    );
  }

  void _showTransactionDialog(BuildContext context, {SavingsTransactionModel? transaction}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _TransactionBottomSheet(
        transaction: transaction,
      ),
    );
  }

  void _showEditDeleteDialog(
      BuildContext context, JointPotProvider provider, SavingsTransactionModel transaction) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _showTransactionDialog(context, transaction: transaction);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, provider, transaction);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, JointPotProvider provider, SavingsTransactionModel transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text('Are you sure you want to delete "${transaction.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              try {
                await provider.deleteTransaction(transaction.id);
              } catch (e) {
                if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _TransactionBottomSheet extends StatefulWidget {
  final SavingsTransactionModel? transaction; // If null, create new mode

  const _TransactionBottomSheet({
    Key? key,
    this.transaction,
  }) : super(key: key);

  @override
  State<_TransactionBottomSheet> createState() => _TransactionBottomSheetState();
}

class _TransactionBottomSheetState extends State<_TransactionBottomSheet> {
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'household'; // Default for Pot
  bool _isDeposit = true;
  bool _isLoading = false;
  bool _isRecurring = false;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final tx = widget.transaction!;
      _amountController.text = tx.amount.abs().toString();
      _titleController.text = tx.title;
      _selectedDate = tx.date;
      _isDeposit = tx.amount >= 0;
      _selectedCategory = tx.category;
      _isRecurring = tx.isRecurring;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEditing
                ? 'Edit Transaction'
                : (_isDeposit ? 'Deposit Funds' : 'Withdraw Funds'),
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Deposit (+)')),
                  selected: _isDeposit,
                  onSelected: (val) {
                    setState(() {
                      _isDeposit = true;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Withdraw (-)')),
                  selected: !_isDeposit,
                  onSelected: (val) {
                    setState(() {
                      _isDeposit = false;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Category Selector
          Text('Category', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          CategorySelector(
            selectedCategoryId: _selectedCategory,
            onCategorySelected: (val) => setState(() => _selectedCategory = val),
          ),
          const SizedBox(height: 16),
          // Date Picker Row
          InkWell(
            onTap: _pickDateTime,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date & Time',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(DateFormat('yyyy/MM/dd HH:mm').format(_selectedDate)),
                  const Icon(Icons.calendar_today),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(labelText: 'Amount'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text('Repeat Monthly?'),
            subtitle: const Text('Useful for bills like Rent/Netflix'),
            value: _isRecurring,
            onChanged: (val) => setState(() => _isRecurring = val),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEditing ? 'Save Changes' : 'Confirm'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (time == null) return;

    setState(() {
      _selectedDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    final amountText = _amountController.text;
    final title = _titleController.text;

    if (amountText.isEmpty || title.isEmpty) return;
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) return;

    setState(() => _isLoading = true);

    try {
      final provider = context.read<JointPotProvider>();
      final user = context.read<SessionProvider>().firebaseUser;
      final finalAmount = _isDeposit ? amount : -amount;

      if (_isEditing) {
        final newData = {
          'amount': finalAmount,
          'title': title,
          'date': _selectedDate, // Provider/Repo will handle Timestamp conversion if needed, but Repo uses FirestoreService
          'category': _selectedCategory,
          'is_recurring': _isRecurring,
          'recurrence_interval': _isRecurring ? 'monthly' : null,
        };
        // FirestoreService expects Timestamp, let's check Repo. 
        // Repo just passes to FirestoreService. 
        // FirestoreService's updateSavingsTransaction takes Map<String, dynamic> newData.
        // I should ensure the map has Timestamp if FirestoreService doesn't handle DateTime.
        // Actually, FirestoreService's updateSavingsTransaction uses `txn.update(txRef, newData);`
        // Firestore SDK handles DateTime if it's not specifically a Map of primitives.
        // Wait, FirestoreService uses Timestamp.fromDate in other places.
        
        final dataWithTimestamp = Map<String, dynamic>.from(newData);
        dataWithTimestamp['date'] = Timestamp.fromDate(_selectedDate);

        await provider.updateTransaction(widget.transaction!.id, dataWithTimestamp);
      } else {
        final transaction = SavingsTransactionModel(
          id: '',
          userId: user?.uid ?? '',
          amount: finalAmount,
          title: title,
          date: _selectedDate,
          isGoalDeduction: false,
          category: _selectedCategory,
          isRecurring: _isRecurring,
          recurrenceInterval: _isRecurring ? 'monthly' : null,
        );

        await provider.addTransaction(transaction);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
