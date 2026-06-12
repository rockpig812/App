import 'package:flutter/foundation.dart';
import '../models/room_model.dart';
import '../repositories/room_repository.dart';
import '../repositories/auth_repository.dart';

/// RoomProvider
/// 管理當前使用者的 Room 狀態
class RoomProvider with ChangeNotifier {
  final RoomRepository _roomRepository = RoomRepository();
  final AuthRepository _authRepository = AuthRepository();

  RoomModel? _currentRoom;
  bool _isLoading = false;
  String? _error;

  RoomModel? get currentRoom => _currentRoom;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasRoom => _currentRoom != null;

  /// 載入使用者的 Room
  Future<void> loadRoom() async {
    final authUser = _authRepository.currentUser;
    if (authUser == null) {
      _currentRoom = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userModel = await _authRepository.getUserData(authUser.uid);
      final roomId = userModel?.lastActiveRoomId;

      if (roomId == null) {
        _currentRoom = null;
        return;
      }

      _currentRoom = await _roomRepository.getRoom(roomId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 建立新的 Room
  Future<Map<String, String>> createRoom(String name, RoomType type) async {
    final user = _authRepository.currentUser;
    if (user == null) throw Exception('使用者未登入');

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _roomRepository.createRoom(
        creatorId: user.uid,
        name: name,
        type: type,
      );

      await loadRoom();

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

  /// 使用邀請碼加入 Room
  Future<void> joinRoom(String inviteCode) async {
    final user = _authRepository.currentUser;
    if (user == null) throw Exception('使用者未登入');

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final roomId = await _roomRepository.joinRoom(
        inviteCode: inviteCode,
        userId: user.uid,
      );

      if (roomId != null) {
        await loadRoom();
      } else {
        throw Exception('找不到對應的 Space');
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

  /// 監聽 Room 資料變更
  Stream<RoomModel?> watchRoom() {
    if (_currentRoom == null) {
      return Stream.value(null);
    }
    return _roomRepository.watchRoom(_currentRoom!.id);
  }

  /// 取得淨餘額
  Map<String, double>? getNetBalance() {
    return _currentRoom?.calculateNetBalance();
  }
}
