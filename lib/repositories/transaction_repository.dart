import '../models/transaction_model.dart';
import '../services/firestore_service.dart';

/// TransactionRepository
/// 處理所有與「交易紀錄」相關的業務邏輯
class TransactionRepository {
  final FirestoreService _firestoreService = FirestoreService();

  /// 新增交易
  /// 這會同時更新 Couple 的 total_balance
  Future<String> addTransaction({
    required String coupleId,
    required String payerId,
    required double amount,
    required String title,
    required DateTime date,
    String category = '其他',
    String splitType = 'equal',
  }) async {
    final tx = TransactionModel(
      id: '',
      coupleId: coupleId,
      payerId: payerId,
      amount: amount,
      title: title,
      date: date,
      category: category,
      splitType: splitType,
    );

    // CRITICAL: 原子操作（新增交易 + 增加 total_balance）
    return _firestoreService.addTransactionAndIncrementBalance(
      coupleId: coupleId,
      payerId: payerId,
      amount: amount,
      transactionData: tx.toMap(),
    );
  }

  /// 監聽交易列表
  Stream<List<TransactionModel>> watchTransactions(String coupleId) {
    return _firestoreService.watchTransactions(coupleId).map((snapshot) {
      return snapshot.docs.map((doc) {
        return TransactionModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// 刪除交易
  /// 這會同時減少 Couple 的 total_balance
  Future<void> deleteTransaction({
    required String coupleId,
    required String transactionId,
    required String payerId,
    required double amount,
  }) async {
    // MVP: 先保留刪除交易不做 total_balance 回滾（避免歷史修正帶來複雜度）
    // Phase 3 的核心是「新增」要原子且即時更新。
    await _firestoreService.deleteTransaction(coupleId, transactionId);
  }
}
