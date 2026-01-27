import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _joinCodeController = TextEditingController();

  bool _busy = false;
  String? _createdCoupleId;
  String? _createdInviteCode;
  String? _error;
  bool _pairedSynced = false;

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  String _random6DigitCode() {
    final r = Random.secure();
    return (100000 + r.nextInt(900000)).toString();
  }

  Future<String> _generateUniqueInviteCode() async {
    // 6 位數碰撞機率很低，但還是做個簡單防撞（最多重試 8 次）
    for (var i = 0; i < 8; i++) {
      final code = _random6DigitCode();
      final q = await FirebaseFirestore.instance
          .collection('couples')
          .where('invite_code', isEqualTo: code)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return code;
    }
    throw Exception('Failed to generate unique invite code. Try again.');
  }

  Future<void> _createNewSpace() async {
    final uid = context.read<SessionProvider>().firebaseUser?.uid;
    if (uid == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final code = await _generateUniqueInviteCode();
      final docRef = await FirebaseFirestore.instance.collection('couples').add({
        'user_ids': [uid],
        'total_balance': {uid: 0.0},
        'invite_code': code,
      });

      setState(() {
        _createdCoupleId = docRef.id;
        _createdInviteCode = code;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinWithCode() async {
    final uid = context.read<SessionProvider>().firebaseUser?.uid;
    if (uid == null) return;

    final code = _joinCodeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Invite code must be 6 digits.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final q = await FirebaseFirestore.instance
          .collection('couples')
          .where('invite_code', isEqualTo: code)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        throw Exception('No couple space found for this code.');
      }

      final coupleDoc = q.docs.first;
      final coupleId = coupleDoc.id;
      final data = coupleDoc.data();
      final userIds = List<String>.from(data['user_ids'] ?? []);

      if (userIds.length >= 2 && !userIds.contains(uid)) {
        throw Exception('This couple space is already full.');
      }

      final batch = FirebaseFirestore.instance.batch();

      // 1) 更新 couple 文件：加入 user_ids + 初始化 total_balance.{uid}
      final coupleRef = FirebaseFirestore.instance.collection('couples').doc(coupleId);
      final coupleUpdates = <String, dynamic>{
        'user_ids': FieldValue.arrayUnion([uid]),
      };
      if (!userIds.contains(uid)) {
        coupleUpdates['total_balance.$uid'] = 0.0;
      }
      batch.update(coupleRef, coupleUpdates);

      // 2) 更新「自己的」current_couple_id
      // （較符合常見 Firestore rules：只能更新自己的 users/{uid} 文件）
      final myUserRef = FirebaseFirestore.instance.collection('users').doc(uid);
      batch.set(myUserRef, {'current_couple_id': coupleId}, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ensurePairedForCreator(List<String> userIds) async {
    // 當 creator 的畫面偵測到 user_ids == 2 時，保險起見同步 current_couple_id
    final coupleId = _createdCoupleId;
    if (coupleId == null || _pairedSynced) return;
    _pairedSynced = true;

    final uid = context.read<SessionProvider>().firebaseUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'current_couple_id': coupleId}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<SessionProvider>().firebaseUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pairing'),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => context.read<SessionProvider>().signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DefaultTabController(
              length: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Not paired yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your UID: $uid',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  const TabBar(
                    tabs: [
                      Tab(text: 'Create'),
                      Tab(text: 'Join'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildCreateTab(),
                        _buildJoinTab(),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateTab() {
    final createdCoupleId = _createdCoupleId;
    final createdInviteCode = _createdInviteCode;

    if (createdCoupleId == null || createdInviteCode == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Create a new couple space and share the code.'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _createNewSpace,
              icon: const Icon(Icons.favorite),
              label: _busy ? const Text('Creating...') : const Text('Create New Space'),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Invite Code'),
        const SizedBox(height: 8),
        SelectableText(
          createdInviteCode,
          style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: createdInviteCode));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Waiting for your partner to join...'),
        const SizedBox(height: 12),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('couples').doc(createdCoupleId).snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            final userIds = List<String>.from(data?['user_ids'] ?? []);

            final ready = userIds.length == 2;
            if (ready) {
              // 保險：確保兩邊 users 文件都有 current_couple_id
              _ensurePairedForCreator(userIds);
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(ready ? Icons.check_circle : Icons.hourglass_bottom),
                const SizedBox(width: 8),
                Text(ready ? 'Paired!' : 'Not paired yet'),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildJoinTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Enter a 6-digit invite code.'),
        const SizedBox(height: 12),
        TextField(
          controller: _joinCodeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Invite code',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ? null : _joinWithCode,
            icon: const Icon(Icons.link),
            label: _busy ? const Text('Joining...') : const Text('Join'),
          ),
        ),
      ],
    );
  }
}

