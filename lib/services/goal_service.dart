import '../models/goal_model.dart';
import '../models/contribution_model.dart';
import '../repositories/goal_repository.dart';

/// GoalService
/// 封裝 Goal 相關的 CRUD / 流水帳邏輯，給 UI / Provider 使用
/// 實作上委派給 GoalRepository，保持單一來源的商業邏輯
class GoalService {
  final GoalRepository _repo;

  GoalService({GoalRepository? repository}) : _repo = repository ?? GoalRepository();

  Future<String> addGoal({
    required String coupleId,
    required String title,
    required double targetAmount,
    DateTime? deadline,
  }) {
    return _repo.addGoal(
      coupleId: coupleId,
      title: title,
      targetAmount: targetAmount,
      deadline: deadline,
    );
  }

  Stream<List<GoalModel>> watchGoals(String coupleId) => _repo.watchGoals(coupleId);

  Future<GoalModel?> getGoal(String coupleId, String goalId) =>
      _repo.getGoal(coupleId, goalId);

  Stream<List<ContributionModel>> watchContributions(String coupleId, String goalId) =>
      _repo.watchContributions(coupleId, goalId);

  Future<String> addContribution({
    required String coupleId,
    required String goalId,
    required String userId,
    required double amount,
    required DateTime date,
  }) {
    return _repo.addContribution(
      coupleId: coupleId,
      goalId: goalId,
      userId: userId,
      amount: amount,
      date: date,
    );
  }
}

