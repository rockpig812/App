import 'package:flutter/foundation.dart';
import '../models/goal_model.dart';
import '../models/contribution_model.dart';
import '../repositories/goal_repository.dart';

/// GoalProvider
/// 管理儲蓄目標的狀態
class GoalProvider with ChangeNotifier {
  final GoalRepository _goalRepository = GoalRepository();

  final List<GoalModel> _goals = [];
  bool _isLoading = false;
  String? _error;

  List<GoalModel> get goals => _goals;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 新增儲蓄目標
  Future<void> addGoal({
    required String coupleId,
    required String title,
    required double targetAmount,
    DateTime? deadline,
    double monthlyRecurrenceAmount = 0.0,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _goalRepository.addGoal(
        coupleId: coupleId,
        title: title,
        targetAmount: targetAmount,
        deadline: deadline,
        monthlyRecurrenceAmount: monthlyRecurrenceAmount,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _goalRepository.updateGoal(
        coupleId: coupleId,
        goalId: goalId,
        title: title,
        targetAmount: targetAmount,
        currentAmount: currentAmount,
        deadline: deadline,
        monthlyRecurrenceAmount: monthlyRecurrenceAmount,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 新增存入紀錄
  Future<void> addContribution({
    required String coupleId,
    required String goalId,
    required String userId,
    required double amount,
    required DateTime date,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _goalRepository.addContribution(
        coupleId: coupleId,
        goalId: goalId,
        userId: userId,
        amount: amount,
        date: date,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 快速存入
  Future<void> quickDeposit({
    required String coupleId,
    required String goalId,
    required String userId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _goalRepository.quickDeposit(
        coupleId: coupleId,
        goalId: goalId,
        userId: userId,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 監聽儲蓄目標列表
  Stream<List<GoalModel>> watchGoals(String coupleId) {
    return _goalRepository.watchGoals(coupleId);
  }

  /// 監聽存入紀錄列表
  Stream<List<ContributionModel>> watchContributions(
    String coupleId,
    String goalId,
  ) {
    return _goalRepository.watchContributions(coupleId, goalId);
  }
}
