import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';

/// TransactionProvider
/// 管理交易紀錄的狀態，支援「樂觀更新」與「零延遲」體驗
class TransactionProvider with ChangeNotifier {
  final TransactionRepository _transactionRepository = TransactionRepository();
  final _uuid = const Uuid();

  List<TransactionModel> _transactions = [];
  StreamSubscription? _transactionSubscription;
  
  // 存放本地端「尚未確認」的樂觀更新交易
  final Map<String, TransactionModel> _optimisticTransactions = {};

  List<TransactionModel> get transactions {
    // 合併遠端資料與本地樂觀更新資料
    // 若 ID 相同，以遠端資料 (Snapshot) 為準，因為它包含正確的同步狀態 (hasPendingWrites)
    final remoteIds = _transactions.map((t) => t.id).toSet();
    final optimisticOnly = _optimisticTransactions.values
        .where((t) => !remoteIds.contains(t.id))
        .toList();

    return [...optimisticOnly, ..._transactions];
  }

  /// 開始監聽交易列表
  void startWatching(String roomId) {
    _transactionSubscription?.cancel();
    _transactionSubscription = _transactionRepository.watchTransactions(roomId).listen((data) {
      _transactions = data;
      // 當遠端資料回傳時，若對應的 ID 已在 remote 中，則移除本地暫存
      for (var tx in data) {
        if (!tx.isSyncing) {
          _optimisticTransactions.remove(tx.id);
        }
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    super.dispose();
  }

  /// 新增交易 (樂觀更新版本)
  Future<void> addTransaction({
    required String roomId,
    required String payerId,
    required double amount,
    required String title,
    required DateTime date,
    String category = '其他',
    String splitType = 'equal',
  }) async {
    final txId = _uuid.v4();
    final newTx = TransactionModel(
      id: txId,
      roomId: roomId,
      payerId: payerId,
      amount: amount,
      title: title,
      date: date,
      category: category,
      splitType: splitType,
      isSyncing: true, // 初始標記為同步中
    );

    // 1. 立即更新本地 UI
    _optimisticTransactions[txId] = newTx;
    notifyListeners();

    // 2. 背景發送請求 (Repository 內部不 await)
    try {
      _transactionRepository.addTransactionOptimistically(
        roomId: roomId,
        payerId: payerId,
        amount: amount,
        title: title,
        date: date,
        category: category,
        splitType: splitType,
      );
      // 注意：這裡不 await 網路結果，達到零延遲
    } catch (e) {
      // 只有在呼叫失敗 (非網路失敗，因為 SDK 會處理網路) 時才移除
      _optimisticTransactions.remove(txId);
      notifyListeners();
      rethrow;
    }
  }

  /// 刪除交易
  Future<void> deleteTransaction({
    required String roomId,
    required String transactionId,
    required String payerId,
    required double amount,
  }) async {
    try {
      await _transactionRepository.deleteTransaction(
        roomId: roomId,
        transactionId: transactionId,
        payerId: payerId,
        amount: amount,
      );
    } catch (e) {
      rethrow;
    }
  }
}
