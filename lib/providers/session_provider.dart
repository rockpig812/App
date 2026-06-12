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
  bool get isJoinedRoom => (_profile?.joinedRoomIds.isNotEmpty ?? false);

  /// 監聽目前 room 文件
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCurrentRoomDoc() {
    final roomId = _profile?.lastActiveRoomId;
    if (roomId == null) {
      return const Stream.empty();
    }
    return _firestore.firestore.collection('rooms').doc(roomId).snapshots();
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

    // 監聽 users/{uid}
    _userDocSub = _firestore.watchUser(user.uid).listen(
      (snapshot) async {
        try {
          if (!snapshot.exists) {
            // 1. 若 users 文件不存在，建立初始資料並給予個人空間
            final roomRef = await _firestore.createRoom({
              'name': 'My Personal Space',
              'user_ids': [user.uid],
              'total_balance': {user.uid: 0.0},
              'type': 'personal',
              'joint_pot_balance': 0.0,
            });

            await _firestore.setUser(user.uid, {
              'uid': user.uid,
              'name': '',
              'email': user.email ?? '',
              'joined_room_ids': [roomRef],
              'last_active_room_id': roomRef,
            });
            // 等待下一次 Stream 更新
            return;
          }

          final data = snapshot.data()!;
          bool needsUpdate = false;
          
          // 安全解析 joined_room_ids
          List<String> joinedIds = [];
          if (data['joined_room_ids'] is List) {
            joinedIds = List<String>.from(data['joined_room_ids']);
          }

          String? activeId = data['last_active_room_id'];

          // 2. 數據遷移邏輯 (Migration)
          if (data.containsKey('current_couple_id') && data['current_couple_id'] != null) {
            final oldId = data['current_couple_id'] as String;
            if (!joinedIds.contains(oldId)) {
              joinedIds.add(oldId);
              activeId ??= oldId;
              needsUpdate = true;
            }
          }

          // 3. 強制分配空間 (Auto-creation if empty)
          if (joinedIds.isEmpty) {
            final roomRef = await _firestore.createRoom({
              'name': 'My Personal Space',
              'user_ids': [user.uid],
              'total_balance': {user.uid: 0.0},
              'type': 'personal',
              'joint_pot_balance': 0.0,
            });
            joinedIds.add(roomRef);
            activeId = roomRef;
            needsUpdate = true;
          }

          // 4. 確保有活躍空間
          if (joinedIds.isNotEmpty && activeId == null) {
            activeId = joinedIds.first;
            needsUpdate = true;
          }

          if (needsUpdate) {
            await _firestore.setUser(user.uid, {
              'joined_room_ids': joinedIds,
              'last_active_room_id': activeId,
            });
            // 更新後 Stream 會再次觸發，我們在那次觸發再關閉 Loading
            return;
          }

          // 5. 資料已就緒，更新 Profile 並通知 UI
          _profile = UserModel.fromMap(data, snapshot.id);
          _error = null;
          _isLoading = false;
          notifyListeners();
          
        } catch (e) {
          _error = 'Sync Error: $e';
          _isLoading = false;
          notifyListeners();
        }
      },
      onError: (e) {
        _error = 'Firestore Error: $e';
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

      // 1. 先建立基本的 User 文件
      await _firestore.setUser(uid, {
        'uid': uid,
        'name': name,
        'email': email,
        'joined_room_ids': [],
        'last_active_room_id': null,
      });

      // 2. 自動為新用戶建立一個「個人空間」，讓其可以立即使用
      final roomRef = await _firestore.createRoom({
        'name': 'My Personal Space',
        'user_ids': [uid],
        'total_balance': {uid: 0.0},
        'type': 'personal',
        'joint_pot_balance': 0.0,
      });

      // 3. 更新 User 文件的房間資訊
      await _firestore.setUser(uid, {
        'joined_room_ids': [roomRef],
        'last_active_room_id': roomRef,
      });

    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signInAnonymously() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.signInAnonymously();
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

