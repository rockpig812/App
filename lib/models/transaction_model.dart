import 'package:cloud_firestore/cloud_firestore.dart';

/// Transaction Model
/// 對應 Firestore 的 rooms/{roomId}/transactions 子集合
class TransactionModel {
  final String id;
  final String roomId; // 所屬的 room
  final String payerId; // 付款者 UID
  final double amount;
  final String title;
  final DateTime date;
  final String category; // 'household', 'food', etc.
  final String splitType; // "equal" (均分) 或其他未來擴充類型
  final bool isSyncing; // 是否正在與後端同步 (樂觀更新用)

  TransactionModel({
    required this.id,
    required this.roomId,
    required this.payerId,
    required this.amount,
    required this.title,
    required this.date,
    this.category = 'other',
    this.splitType = 'equal',
    this.isSyncing = false,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map, String id, {bool isSyncing = false}) {
    return TransactionModel(
      id: id,
      roomId: map['room_id'] ?? map['couple_id'] ?? '',
      payerId: map['payer_id'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      title: map['title'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      category: map['category'] ?? 'other',
      splitType: map['split_type'] ?? 'equal',
      isSyncing: isSyncing,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'room_id': roomId,
      'payer_id': payerId,
      'amount': amount,
      'title': title,
      'date': Timestamp.fromDate(date),
      'category': category,
      'split_type': splitType,
      // isSyncing 不存入 Firestore
    };
  }

  TransactionModel copyWith({
    String? id,
    String? roomId,
    String? payerId,
    double? amount,
    String? title,
    DateTime? date,
    String? category,
    String? splitType,
    bool? isSyncing,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      payerId: payerId ?? this.payerId,
      amount: amount ?? this.amount,
      title: title ?? this.title,
      date: date ?? this.date,
      category: category ?? this.category,
      splitType: splitType ?? this.splitType,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}
