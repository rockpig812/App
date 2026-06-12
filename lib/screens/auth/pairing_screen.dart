import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../repositories/room_repository.dart';
import '../../models/room_model.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _joinCodeController = TextEditingController();

  bool _busy = false;
  String? _createdRoomId;
  String? _createdInviteCode;
  String? _error;
  bool _joinedSynced = false;

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _createPersonalSpace() async {
    await _createNewSpace(RoomType.personal, 'My Personal Space');
  }

  Future<void> _createGroupSpace() async {
    await _createNewSpace(RoomType.group, 'Our Group Space');
  }

  Future<void> _createNewSpace(RoomType type, String name) async {
    final uid = context.read<SessionProvider>().firebaseUser?.uid;
    if (uid == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final repo = context.read<RoomRepository>();
      final result = await repo.createRoom(
        creatorId: uid,
        name: name,
        type: type,
      );

      setState(() {
        _createdRoomId = result['roomId'];
        _createdInviteCode = result['inviteCode'];
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
      final repo = context.read<RoomRepository>();
      final roomId = await repo.joinRoom(inviteCode: code, userId: uid);

      if (roomId == null) {
        throw Exception('No space found for this code.');
      }
      
      // SessionProvider is watching user doc, so it should auto-update.
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<SessionProvider>().firebaseUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spaces'),
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
                    'Welcome to Spaces',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'UID: $uid',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
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
                      textAlign: TextAlign.center,
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
    final createdRoomId = _createdRoomId;
    final createdInviteCode = _createdInviteCode;

    if (createdRoomId == null || createdInviteCode == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Start your financial journey.'),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _createPersonalSpace,
              icon: const Icon(Icons.person),
              label: _busy ? const Text('Creating...') : const Text('Personal Space'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _createGroupSpace,
              icon: const Icon(Icons.group),
              label: const Text('Group Space'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Groups can be shared with others using a code.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
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
        const Text('Waiting for others to join...'),
        const SizedBox(height: 12),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('rooms').doc(createdRoomId).snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            final userIds = List<String>.from(data?['user_ids'] ?? []);

            final ready = userIds.length > 1;

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(ready ? Icons.check_circle : Icons.hourglass_bottom),
                const SizedBox(width: 8),
                Text(ready ? 'Others Joined!' : 'Waiting...'),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () {
            // Force refresh session to enter the shell if it doesn't auto-update
            // But usually StreamBuilder in SessionProvider handles this.
          },
          child: const Text('Go to Space'),
        )
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
