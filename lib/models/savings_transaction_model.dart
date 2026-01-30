import 'package:cloud_firestore/cloud_firestore.dart';

/// SavingsTransaction Model
/// 對應 Firestore 的 couples/{coupleId}/savings_transactions 子集合
class SavingsTransactionModel {
  final String id;
  final String userId; // 操作者 UID
  final double amount; // 正數為存入，負數為提領/目標扣款
  final String title;
  final DateTime date;
  final bool isGoalDeduction; // 是否為達成目標時的自動扣款

  SavingsTransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.title,
    required this.date,
    this.isGoalDeduction = false,
  });

  factory SavingsTransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return SavingsTransactionModel(
      id: id,
      userId: map['user_id'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      title: map['title'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      isGoalDeduction: map['is_goal_deduction'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'amount': amount,
      'title': title,
      'date': Timestamp.fromDate(date),
      'is_goal_deduction': isGoalDeduction,
    };
  }

  SavingsTransactionModel copyWith({
    String? id,
    String? userId,
    double? amount,
    String? title,
    DateTime? date,
    bool? isGoalDeduction,
  }) {
    return SavingsTransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      title: title ?? this.title,
      date: date ?? this.date,
      isGoalDeduction: isGoalDeduction ?? this.isGoalDeduction,
    );
  }
}
