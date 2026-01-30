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

  /// 以原子方式：對目標存入一筆金額 + 新增 contributions 紀錄
  Future<String> addContributionAndIncrementGoal({
    required String coupleId,
    required String goalId,
    required String userId,
    required double amount,
    required DateTime date,
  }) async {
    final goalRef =
        _firestore.collection('couples').doc(coupleId).collection('goals').doc(goalId);
    final contribRef = goalRef.collection('contributions').doc();

    await _firestore.runTransaction((txn) async {
      // 1) 讀取現有 goal（若不存在會丟錯）
      final goalSnap = await txn.get(goalRef);
      if (!goalSnap.exists) {
        throw StateError('Goal not found');
      }

      // 2) 新增 contribution
      txn.set(contribRef, {
        'goal_id': goalId,
        'user_id': userId,
        'amount': amount,
        'date': Timestamp.fromDate(date),
      });

      // 3) 原子遞增 current_amount
      txn.update(goalRef, {
        'current_amount': FieldValue.increment(amount),
      });
    });

    return contribRef.id;
  }

  // ========== Joint Pot & Savings Transactions ==========

  /// 執行存錢/提款交易 (原子操作)
  /// 1. 新增 savings_transactions 紀錄
  /// 2. 更新 couple.joint_pot_balance
  Future<void> performSavingsTransaction({
    required String coupleId,
    required Map<String, dynamic> transactionData, // SavingsTransactionModel data
  }) async {
    final coupleRef = _firestore.collection('couples').doc(coupleId);
    final txRef = coupleRef.collection('savings_transactions').doc();
    final double amount = transactionData['amount'];

    await _firestore.runTransaction((txn) async {
      // 1. 新增交易紀錄
      txn.set(txRef, transactionData);

      // 2. 更新公基金餘額
      txn.update(coupleRef, {
        'joint_pot_balance': FieldValue.increment(amount),
      });
    });
  }

  /// 監聽公基金交易紀錄
  Stream<QuerySnapshot<Map<String, dynamic>>> watchSavingsTransactions(
      String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('savings_transactions')
        .orderBy('date', descending: true)
        .snapshots();
  }

  /// 達成目標 (原子操作)
  /// 1. 檢查餘額是否足夠
  /// 2. 扣除公基金餘額
  /// 3. 新增 savings_transactions (支出)
  /// 4. 更新 goal.status = 'achieved' (與 achieved_date)
  Future<void> achieveGoal({
    required String coupleId,
    required String goalId,
    required double targetAmount,
    required String goalTitle,
    required String userId,
  }) async {
    final coupleRef = _firestore.collection('couples').doc(coupleId);
    final goalRef = coupleRef.collection('goals').doc(goalId);
    final txRef = coupleRef.collection('savings_transactions').doc();

    await _firestore.runTransaction((txn) async {
      final coupleSnap = await txn.get(coupleRef);
      if (!coupleSnap.exists) throw Exception("Couple not found");

      final double currentBalance =
          (coupleSnap.data()?['joint_pot_balance'] as num?)?.toDouble() ?? 0.0;

      if (currentBalance < targetAmount) {
        throw Exception("Insufficient funds");
      }

      // 1. 扣除金額
      txn.update(coupleRef, {
        'joint_pot_balance': FieldValue.increment(-targetAmount),
      });

      // 2. 新增交易紀錄
      txn.set(txRef, {
        'user_id': userId,
        'amount': -targetAmount,
        'title': 'Goal: $goalTitle',
        'date': Timestamp.now(),
        'is_goal_deduction': true,
      });

      // 3. 更新目標狀態
      txn.update(goalRef, {
        'status': 'achieved',
        'achieved_date': Timestamp.now(),
      });
    });
  }

  /// 撤銷達成目標 (原子操作)
  /// 1. 加回公基金餘額
  /// 2. 刪除對應的 savings_transactions (這裡簡化為新增一筆補償入帳，或刪除該筆交易。
  ///    若要刪除特定交易，需要知道該交易ID。但這裡可以做的簡單點：直接新增一筆「退款」紀錄，
  ///    或者若要嚴格「還原」，需要查詢該筆 transaction。
  ///    **修正策略**：為了資料完整性，我們採用「反向交易」：新增一筆 +amount 的紀錄，標題 "Refund: Goal"。
  ///    同時把 goal 狀態改回 active。)
  Future<void> undoAchieveGoal({
    required String coupleId,
    required String goalId,
    required double amount,
    required String goalTitle,
    required String userId,
  }) async {
    final coupleRef = _firestore.collection('couples').doc(coupleId);
    final goalRef = coupleRef.collection('goals').doc(goalId);
    final txRef = coupleRef.collection('savings_transactions').doc();

    await _firestore.runTransaction((txn) async {
      // 1. 加回金額
      txn.update(coupleRef, {
        'joint_pot_balance': FieldValue.increment(amount),
      });

      // 2. 新增退款交易紀錄
      txn.set(txRef, {
        'user_id': userId,
        'amount': amount,
        'title': 'Refund: $goalTitle',
        'date': Timestamp.now(),
        'is_goal_deduction': true,
      });

      // 3. 更新目標狀態
      txn.update(goalRef, {
        'status': 'active',
      });
    });
  }

  /// 更新交易紀錄 (原子操作)
  /// 1. 讀取舊交易 (取得 oldAmount)
  /// 2. 計算差額 (newAmount - oldAmount)
  /// 3. 更新交易文件
  /// 4. 更新公基金餘額
  Future<void> updateSavingsTransaction({
    required String coupleId,
    required String transactionId,
    required Map<String, dynamic> newData, // 包含新的 amount, title, date 等
  }) async {
    final coupleRef = _firestore.collection('couples').doc(coupleId);
    final txRef = coupleRef.collection('savings_transactions').doc(transactionId);
    final double newAmount = newData['amount'];

    await _firestore.runTransaction((txn) async {
      // 1. 讀取舊交易
      final txSnap = await txn.get(txRef);
      if (!txSnap.exists) throw Exception("Transaction not found");

      final oldAmount = (txSnap.data()?['amount'] as num?)?.toDouble() ?? 0.0;
      final diff = newAmount - oldAmount;

      // 2. 更新交易紀錄
      txn.update(txRef, newData);

      // 3. 更新公基金餘額 (只有金額變動時才需要)
      if (diff != 0) {
        txn.update(coupleRef, {
          'joint_pot_balance': FieldValue.increment(diff),
        });
      }
    });
  }

  /// 刪除交易紀錄 (原子操作)
  /// 1. 讀取交易金 (取得 amount)
  /// 2. 反向更新公基金餘額 (balance - amount)
  /// 3. 刪除交易文件
  Future<void> deleteSavingsTransaction({
    required String coupleId,
    required String transactionId,
  }) async {
    final coupleRef = _firestore.collection('couples').doc(coupleId);
    final txRef = coupleRef.collection('savings_transactions').doc(transactionId);

    await _firestore.runTransaction((txn) async {
      // 1. 讀取交易
      final txSnap = await txn.get(txRef);
      if (!txSnap.exists) throw Exception("Transaction not found");

      final amount = (txSnap.data()?['amount'] as num?)?.toDouble() ?? 0.0;

      // 2. 反向更新餘額
      // 如果原本是存 +1000，刪除後要 balance - 1000
      // 如果原本是領 -500，刪除後要 balance - (-500) = balance + 500
      txn.update(coupleRef, {
        'joint_pot_balance': FieldValue.increment(-amount),
      });

      // 3. 刪除文件
      txn.delete(txRef);
    });
  }
}
