import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// SessionProvider
/// - 管理 FirebaseAuth 的 `User?`（是否登入）
/// - 同步 Firestore `users/{uid}`（是否已配對 current_couple_id）
class SessionProvider with ChangeNotifier {
  final AuthService _authService;
  final FirestoreService _firestore;

  StreamSubscription? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

  bool _isLoading = true;
  User? _firebaseUser;
  UserModel? _profile;
  String? _error;

  SessionProvider({
    AuthService? authService,
    FirestoreService? firestoreService,
  })  : _authService = authService ?? AuthService(),
        _firestore = firestoreService ?? FirestoreService() {
    _authSub = _authService.authStateChanges.listen(_onAuthChanged);
    // 立即同步一次（避免啟動瞬間 authStateChanges 還沒回來）
    _onAuthChanged(_authService.getCurrentUser());
  }

  bool get isLoading => _isLoading;
  User? get firebaseUser => _firebaseUser;
  UserModel? get profile => _profile;
  String? get error => _error;

  bool get isLoggedIn => _firebaseUser != null;
  bool get isPaired => (_profile?.currentCoupleId != null);

  /// 監聽目前 couple 文件（供 Dashboard / AddTransaction one-shot 取 partner uid）
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCurrentCoupleDoc() {
    final coupleId = _profile?.currentCoupleId;
    if (coupleId == null) {
      return const Stream.empty();
    }
    return _firestore.firestore.collection('couples').doc(coupleId).snapshots();
  }

  Future<void> _onAuthChanged(User? user) async {
    _error = null;
    _firebaseUser = user;

    await _userDocSub?.cancel();
    _userDocSub = null;

    if (user == null) {
      _profile = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    // 監聽 users/{uid}：配對完成時（current_couple_id 被更新）能自動切畫面
    _userDocSub = _firestore.watchUser(user.uid).listen(
      (snapshot) async {
        if (!snapshot.exists) {
          // 若 users 文件不存在，先建立最小資料（匿名登入 / 其他情況也能穩住流程）
          await _firestore.setUser(user.uid, {
            'uid': user.uid,
            'name': '',
            'email': user.email ?? '',
            'current_couple_id': null,
          });
          return;
        }

        _profile = UserModel.fromMap(snapshot.data()!, snapshot.id);
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.signInWithEmail(email: email, password: password);
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final cred = await _authService.signUpWithEmail(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;
      await _firestore.setUser(uid, {
        'uid': uid,
        'name': name,
        'email': email,
        'current_couple_id': null,
      });
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() => _authService.signOut();

  @override
  void dispose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }
}

