import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

/// AuthProvider
/// 使用 Provider 模式管理認證狀態
/// 類似 C++ 中的 Singleton 或全局狀態管理器
class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  UserModel? _currentUser;
  bool _isLoading = true;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _init();
  }

  /// 初始化：監聽認證狀態變更
  void _init() {
    _authRepository.authStateChanges.listen((user) async {
      if (user != null) {
        // 使用者已登入，載入使用者資料
        _currentUser = await _authRepository.getUserData(user.uid);
      } else {
        // 使用者已登出
        _currentUser = null;
      }
      _isLoading = false;
      notifyListeners(); // 通知所有監聽者狀態已變更
    });
  }

  /// 匿名登入
  Future<void> signInAnonymously() async {
    try {
      await _authRepository.signInAnonymously();
      // _init() 中的監聽器會自動更新狀態
    } catch (e) {
      rethrow;
    }
  }

  /// Email/Password 註冊
  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      await _authRepository.signUpWithEmailAndPassword(
        email: email,
        password: password,
        name: name,
      );
      // _init() 中的監聽器會自動更新狀態
    } catch (e) {
      rethrow;
    }
  }

  /// Email/Password 登入
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _authRepository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // _init() 中的監聽器會自動更新狀態
    } catch (e) {
      rethrow;
    }
  }

  /// 登出
  Future<void> signOut() async {
    await _authRepository.signOut();
    _currentUser = null;
    notifyListeners();
  }

  /// 重新載入使用者資料
  Future<void> reloadUser() async {
    final user = _authRepository.currentUser;
    if (user != null) {
      _currentUser = await _authRepository.getUserData(user.uid);
      notifyListeners();
    }
  }
}
