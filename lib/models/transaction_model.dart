import 'package:cloud_firestore/cloud_firestore.dart';

/// Transaction Model
/// 對應 Firestore 的 couples/{coupleId}/transactions 子集合
class TransactionModel {
  final String id;
  final String coupleId; // 所屬的 couple
  final String payerId; // 付款者 UID
  final double amount;
  final String title;
  final DateTime date;
  final String category; // 'household', 'food', etc.
  final String splitType; // "equal" (均分) 或其他未來擴充類型

  TransactionModel({
    required this.id,
    required this.coupleId,
    required this.payerId,
    required this.amount,
    required this.title,
    required this.date,
    this.category = 'other',
    this.splitType = 'equal',
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return TransactionModel(
      id: id,
      coupleId: map['couple_id'] ?? '',
      payerId: map['payer_id'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      title: map['title'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      category: map['category'] ?? 'other',
      splitType: map['split_type'] ?? 'equal',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'couple_id': coupleId,
      'payer_id': payerId,
      'amount': amount,
      'title': title,
      'date': Timestamp.fromDate(date),
      'category': category,
      'split_type': splitType,
    };
  }

  TransactionModel copyWith({
    String? id,
    String? coupleId,
    String? payerId,
    double? amount,
    String? title,
    DateTime? date,
    String? category,
    String? splitType,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      coupleId: coupleId ?? this.coupleId,
      payerId: payerId ?? this.payerId,
      amount: amount ?? this.amount,
      title: title ?? this.title,
      date: date ?? this.date,
      category: category ?? this.category,
      splitType: splitType ?? this.splitType,
    );
  }
}
