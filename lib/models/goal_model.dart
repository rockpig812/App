import 'package:cloud_firestore/cloud_firestore.dart';

/// Goal Model (儲蓄目標)
/// 對應 Firestore 的 couples/{coupleId}/goals 子集合
class GoalModel {
  final String id;
  final String coupleId;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final DateTime? deadline;
  final double monthlyRecurrenceAmount; // 每月預期存入金額

  GoalModel({
    required this.id,
    required this.coupleId,
    required this.title,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.deadline,
    this.monthlyRecurrenceAmount = 0.0,
  });

  factory GoalModel.fromMap(Map<String, dynamic> map, String id) {
    return GoalModel(
      id: id,
      coupleId: map['couple_id'] ?? '',
      title: map['title'] ?? '',
      targetAmount: (map['target_amount'] as num).toDouble(),
      currentAmount: (map['current_amount'] as num?)?.toDouble() ?? 0.0,
      deadline: map['deadline'] != null
          ? (map['deadline'] as Timestamp).toDate()
          : null,
      monthlyRecurrenceAmount:
          (map['monthly_recurrence_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'couple_id': coupleId,
      'title': title,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      if (deadline != null) 'deadline': Timestamp.fromDate(deadline!),
      'monthly_recurrence_amount': monthlyRecurrenceAmount,
    };
  }

  /// 計算完成百分比
  double get progressPercentage {
    if (targetAmount == 0) return 0.0;
    return (currentAmount / targetAmount * 100).clamp(0.0, 100.0);
  }

  /// 是否已完成
  bool get isCompleted => currentAmount >= targetAmount;

  GoalModel copyWith({
    String? id,
    String? coupleId,
    String? title,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    double? monthlyRecurrenceAmount,
  }) {
    return GoalModel(
      id: id ?? this.id,
      coupleId: coupleId ?? this.coupleId,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: deadline ?? this.deadline,
      monthlyRecurrenceAmount:
          monthlyRecurrenceAmount ?? this.monthlyRecurrenceAmount,
    );
  }
}
