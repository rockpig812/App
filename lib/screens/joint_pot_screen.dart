import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/couple_model.dart';
import '../models/transaction_model.dart';
import '../models/savings_transaction_model.dart';
import '../services/firestore_service.dart';
import '../providers/session_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JointPotScreen extends StatelessWidget {
  const JointPotScreen({Key? key, required this.coupleId}) : super(key: key);

  final String coupleId;

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Joint Pot'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: firestoreService.watchCouple(coupleId),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final coupleData = snapshot.data!.data();
          if (coupleData == null) return const Center(child: Text('Couple not found'));

          final couple = CoupleModel.fromMap(coupleData, snapshot.data!.id);

          return Column(
            children: [
              const SizedBox(height: 20),
              // Balance Circle
              _buildBalanceCircle(couple.jointPotBalance),
              const SizedBox(height: 20),
              // Transaction List
              Expanded(
                child: _buildTransactionList(context, firestoreService),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTransactionDialog(context),
        label: const Text('Deposit / Withdraw'),
        icon: const Icon(Icons.swap_horiz),
      ),
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

  Widget _buildTransactionList(BuildContext context, FirestoreService service) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.watchSavingsTransactions(coupleId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Error loading transactions'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No transactions yet'));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final transaction = SavingsTransactionModel.fromMap(data, docs[index].id);
            final isDeposit = transaction.amount >= 0;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isDeposit ? Colors.green[100] : Colors.red[100],
                child: Icon(
                  isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isDeposit ? Colors.green : Colors.red,
                ),
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
              onLongPress: () => _showEditDeleteDialog(context, service, transaction),
            );
          },
        );
      },
    );
  }

  void _showTransactionDialog(BuildContext context, {SavingsTransactionModel? transaction}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _TransactionBottomSheet(
        coupleId: coupleId,
        transaction: transaction,
      ),
    );
  }

  void _showEditDeleteDialog(
      BuildContext context, FirestoreService service, SavingsTransactionModel transaction) {
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
                _confirmDelete(context, service, transaction);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, FirestoreService service, SavingsTransactionModel transaction) {
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
                await service.deleteSavingsTransaction(
                  coupleId: coupleId,
                  transactionId: transaction.id,
                );
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
  final String coupleId;
  final SavingsTransactionModel? transaction; // If null, create new mode

  const _TransactionBottomSheet({
    Key? key,
    required this.coupleId,
    this.transaction,
  }) : super(key: key);

  @override
  State<_TransactionBottomSheet> createState() => _TransactionBottomSheetState();
}

class _TransactionBottomSheetState extends State<_TransactionBottomSheet> {
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isDeposit = true;
  bool _isLoading = false;

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
          // Toggle only if not editing (or allow editing type? usually better to keep simple)
          // Let's allow editing type unless it feels wrong. For now allow it.
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
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const CircularProgressIndicator()
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
      final user = context.read<SessionProvider>().firebaseUser;
      final service = context.read<FirestoreService>();
      final finalAmount = _isDeposit ? amount : -amount;

      if (_isEditing) {
        // Update
        final newData = {
          'amount': finalAmount,
          'title': title,
          'date': Timestamp.fromDate(_selectedDate), // Ensure Timestamp
          // 'user_id': ... keep original user or update? Keep original usually.
        };
        await service.updateSavingsTransaction(
          coupleId: widget.coupleId,
          transactionId: widget.transaction!.id,
          newData: newData,
        );
      } else {
        // Create
        final transaction = SavingsTransactionModel(
          id: '',
          userId: user?.uid ?? '',
          amount: finalAmount,
          title: title,
          date: _selectedDate,
          isGoalDeduction: false,
        );

        await service.performSavingsTransaction(
          coupleId: widget.coupleId,
          transactionData: transaction.toMap(),
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
