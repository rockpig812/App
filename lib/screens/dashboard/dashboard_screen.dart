import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../providers/transaction_provider.dart';
import '../transactions/add_transaction_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _formatMoney(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = context.read<SessionProvider>();
      final roomId = session.profile?.lastActiveRoomId;
      if (roomId != null) {
        context.read<TransactionProvider>().startWatching(roomId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final myUid = session.firebaseUser?.uid;
    final roomId = session.profile?.lastActiveRoomId;

    if (myUid == null || roomId == null) {
      return const Scaffold(body: Center(child: Text('Missing session/room.')));
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
            return const Center(
              child: Text('No users in this room.'),
            );
          }

          // Net Balance Logic for Multiple Users:
          // myNet = (myPaid) - (totalPaid / N)
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
            netText = 'Personal Mode: All expenses are yours.';
          } else {
            netText = positive
                ? 'Others owe you \$${_formatMoney(absNet)}'
                : 'You owe others \$${_formatMoney(absNet)}';
          }
          
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
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: netColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            positive ? Icons.arrow_upward : Icons.arrow_downward,
                            color: netColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                netText,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: netColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'You paid \$${_formatMoney(myPaid)} • Total room paid \$${_formatMoney(totalPaid)}',
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
        );
      },
    );
  }
}
