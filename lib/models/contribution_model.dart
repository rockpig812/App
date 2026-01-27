import 'package:cloud_firestore/cloud_firestore.dart';

/// Contribution Model (儲蓄目標的存入紀錄)
/// 對應 Firestore 的 couples/{coupleId}/goals/{goalId}/contributions 子集合
class ContributionModel {
  final String id;
  final String goalId;
  final String userId;
  final double amount;
  final DateTime date;

  ContributionModel({
    required this.id,
    required this.goalId,
    required this.userId,
    required this.amount,
    required this.date,
  });

  factory ContributionModel.fromMap(Map<String, dynamic> map, String id) {
    return ContributionModel(
      id: id,
      goalId: map['goal_id'] ?? '',
      userId: map['user_id'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'goal_id': goalId,
      'user_id': userId,
      'amount': amount,
      'date': Timestamp.fromDate(date),
    };
  }

  ContributionModel copyWith({
    String? id,
    String? goalId,
    String? userId,
    double? amount,
    DateTime? date,
  }) {
    return ContributionModel(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
    );
  }
}
