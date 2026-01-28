import '../models/goal_model.dart';
import '../models/contribution_model.dart';
import '../services/firestore_service.dart';

/// GoalRepository
/// 處理所有與「儲蓄目標」相關的業務邏輯
class GoalRepository {
  final FirestoreService _firestoreService = FirestoreService();

  /// 新增儲蓄目標
  Future<String> addGoal({
    required String coupleId,
    required String title,
    required double targetAmount,
    DateTime? deadline,
    double monthlyRecurrenceAmount = 0.0,
  }) async {
    return await _firestoreService.addGoal(
      coupleId,
      GoalModel(
        id: '', // 會在 addGoal 中產生
        coupleId: coupleId,
        title: title,
        targetAmount: targetAmount,
        deadline: deadline,
        monthlyRecurrenceAmount: monthlyRecurrenceAmount,
      ).toMap(),
    );
  }

  /// 更新儲蓄目標
  Future<void> updateGoal({
    required String coupleId,
    required String goalId,
    String? title,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    double? monthlyRecurrenceAmount,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (targetAmount != null) updates['target_amount'] = targetAmount;
    if (currentAmount != null) updates['current_amount'] = currentAmount;
    if (deadline != null) updates['deadline'] = deadline;
    if (monthlyRecurrenceAmount != null) {
      updates['monthly_recurrence_amount'] = monthlyRecurrenceAmount;
    }

    await _firestoreService.updateGoal(coupleId, goalId, updates);
  }

  /// 監聽儲蓄目標列表
  Stream<List<GoalModel>> watchGoals(String coupleId) {
    return _firestoreService.watchGoals(coupleId).map((snapshot) {
      return snapshot.docs.map((doc) {
        return GoalModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// 取得單一儲蓄目標
  Future<GoalModel?> getGoal(String coupleId, String goalId) async {
    final data = await _firestoreService.getGoal(coupleId, goalId);
    if (data == null) return null;
    return GoalModel.fromMap(data, goalId);
  }

  /// 新增存入紀錄 (Contribution)
  Future<String> addContribution({
    required String coupleId,
    required String goalId,
    required String userId,
    required double amount,
    required DateTime date,
  }) async {
    // 使用 Firestore Transaction 以原子方式：新增 contribution + 遞增 current_amount
    return _firestoreService.addContributionAndIncrementGoal(
      coupleId: coupleId,
      goalId: goalId,
      userId: userId,
      amount: amount,
      date: date,
    );
  }

  /// 快速存入 (使用 monthly_recurrence_amount)
  Future<String> quickDeposit({
    required String coupleId,
    required String goalId,
    required String userId,
  }) async {
    final goal = await getGoal(coupleId, goalId);
    if (goal == null) {
      throw Exception('找不到這個儲蓄目標');
    }

    if (goal.monthlyRecurrenceAmount <= 0) {
      throw Exception('此目標沒有設定每月存入金額');
    }

    return await addContribution(
      coupleId: coupleId,
      goalId: goalId,
      userId: userId,
      amount: goal.monthlyRecurrenceAmount,
      date: DateTime.now(),
    );
  }

  /// 監聽存入紀錄列表
  Stream<List<ContributionModel>> watchContributions(
    String coupleId,
    String goalId,
  ) {
    return _firestoreService.watchContributions(coupleId, goalId).map((snapshot) {
      return snapshot.docs.map((doc) {
        return ContributionModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }
}
