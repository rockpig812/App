/// User Model
/// 對應 Firestore 的 users 集合
class UserModel {
  final String uid;
  final String name;
  final String email;
  final List<String> joinedRoomIds; // 加入的房間列表
  final String? lastActiveRoomId; // 上次離開時所在的空間

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.joinedRoomIds = const [],
    this.lastActiveRoomId,
  });

  /// 從 Firestore Map 建立 UserModel
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      joinedRoomIds: List<String>.from(map['joined_room_ids'] ?? []),
      lastActiveRoomId: map['last_active_room_id'],
    );
  }

  /// 轉換為 Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'joined_room_ids': joinedRoomIds,
      if (lastActiveRoomId != null) 'last_active_room_id': lastActiveRoomId,
    };
  }

  /// 複製並更新部分欄位 (Immutable update pattern)
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    List<String>? joinedRoomIds,
    String? lastActiveRoomId,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      joinedRoomIds: joinedRoomIds ?? this.joinedRoomIds,
      lastActiveRoomId: lastActiveRoomId ?? this.lastActiveRoomId,
    );
  }
}
