import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../repositories/transaction_repository.dart';
import '../transactions/add_transaction_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _formatMoney(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final myUid = session.firebaseUser?.uid;
    final coupleId = session.profile?.currentCoupleId;

    if (myUid == null || coupleId == null) {
      return const Scaffold(body: Center(child: Text('Missing session/couple.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            onPressed: () => context.read<SessionProvider>().signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: session.watchCurrentCoupleDoc(),
        builder: (context, coupleSnap) {
          if (!coupleSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final couple = coupleSnap.data!;
          final data = couple.data() ?? {};
          final userIds = List<String>.from(data['user_ids'] ?? []);
          final balanceRaw = (data['total_balance'] as Map<String, dynamic>?) ?? {};
          final totalBalance = balanceRaw.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          );

          if (userIds.length < 2) {
            return const Center(
              child: Text('Waiting for your partner to join...'),
            );
          }

          final partnerUid = userIds.firstWhere((u) => u != myUid, orElse: () => myUid);

          // Net Balance Logic:
          // myNet = (myPaid) - (totalPaid / 2)
          final myPaid = totalBalance[myUid] ?? 0.0;
          final partnerPaid = totalBalance[partnerUid] ?? 0.0;
          final totalPaid = myPaid + partnerPaid;
          final myShare = totalPaid / 2;
          final myNet = myPaid - myShare;

          final positive = myNet >= 0;
          final absNet = myNet.abs();
          final netText = positive
              ? 'Partner owes you \$${_formatMoney(absNet)}'
              : 'You owe Partner \$${_formatMoney(absNet)}';
          final netColor = positive ? Colors.green : Colors.red;

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Top card: Net Balance
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: netColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            positive ? Icons.trending_up : Icons.trending_down,
                            color: netColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Net Balance',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                netText,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: netColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'You paid \$${_formatMoney(myPaid)} • Partner paid \$${_formatMoney(partnerPaid)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Middle: transactions list
                Expanded(
                  child: _TransactionList(
                    coupleId: coupleId,
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
}

class _TransactionList extends StatelessWidget {
  final String coupleId;
  final String myUid;

  const _TransactionList({
    required this.coupleId,
    required this.myUid,
  });

  String _formatMoney(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
  String _formatDate(DateTime d) => '${d.year}-${d.month}-${d.day}';

  @override
  Widget build(BuildContext context) {
    final repo = TransactionRepository();

    return StreamBuilder(
      stream: repo.watchTransactions(coupleId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Failed to load: ${snapshot.error}'));
        }

        final items = snapshot.data ?? [];
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
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
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
                          Text(
                            tx.title,
                            style: Theme.of(context).textTheme.titleMedium,
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
                            isMe ? 'Paid by: Me' : 'Paid by: Partner',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

