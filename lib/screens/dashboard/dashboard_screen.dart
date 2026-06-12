import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../providers/session_provider.dart';
import '../../providers/transaction_provider.dart';
import '../transactions/add_transaction_screen.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _formatMoney(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final myUid = session.firebaseUser?.uid;
    final roomId = session.profile?.lastActiveRoomId;

    if (myUid == null || roomId == null || session.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: session.watchCurrentRoomDoc(),
        builder: (context, roomSnap) {
          if (!roomSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final room = roomSnap.data!;
          final data = room.data() ?? {};
          final userIds = List<String>.from(data['user_ids'] ?? []);
          final balanceRaw = (data['total_balance'] as Map<String, dynamic>?) ?? {};
          final totalBalance = balanceRaw.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          );

          if (userIds.isEmpty) {
            return const Center(child: Text('空間內尚無成員'));
          }

          final myPaid = totalBalance[myUid] ?? 0.0;
          double totalPaid = 0.0;
          totalBalance.forEach((uid, paid) {
            totalPaid += paid;
          });
          
          final myShare = totalPaid / userIds.length;
          final myNet = myPaid - myShare;

          final positive = myNet >= 0;
          final absNet = myNet.abs();
          
          String netText;
          if (userIds.length == 1) {
            netText = '個人模式：所有支出皆由你負擔';
          } else {
            netText = positive
                ? '其他人共欠你 \$${_formatMoney(absNet)}'
                : '你共欠其他人 \$${_formatMoney(absNet)}';
          }
          
          final colorScheme = Theme.of(context).colorScheme;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 8),
                // Top card: Net Balance
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: positive 
                        ? [colorScheme.primaryContainer, colorScheme.primaryContainer.withOpacity(0.7)]
                        : [colorScheme.errorContainer, colorScheme.errorContainer.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          positive ? Icons.account_balance_wallet_rounded : Icons.warning_amber_rounded,
                          color: positive ? colorScheme.onPrimaryContainer : colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              netText,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: positive ? colorScheme.onPrimaryContainer : colorScheme.onErrorContainer,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '你累計支付 \$${_formatMoney(myPaid)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: (positive ? colorScheme.onPrimaryContainer : colorScheme.onErrorContainer).withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Expense Analysis (Donut Chart)
                _buildAnalysisSection(context),

                const SizedBox(height: 12),

                // Middle: transactions list
                Expanded(
                  child: _TransactionList(
                    roomId: roomId,
                    myUid: myUid,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnalysisSection(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final txs = provider.transactions;
    if (txs.isEmpty) return const SizedBox.shrink();

    // Group by category
    final Map<String, double> categorySums = {};
    double total = 0;
    for (var tx in txs) {
      if (tx.amount > 0) { // Only count expenses
        categorySums[tx.category] = (categorySums[tx.category] ?? 0) + tx.amount;
        total += tx.amount;
      }
    }

    if (total == 0) return const SizedBox.shrink();

    final List<PieChartSectionData> sections = categorySums.entries.map((e) {
      final category = TransactionCategory.getById(e.key);
      final percentage = (e.value / total * 100).toStringAsFixed(1);
      return PieChartSectionData(
        color: category.color,
        value: e.value,
        title: '$percentage%',
        radius: 40,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 30,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('支出分析', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ...categorySums.entries.take(3).map((e) {
                  final cat = TransactionCategory.getById(e.key);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(cat.label, style: const TextStyle(fontSize: 12)),
                        const Spacer(),
                        Text('\$${_formatMoney(e.value)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionList extends StatelessWidget {
  final String roomId;
  final String myUid;

  const _TransactionList({
    required this.roomId,
    required this.myUid,
  });

  String _formatMoney(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
  String _formatDate(DateTime d) => '${d.year}-${d.month}-${d.day}';

  void _showDeleteConfirm(BuildContext context, TransactionModel tx) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除交易'),
        content: Text('確定要刪除「${tx.title}」嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              context.read<TransactionProvider>().deleteTransaction(
                roomId: roomId,
                transactionId: tx.id,
                payerId: tx.payerId,
                amount: tx.amount,
              );
              Navigator.pop(context);
            },
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final items = provider.transactions;

    if (items.isEmpty) {
      return const Center(child: Text('No transactions yet. Tap + to add one.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final tx = items[index];
        final isMe = tx.payerId == myUid;
        final bubbleColor = isMe
            ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
            : Theme.of(context).colorScheme.secondary.withOpacity(0.12);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddTransactionScreen(existingTransaction: tx),
                ),
              );
            },
            onLongPress: () => _showDeleteConfirm(context, tx),
            borderRadius: BorderRadius.circular(16),
            child: Row(
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tx.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (tx.isSyncing) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.access_time, size: 14, color: Colors.grey),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '\$${_formatMoney(tx.amount)}',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(tx.date),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isMe ? 'Paid by: Me' : 'Paid by: Someone Else',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
