import 'package:flutter/foundation.dart';
import '../models/couple_model.dart';
import '../repositories/couple_repository.dart';
import '../repositories/auth_repository.dart';

/// CoupleProvider
/// 管理當前使用者的 Couple 狀態
class CoupleProvider with ChangeNotifier {
  final CoupleRepository _coupleRepository = CoupleRepository();
  final AuthRepository _authRepository = AuthRepository();

  CoupleModel? _currentCouple;
  bool _isLoading = false;
  String? _error;

  CoupleModel? get currentCouple => _currentCouple;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasCouple => _currentCouple != null;

  /// 載入使用者的 Couple
  Future<void> loadCouple() async {
    final authUser = _authRepository.currentUser;
    if (authUser == null) {
      _currentCouple = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // AuthRepository.currentUser 是 firebase_auth 的 User，沒有 currentCoupleId。
      // currentCoupleId 存在於 Firestore 的 users 文件中，需先載入 UserModel。
      final userModel = await _authRepository.getUserData(authUser.uid);
      final coupleId = userModel?.currentCoupleId;

      if (coupleId == null) {
        _currentCouple = null;
        return;
      }

      _currentCouple = await _coupleRepository.getCouple(coupleId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 建立新的 Couple Space
  Future<Map<String, String>> createCoupleSpace(String userId2) async {
    final user = _authRepository.currentUser;
    if (user == null) throw Exception('使用者未登入');

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _coupleRepository.createCoupleSpace(
        userId1: user.uid,
        userId2: userId2,
      );

      // 重新載入 Couple
      await loadCouple();

      return result;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 使用邀請碼加入 Couple Space
  Future<void> joinCoupleSpace(String inviteCode) async {
    final user = _authRepository.currentUser;
    if (user == null) throw Exception('使用者未登入');

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final coupleId = await _coupleRepository.joinCoupleSpace(
        inviteCode: inviteCode,
        userId: user.uid,
      );

      if (coupleId != null) {
        // 更新使用者的 current_couple_id (這裡需要透過 AuthRepository 更新)
        // 注意：實際實作時，可能需要更新 UserModel 的 currentCoupleId
        await loadCouple();
      } else {
        throw Exception('找不到對應的 Couple Space');
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 監聽 Couple 資料變更
  Stream<CoupleModel?> watchCouple() {
    if (_currentCouple == null) {
      return Stream.value(null);
    }
    return _coupleRepository.watchCouple(_currentCouple!.id);
  }

  /// 取得淨餘額
  Map<String, double>? getNetBalance() {
    return _currentCouple?.calculateNetBalance();
  }
}
