import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';

/// TransactionProvider
/// 管理交易紀錄的狀態
class TransactionProvider with ChangeNotifier {
  final TransactionRepository _transactionRepository = TransactionRepository();

  final List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _error;

  List<TransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 新增交易
  Future<void> addTransaction({
    required String coupleId,
    required String payerId,
    required double amount,
    required String title,
    required DateTime date,
    String category = '其他',
    String splitType = 'equal',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _transactionRepository.addTransaction(
        coupleId: coupleId,
        payerId: payerId,
        amount: amount,
        title: title,
        date: date,
        category: category,
        splitType: splitType,
      );
      // StreamBuilder 會自動更新，這裡不需要手動更新 _transactions
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 刪除交易
  Future<void> deleteTransaction({
    required String coupleId,
    required String transactionId,
    required String payerId,
    required double amount,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _transactionRepository.deleteTransaction(
        coupleId: coupleId,
        transactionId: transactionId,
        payerId: payerId,
        amount: amount,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 監聽交易列表 (返回 Stream，供 StreamBuilder 使用)
  Stream<List<TransactionModel>> watchTransactions(String coupleId) {
    return _transactionRepository.watchTransactions(coupleId);
  }
}
