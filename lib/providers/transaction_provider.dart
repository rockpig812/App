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
  String? _activeRoomId;
  DateTime? _filterDate;
  
  // 存放本地端「尚未確認」的樂觀更新交易
  final Map<String, TransactionModel> _optimisticTransactions = {};

  List<TransactionModel> get transactions {
    // 合併遠端資料與本地樂觀更新資料
    final remoteIds = _transactions.map((t) => t.id).toSet();
    final optimisticOnly = _optimisticTransactions.values
        .where((t) => !remoteIds.contains(t.id))
        .toList();

    final all = [...optimisticOnly, ..._transactions];

    if (_filterDate != null) {
      return all.where((t) {
        return t.date.year == _filterDate!.year &&
               t.date.month == _filterDate!.month &&
               t.date.day == _filterDate!.day;
      }).toList();
    }
    return all;
  }

  DateTime? get filterDate => _filterDate;

  void setFilterDate(DateTime? date) {
    _filterDate = date;
    notifyListeners();
  }

  /// 開始監聽交易列表
  void startWatching(String roomId) {
    if (_activeRoomId == roomId) return;
    _activeRoomId = roomId;

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
        id: txId, // 傳入相同的 ID
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

  /// 更新交易
  Future<void> updateTransaction({
    required String roomId,
    required String transactionId,
    required String payerId,
    required double oldAmount,
    required double newAmount,
    required String title,
    required DateTime date,
    String category = '其他',
  }) async {
    try {
      await _transactionRepository.updateTransaction(
        roomId: roomId,
        transactionId: transactionId,
        payerId: payerId,
        oldAmount: oldAmount,
        newAmount: newAmount,
        newData: {
          'title': title,
          'amount': newAmount,
          'date': date,
          'category': category,
        },
      );
    } catch (e) {
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
