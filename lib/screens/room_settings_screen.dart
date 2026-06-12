import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../providers/session_provider.dart';
import '../repositories/room_repository.dart';
import '../models/room_model.dart';

class RoomSettingsView extends StatelessWidget {
  const RoomSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final roomId = session.profile?.lastActiveRoomId ?? '';
    final roomRepo = context.read<RoomRepository>();
    final colorScheme = Theme.of(context).colorScheme;

    if (roomId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<RoomModel?>(
      stream: roomRepo.watchRoom(roomId),
      builder: (context, snapshot) {
        final room = snapshot.data;
        if (room == null) return const Center(child: CircularProgressIndicator());

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            // Room Info Header
            _buildSectionHeader(context, "空間資訊"),
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(
                        room.type == RoomType.personal ? Icons.person_rounded : Icons.people_rounded,
                        size: 32,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      room.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      room.type == RoomType.personal ? "個人空間" : "共同空間",
                      style: TextStyle(color: colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Invite Code Section
            if (room.inviteCode != null && room.inviteCode!.isNotEmpty) ...[
              _buildSectionHeader(context, "邀請成員"),
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  title: const Text("邀請碼", style: TextStyle(fontSize: 14, color: Colors.grey)),
                  subtitle: Text(
                    room.inviteCode!,
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.w900, 
                      letterSpacing: 4,
                      color: colorScheme.primary,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: room.inviteCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("已複製邀請碼")),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Danger Zone
            _buildSectionHeader(context, "帳號管理"),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: colorScheme.error),
              title: Text("登出帳號", style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold)),
              onTap: () => _showLogoutDialog(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14, 
          fontWeight: FontWeight.bold, 
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("確定要登出嗎？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
          TextButton(
            onPressed: () {
              context.read<SessionProvider>().signOut();
              Navigator.pop(context);
            },
            child: const Text("登出", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
