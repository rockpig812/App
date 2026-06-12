import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart';
import '../services/firestore_service.dart';

/// RoomRepository
/// 處理所有與「房間」相關的業務邏輯
class RoomRepository {
  final FirestoreService _firestoreService = FirestoreService();

  /// 產生 6 位數邀請碼
  String _generateInviteCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// 建立新的 Room
  Future<Map<String, String>> createRoom({
    required String creatorId,
    required String name,
    required RoomType type,
  }) async {
    final inviteCode = _generateInviteCode();
    final roomId = await _firestoreService.createRoom({
      'name': name,
      'user_ids': [creatorId],
      'total_balance': {
        creatorId: 0.0,
      },
      'invite_code': inviteCode,
      'type': type.name,
      'joint_pot_balance': 0.0,
    });

    // 更新建立者的資料
    await _firestoreService.setUser(creatorId, {
      'joined_room_ids': [roomId],
      'last_active_room_id': roomId,
    });

    return {
      'roomId': roomId,
      'inviteCode': inviteCode,
    };
  }

  /// 使用邀請碼加入 Room
  Future<String?> joinRoom({
    required String inviteCode,
    required String userId,
  }) async {
    // 1. 根據邀請碼找到 roomId
    final roomId = await _firestoreService.findRoomByInviteCode(inviteCode);
    if (roomId == null) return null;

    // 2. 加入房間
    await _firestoreService.joinRoom(roomId, userId);

    return roomId;
  }

  /// 取得 Room 資料
  Future<RoomModel?> getRoom(String roomId) async {
    final data = await _firestoreService.getRoom(roomId);
    if (data == null) return null;
    return RoomModel.fromMap(data, roomId);
  }

  /// 監聽 Room 資料變更
  Stream<RoomModel?> watchRoom(String roomId) {
    return _firestoreService.watchRoom(roomId).map((snapshot) {
      if (!snapshot.exists) return null;
      return RoomModel.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  /// 更新總餘額
  Future<void> updateTotalBalance({
    required String roomId,
    required String payerId,
    required double amount,
  }) async {
    await _firestoreService.updateRoom(roomId, {
      'total_balance.$payerId': FieldValue.increment(amount),
    });
  }
}
