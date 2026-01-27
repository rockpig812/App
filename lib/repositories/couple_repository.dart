import 'dart:math';
import '../models/couple_model.dart';
import '../services/firestore_service.dart';

/// CoupleRepository
/// 處理所有與「情侶配對」相關的業務邏輯
class CoupleRepository {
  final FirestoreService _firestoreService = FirestoreService();

  /// 產生 6 位數邀請碼
  String _generateInviteCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// 建立新的 Couple Space (使用者 A 建立)
  /// 返回 coupleId 和 inviteCode
  Future<Map<String, String>> createCoupleSpace({
    required String userId1,
    required String userId2,
  }) async {
    final inviteCode = _generateInviteCode();
    final coupleId = await _firestoreService.createCouple({
      'user_ids': [userId1, userId2],
      'total_balance': {
        userId1: 0.0,
        userId2: 0.0,
      },
      'invite_code': inviteCode,
    });

    return {
      'coupleId': coupleId,
      'inviteCode': inviteCode,
    };
  }

  /// 使用邀請碼加入 Couple Space (使用者 B 加入)
  Future<String?> joinCoupleSpace({
    required String inviteCode,
    required String userId,
  }) async {
    // 1. 根據邀請碼找到 coupleId
    final coupleId = await _firestoreService.findCoupleByInviteCode(inviteCode);
    if (coupleId == null) return null;

    // 2. 取得現有的 couple 資料
    final coupleData = await _firestoreService.getCouple(coupleId);
    if (coupleData == null) return null;

    final existingUserIds = List<String>.from(coupleData['user_ids'] ?? []);

    // 3. 檢查是否已經有兩個使用者
    if (existingUserIds.length >= 2) {
      throw Exception('這個 Couple Space 已經滿了');
    }

    // 4. 如果只有一個使用者，加入第二個
    if (existingUserIds.length == 1 && !existingUserIds.contains(userId)) {
      final balanceMap = Map<String, double>.from(
        (coupleData['total_balance'] as Map).map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        ),
      );
      balanceMap[userId] = 0.0;

      await _firestoreService.updateCouple(coupleId, {
        'user_ids': [...existingUserIds, userId],
        'total_balance': balanceMap,
      });
    }

    return coupleId;
  }

  /// 取得 Couple 資料
  Future<CoupleModel?> getCouple(String coupleId) async {
    final data = await _firestoreService.getCouple(coupleId);
    if (data == null) return null;
    return CoupleModel.fromMap(data, coupleId);
  }

  /// 監聽 Couple 資料變更
  Stream<CoupleModel?> watchCouple(String coupleId) {
    return _firestoreService.watchCouple(coupleId).map((snapshot) {
      if (!snapshot.exists) return null;
      return CoupleModel.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  /// 更新總餘額 (當有交易時呼叫)
  Future<void> updateTotalBalance({
    required String coupleId,
    required String payerId,
    required double amount,
  }) async {
    final couple = await getCouple(coupleId);
    if (couple == null) return;

    final newBalance = Map<String, double>.from(couple.totalBalance);
    newBalance[payerId] = (newBalance[payerId] ?? 0.0) + amount;

    await _firestoreService.updateCouple(coupleId, {
      'total_balance': newBalance,
    });
  }
}
