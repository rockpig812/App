import '../models/transaction_model.dart';
import '../services/firestore_service.dart';

/// TransactionRepository
/// 處理所有與「交易紀錄」相關的業務邏輯
class TransactionRepository {
  final FirestoreService _firestoreService = FirestoreService();

  /// 新增交易
  /// 這會同時更新 Room 的 total_balance
  Future<String> addTransaction({
    required String roomId,
    required String payerId,
    required double amount,
    required String title,
    required DateTime date,
    String category = '其他',
    String splitType = 'equal',
  }) async {
    final tx = TransactionModel(
      id: '',
      coupleId: roomId, // TransactionModel still has coupleId field, let's keep it for now or rename later
      payerId: payerId,
      amount: amount,
      title: title,
      date: date,
      category: category,
      splitType: splitType,
    );

    // CRITICAL: 原子操作（新增交易 + 增加 total_balance）
    return _firestoreService.addTransactionAndIncrementBalance(
      roomId: roomId,
      payerId: payerId,
      amount: amount,
      transactionData: tx.toMap(),
    );
  }

  /// 監聽交易列表
  Stream<List<TransactionModel>> watchTransactions(String roomId) {
    return _firestoreService.watchTransactions(roomId).map((snapshot) {
      return snapshot.docs.map((doc) {
        return TransactionModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// 刪除交易
  Future<void> deleteTransaction({
    required String roomId,
    required String transactionId,
    required String payerId,
    required double amount,
  }) async {
    await _firestoreService.deleteTransaction(roomId, transactionId);
  }
}
