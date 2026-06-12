import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';

/// TransactionRepository
/// 處理所有與「交易紀錄」相關的業務邏輯
class TransactionRepository {
  final FirestoreService _firestoreService = FirestoreService();
  final _uuid = const Uuid();

  /// 樂觀新增交易 (零延遲)
  /// 利用 Firestore 的 Persistence 機制，不 await 結果
  void addTransactionOptimistically({
    required String roomId,
    required String payerId,
    required double amount,
    required String title,
    required DateTime date,
    String? id, // 接收預先產生的 ID
    String category = '其他',
    String splitType = 'equal',
  }) {
    final txId = id ?? _uuid.v4();
    final tx = TransactionModel(
      id: txId,
      roomId: roomId,
      payerId: payerId,
      amount: amount,
      title: title,
      date: date,
      category: category,
      splitType: splitType,
    );

    // 使用 WriteBatch 確保原子性，但不 await
    final batch = _firestoreService.firestore.batch();
    
    final roomRef = _firestoreService.firestore.collection('rooms').doc(roomId);
    final txRef = roomRef.collection('transactions').doc(txId);

    batch.set(txRef, tx.toMap());
    batch.update(roomRef, {
      'total_balance.$payerId': FieldValue.increment(amount),
    });

    // 這裡不 await，讓 Firestore SDK 在背景處理排隊與同步
    batch.commit().catchError((e) {
      print('Optimistic update failed in background: $e');
    });
  }

  /// 更新交易紀錄 (原子操作)
  Future<void> updateTransaction({
    required String roomId,
    required String transactionId,
    required String payerId,
    required double oldAmount,
    required double newAmount,
    required Map<String, dynamic> newData,
  }) async {
    final batch = _firestoreService.firestore.batch();
    final roomRef = _firestoreService.firestore.collection('rooms').doc(roomId);
    final txRef = roomRef.collection('transactions').doc(transactionId);

    batch.update(txRef, newData);
    
    final diff = newAmount - oldAmount;
    if (diff != 0) {
      batch.update(roomRef, {
        'total_balance.$payerId': FieldValue.increment(diff),
      });
    }

    return batch.commit();
  }

  /// 監聽交易列表 (包含 metadata)
  Stream<List<TransactionModel>> watchTransactions(String roomId) {
    return _firestoreService.watchTransactions(roomId).map((snapshot) {
      return snapshot.docs.map((doc) {
        // hasPendingWrites 為 true 代表資料還在本地緩存中，尚未同步到 Server
        final isSyncing = doc.metadata.hasPendingWrites;
        return TransactionModel.fromMap(doc.data(), doc.id, isSyncing: isSyncing);
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
    // 刪除同樣建議做成原子操作
    final batch = _firestoreService.firestore.batch();
    final roomRef = _firestoreService.firestore.collection('rooms').doc(roomId);
    final txRef = roomRef.collection('transactions').doc(transactionId);

    batch.delete(txRef);
    batch.update(roomRef, {
      'total_balance.$payerId': FieldValue.increment(-amount),
    });

    return batch.commit();
  }
}
