import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart';
import '../models/savings_transaction_model.dart';
import '../services/firestore_service.dart';

class JointPotRepository {
  final FirestoreService _firestoreService;

  JointPotRepository(this._firestoreService);

  /// 監聽 Room 資料 (獲取餘額)
  Stream<RoomModel?> watchRoom(String roomId) {
    return _firestoreService.watchRoom(roomId).map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return RoomModel.fromMap(data, snapshot.id);
    });
  }

  /// 監聽公基金交易紀錄
  Stream<List<SavingsTransactionModel>> watchSavingsTransactions(String roomId) {
    return _firestoreService.watchSavingsTransactions(roomId).map((snapshot) {
      return snapshot.docs.map((doc) {
        return SavingsTransactionModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// 執行存錢/提款交易
  Future<void> performTransaction({
    required String roomId,
    required SavingsTransactionModel transaction,
  }) async {
    await _firestoreService.performSavingsTransaction(
      roomId: roomId,
      transactionData: transaction.toMap(),
    );
  }

  /// 更新交易紀錄
  Future<void> updateTransaction({
    required String roomId,
    required String transactionId,
    required Map<String, dynamic> newData,
  }) async {
    await _firestoreService.updateSavingsTransaction(
      roomId: roomId,
      transactionId: transactionId,
      newData: newData,
    );
  }

  /// 刪除交易紀錄
  Future<void> deleteTransaction({
    required String roomId,
    required String transactionId,
  }) async {
    await _firestoreService.deleteSavingsTransaction(
      roomId: roomId,
      transactionId: transactionId,
    );
  }
}
