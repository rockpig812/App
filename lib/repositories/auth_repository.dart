import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

/// AuthRepository
/// 處理所有與身份驗證相關的業務邏輯
/// 類似 C++ 中的 Service 層，封裝業務規則
class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  /// 取得當前使用者
  User? get currentUser => _auth.currentUser;

  /// 監聽認證狀態變更
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// 匿名登入
  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  /// 使用 Email/Password 註冊
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // 建立使用者資料到 Firestore
    if (credential.user != null) {
      await _firestoreService.setUser(
        credential.user!.uid,
        UserModel(
          uid: credential.user!.uid,
          name: name,
          email: email,
        ).toMap(),
      );
    }

    return credential;
  }

  /// 使用 Email/Password 登入
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// 登出
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// 取得使用者資料 (從 Firestore)
  Future<UserModel?> getUserData(String uid) async {
    final data = await _firestoreService.getUser(uid);
    if (data == null) return null;
    return UserModel.fromMap(data, uid);
  }

  /// 更新使用者資料
  Future<void> updateUserData(String uid, UserModel user) async {
    await _firestoreService.setUser(uid, user.toMap());
  }
}
