import '../models/transaction_model.dart';
import '../services/firestore_service.dart';
import '../repositories/couple_repository.dart';

/// TransactionRepository
/// 處理所有與「交易紀錄」相關的業務邏輯
class TransactionRepository {
  final FirestoreService _firestoreService = FirestoreService();
  final CoupleRepository _coupleRepository = CoupleRepository();

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
    // 1. 新增交易紀錄到 Firestore
    final transactionId = await _firestoreService.addTransaction(
      coupleId,
      TransactionModel(
        id: '', // 會在 addTransaction 中產生
        coupleId: coupleId,
        payerId: payerId,
        amount: amount,
        title: title,
        date: date,
        category: category,
        splitType: splitType,
      ).toMap(),
    );

    // 2. 更新 Couple 的總餘額
    await _coupleRepository.updateTotalBalance(
      coupleId: coupleId,
      payerId: payerId,
      amount: amount,
    );

    return transactionId;
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
    // 1. 刪除交易
    await _firestoreService.deleteTransaction(coupleId, transactionId);

    // 2. 減少總餘額 (負數表示減少)
    await _coupleRepository.updateTotalBalance(
      coupleId: coupleId,
      payerId: payerId,
      amount: -amount,
    );
  }
}
