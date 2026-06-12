import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/session_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/calculator_widget.dart';
import '../../widgets/category_grid.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? existingTransaction;

  const AddTransactionScreen({super.key, this.existingTransaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  late String _type; 
  late DateTime _date;
  late String _amountString;
  late String _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    if (widget.existingTransaction != null) {
      final tx = widget.existingTransaction!;
      _type = tx.amount >= 0 ? "支出" : "收入";
      _date = tx.date;
      _amountString = tx.amount.abs().toStringAsFixed(0);
      _selectedCategoryId = tx.category;
    } else {
      _type = "支出";
      _date = DateTime.now();
      _amountString = "0";
      _selectedCategoryId = 'food';
    }
  }

  bool _isSaving = false;

  void _onAmountChanged(String val) {
    setState(() {
      _amountString = val;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.orange,
              primary: Colors.orange,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _handleSave(double finalAmount) async {
    if (finalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("請輸入大於 0 的金額")),
      );
      return;
    }

    final session = context.read<SessionProvider>();
    final txProvider = context.read<TransactionProvider>();
    final myUid = session.firebaseUser?.uid;
    final roomId = session.profile?.lastActiveRoomId;

    if (myUid == null || roomId == null) return;

    setState(() => _isSaving = true);

    try {
      final actualAmount = _type == "支出" ? finalAmount : -finalAmount; 
      final category = TransactionCategory.getById(_selectedCategoryId);

      if (widget.existingTransaction != null) {
        await txProvider.updateTransaction(
          roomId: roomId,
          transactionId: widget.existingTransaction!.id,
          payerId: myUid,
          oldAmount: widget.existingTransaction!.amount,
          newAmount: actualAmount,
          title: category.label,
          date: _date,
          category: _selectedCategoryId,
        );
      } else {
        await txProvider.addTransaction(
          roomId: roomId,
          payerId: myUid,
          amount: actualAmount,
          title: category.label, 
          date: _date,
          category: _selectedCategoryId,
          splitType: 'equal',
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("儲存失敗: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final txProvider = context.read<TransactionProvider>();
    final myUid = session.firebaseUser?.uid;
    final roomId = session.profile?.lastActiveRoomId;

    final colorScheme = Theme.of(context).colorScheme;
    final category = TransactionCategory.getById(_selectedCategoryId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTypeTab("支出"),
              _buildTypeTab("收入"),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.existingTransaction != null && roomId != null && myUid != null)
             IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: () {
                txProvider.deleteTransaction(
                  roomId: roomId,
                  transactionId: widget.existingTransaction!.id,
                  payerId: myUid,
                  amount: widget.existingTransaction!.amount,
                );
                Navigator.pop(context);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: InkWell(
                      onTap: _pickDate,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            "今日 ${DateFormat('yyyy/MM/dd').format(_date)}",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 13),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: category.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(category.icon, color: category.color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          category.label,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          "\$ $_amountString",
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: _type == "支出" ? Colors.orange : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: CategoryGrid(
                      selectedCategoryId: _selectedCategoryId,
                      onCategorySelected: (id) {
                        setState(() {
                          _selectedCategoryId = id;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: CalculatorWidget(
                onChanged: _onAmountChanged,
                onSubmitted: _handleSave,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab(String label) {
    final isSelected = _type == label;
    return GestureDetector(
      onTap: () => setState(() => _type = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
