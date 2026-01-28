import 'package:cloud_firestore/cloud_firestore.dart';

/// FirestoreService
/// 低階的資料庫操作層，封裝所有 Firestore 的 CRUD 操作
/// 類似 C++ 中的 DAO (Data Access Object) 或 Repository 的底層實作
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

  // ========== Couples Collection ==========

  /// 建立新的 Couple
  Future<String> createCouple(Map<String, dynamic> data) async {
    final docRef = await _firestore.collection('couples').add(data);
    return docRef.id;
  }

  /// 取得 Couple 資料
  Future<Map<String, dynamic>?> getCouple(String coupleId) async {
    final doc = await _firestore.collection('couples').doc(coupleId).get();
    return doc.data();
  }

  /// 更新 Couple 資料
  Future<void> updateCouple(String coupleId, Map<String, dynamic> data) async {
    await _firestore.collection('couples').doc(coupleId).update(data);
  }

  /// 監聽 Couple 資料變更
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCouple(String coupleId) {
    return _firestore.collection('couples').doc(coupleId).snapshots();
  }

  /// 根據邀請碼查詢 Couple
  Future<String?> findCoupleByInviteCode(String inviteCode) async {
    final query = await _firestore
        .collection('couples')
        .where('invite_code', isEqualTo: inviteCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return query.docs.first.id;
  }

  // ========== Transactions Sub-collection ==========

  /// 新增交易紀錄
  Future<String> addTransaction(
    String coupleId,
    Map<String, dynamic> data,
  ) async {
    final docRef = await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('transactions')
        .add(data);
    return docRef.id;
  }

  /// 以「原子操作」新增交易 + 更新 couples.total_balance[payerId]
  /// - 使用 Firestore Transaction，確保兩步驟要嘛都成功，要嘛都失敗
  /// - UI 不需要知道 total_balance 如何維護，只要顯示即可
  Future<String> addTransactionAndIncrementBalance({
    required String coupleId,
    required String payerId,
    required double amount,
    required Map<String, dynamic> transactionData,
  }) async {
    final coupleRef = _firestore.collection('couples').doc(coupleId);
    final txRef = coupleRef.collection('transactions').doc(); // 先拿到自動 ID

    await _firestore.runTransaction((txn) async {
      // 1) 新增交易文件
      txn.set(txRef, transactionData);

      // 2) 原子更新 total_balance.<payerId> (不存在也會自動從 null 視為 0 再加)
      txn.update(coupleRef, {
        'total_balance.$payerId': FieldValue.increment(amount),
      });
    });

    return txRef.id;
  }

  /// 取得交易列表 (依日期降序)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTransactions(
    String coupleId,
  ) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots();
  }

  /// 刪除交易
  Future<void> deleteTransaction(String coupleId, String transactionId) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('transactions')
        .doc(transactionId)
        .delete();
  }

  // ========== Goals Sub-collection ==========

  /// 新增儲蓄目標
  Future<String> addGoal(String coupleId, Map<String, dynamic> data) async {
    final docRef = await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('goals')
        .add(data);
    return docRef.id;
  }

  /// 更新儲蓄目標
  Future<void> updateGoal(
    String coupleId,
    String goalId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('goals')
        .doc(goalId)
        .update(data);
  }

  /// 監聽儲蓄目標列表
  Stream<QuerySnapshot<Map<String, dynamic>>> watchGoals(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('goals')
        .snapshots();
  }

  /// 取得單一儲蓄目標
  Future<Map<String, dynamic>?> getGoal(String coupleId, String goalId) async {
    final doc = await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('goals')
        .doc(goalId)
        .get();
    return doc.data();
  }

  // ========== Contributions Sub-collection ==========

  /// 新增存入紀錄
  Future<String> addContribution(
    String coupleId,
    String goalId,
    Map<String, dynamic> data,
  ) async {
    final docRef = await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('goals')
        .doc(goalId)
        .collection('contributions')
        .add(data);
    return docRef.id;
  }

  /// 監聽存入紀錄列表
  Stream<QuerySnapshot<Map<String, dynamic>>> watchContributions(
    String coupleId,
    String goalId,
  ) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('goals')
        .doc(goalId)
        .collection('contributions')
        .orderBy('date', descending: true)
        .snapshots();
  }
}
