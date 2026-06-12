import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart';

/// FirestoreService
/// 低階的資料庫操作層，封裝所有 Firestore 的 CRUD 操作
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FirebaseFirestore get firestore => _firestore;

  // ========== Users Collection ==========

  /// 建立或更新使用者資料
  Future<void> setUser(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  /// 取得使用者資料
  Future<Map<String, dynamic>?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  /// 監聽使用者資料變更 (Stream)
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  // ========== Rooms Collection ==========

  /// 建立新的 Room
  Future<String> createRoom(Map<String, dynamic> data) async {
    final docRef = await _firestore.collection('rooms').add(data);
    return docRef.id;
  }

  /// 取得 Room 資料
  Future<Map<String, dynamic>?> getRoom(String roomId) async {
    final doc = await _firestore.collection('rooms').doc(roomId).get();
    return doc.data();
  }

  /// 更新 Room 資料
  Future<void> updateRoom(String roomId, Map<String, dynamic> data) async {
    await _firestore.collection('rooms').doc(roomId).update(data);
  }

  /// 監聽 Room 資料變更
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRoom(String roomId) {
    return _firestore.collection('rooms').doc(roomId).snapshots();
  }

  /// 根據邀請碼查詢 Room
  Future<String?> findRoomByInviteCode(String inviteCode) async {
    final query = await _firestore
        .collection('rooms')
        .where('invite_code', isEqualTo: inviteCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return query.docs.first.id;
  }

  /// 加入房間 (使用 arrayUnion)
  Future<void> joinRoom(String roomId, String userId) async {
    await _firestore.collection('rooms').doc(roomId).update({
      'user_ids': FieldValue.arrayUnion([userId]),
      'total_balance.$userId': 0.0,
    });
    
    // 同時更新使用者的 joined_room_ids
    await _firestore.collection('users').doc(userId).update({
      'joined_room_ids': FieldValue.arrayUnion([roomId]),
      'last_active_room_id': roomId,
    });
  }

  // ========== Transactions Sub-collection ==========

  /// 新增交易紀錄
  Future<String> addTransaction(
    String roomId,
    Map<String, dynamic> data,
  ) async {
    final docRef = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('transactions')
        .add(data);
    return docRef.id;
  }

  /// 以「原子操作」新增交易 + 更新 rooms.total_balance[payerId]
  Future<String> addTransactionAndIncrementBalance({
    required String roomId,
    required String payerId,
    required double amount,
    required Map<String, dynamic> transactionData,
  }) async {
    final roomRef = _firestore.collection('rooms').doc(roomId);
    final txRef = roomRef.collection('transactions').doc();

    await _firestore.runTransaction((txn) async {
      txn.set(txRef, transactionData);

      txn.update(roomRef, {
        'total_balance.$payerId': FieldValue.increment(amount),
      });
    });

    return txRef.id;
  }

  /// 取得交易列表 (依日期降序)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTransactions(
    String roomId,
  ) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots();
  }

  /// 刪除交易
  Future<void> deleteTransaction(String roomId, String transactionId) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('transactions')
        .doc(transactionId)
        .delete();
  }

  // ========== Goals Sub-collection ==========

  /// 新增儲蓄目標
  Future<String> addGoal(String roomId, Map<String, dynamic> data) async {
    final docRef = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('goals')
        .add(data);
    return docRef.id;
  }

  /// 更新儲蓄目標
  Future<void> updateGoal(
    String roomId,
    String goalId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('goals')
        .doc(goalId)
        .update(data);
  }

  /// 監聽儲蓄目標列表
  Stream<QuerySnapshot<Map<String, dynamic>>> watchGoals(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('goals')
        .snapshots();
  }

  /// 取得單一儲蓄目標
  Future<Map<String, dynamic>?> getGoal(String roomId, String goalId) async {
    final doc = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('goals')
        .doc(goalId)
        .get();
    return doc.data();
  }

  // ========== Contributions Sub-collection ==========

  /// 新增存入紀錄
  Future<String> addContribution(
    String roomId,
    String goalId,
    Map<String, dynamic> data,
  ) async {
    final docRef = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('goals')
        .doc(goalId)
        .collection('contributions')
        .add(data);
    return docRef.id;
  }

  /// 監聽存入紀錄列表
  Stream<QuerySnapshot<Map<String, dynamic>>> watchContributions(
    String roomId,
    String goalId,
  ) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('goals')
        .doc(goalId)
        .collection('contributions')
        .orderBy('date', descending: true)
        .snapshots();
  }

  /// 以原子方式：對目標存入一筆金額 + 新增 contributions 紀錄
  Future<String> addContributionAndIncrementGoal({
    required String roomId,
    required String goalId,
    required String userId,
    required double amount,
    required DateTime date,
  }) async {
    final goalRef =
        _firestore.collection('rooms').doc(roomId).collection('goals').doc(goalId);
    final contribRef = goalRef.collection('contributions').doc();

    await _firestore.runTransaction((txn) async {
      final goalSnap = await txn.get(goalRef);
      if (!goalSnap.exists) {
        throw StateError('Goal not found');
      }

      txn.set(contribRef, {
        'goal_id': goalId,
        'user_id': userId,
        'amount': amount,
        'date': Timestamp.fromDate(date),
      });

      txn.update(goalRef, {
        'current_amount': FieldValue.increment(amount),
      });
    });

    return contribRef.id;
  }

  // ========== Joint Pot & Savings Transactions ==========

  /// 執行存錢/提款交易 (原子操作)
  Future<void> performSavingsTransaction({
    required String roomId,
    required Map<String, dynamic> transactionData,
  }) async {
    final roomRef = _firestore.collection('rooms').doc(roomId);
    final txRef = roomRef.collection('savings_transactions').doc();
    final double amount = transactionData['amount'];

    await _firestore.runTransaction((txn) async {
      txn.set(txRef, transactionData);

      txn.update(roomRef, {
        'joint_pot_balance': FieldValue.increment(amount),
      });
    });
  }

  /// 監聽公基金交易紀錄
  Stream<QuerySnapshot<Map<String, dynamic>>> watchSavingsTransactions(
      String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('savings_transactions')
        .orderBy('date', descending: true)
        .snapshots();
  }

  /// 達成目標 (原子操作)
  Future<void> achieveGoal({
    required String roomId,
    required String goalId,
    required double targetAmount,
    required String goalTitle,
    required String userId,
  }) async {
    final roomRef = _firestore.collection('rooms').doc(roomId);
    final goalRef = roomRef.collection('goals').doc(goalId);
    final txRef = roomRef.collection('savings_transactions').doc();

    await _firestore.runTransaction((txn) async {
      final roomSnap = await txn.get(roomRef);
      if (!roomSnap.exists) throw Exception("Room not found");

      final double currentBalance =
          (roomSnap.data()?['joint_pot_balance'] as num?)?.toDouble() ?? 0.0;

      if (currentBalance < targetAmount) {
        throw Exception("Insufficient funds");
      }

      txn.update(roomRef, {
        'joint_pot_balance': FieldValue.increment(-targetAmount),
      });

      txn.set(txRef, {
        'user_id': userId,
        'amount': -targetAmount,
        'title': 'Goal: $goalTitle',
        'date': Timestamp.now(),
        'is_goal_deduction': true,
      });

      txn.update(goalRef, {
        'status': 'achieved',
        'achieved_date': Timestamp.now(),
      });
    });
  }

  /// 撤銷達成目標 (原子操作)
  Future<void> undoAchieveGoal({
    required String roomId,
    required String goalId,
    required double amount,
    required String goalTitle,
    required String userId,
  }) async {
    final roomRef = _firestore.collection('rooms').doc(roomId);
    final goalRef = roomRef.collection('goals').doc(goalId);
    final txRef = roomRef.collection('savings_transactions').doc();

    await _firestore.runTransaction((txn) async {
      txn.update(roomRef, {
        'joint_pot_balance': FieldValue.increment(amount),
      });

      txn.set(txRef, {
        'user_id': userId,
        'amount': amount,
        'title': 'Refund: $goalTitle',
        'date': Timestamp.now(),
        'is_goal_deduction': true,
      });

      txn.update(goalRef, {
        'status': 'active',
      });
    });
  }

  /// 更新交易紀錄 (原子操作)
  Future<void> updateSavingsTransaction({
    required String roomId,
    required String transactionId,
    required Map<String, dynamic> newData,
  }) async {
    final roomRef = _firestore.collection('rooms').doc(roomId);
    final txRef = roomRef.collection('savings_transactions').doc(transactionId);
    final double newAmount = newData['amount'];

    await _firestore.runTransaction((txn) async {
      final txSnap = await txn.get(txRef);
      if (!txSnap.exists) throw Exception("Transaction not found");

      final oldAmount = (txSnap.data()?['amount'] as num?)?.toDouble() ?? 0.0;
      final diff = newAmount - oldAmount;

      txn.update(txRef, newData);

      if (diff != 0) {
        txn.update(roomRef, {
          'joint_pot_balance': FieldValue.increment(diff),
        });
      }
    });
  }

  /// 刪除交易紀錄 (原子操作)
  Future<void> deleteSavingsTransaction({
    required String roomId,
    required String transactionId,
  }) async {
    final roomRef = _firestore.collection('rooms').doc(roomId);
    final txRef = roomRef.collection('savings_transactions').doc(transactionId);

    await _firestore.runTransaction((txn) async {
      final txSnap = await txn.get(txRef);
      if (!txSnap.exists) throw Exception("Transaction not found");

      final amount = (txSnap.data()?['amount'] as num?)?.toDouble() ?? 0.0;

      txn.update(roomRef, {
        'joint_pot_balance': FieldValue.increment(-amount),
      });

      txn.delete(txRef);
    });
  }
}
