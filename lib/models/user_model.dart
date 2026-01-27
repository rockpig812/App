/// User Model
/// 對應 Firestore 的 users 集合
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? currentCoupleId; // nullable: 可能還沒有配對

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.currentCoupleId,
  });

  /// 從 Firestore Map 建立 UserModel
  /// 類似 C++ 的建構子，但這裡是靜態工廠方法
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      currentCoupleId: map['current_couple_id'],
    );
  }

  /// 轉換為 Firestore Map
  /// 類似 C++ 的序列化方法 (toJson/toMap)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      if (currentCoupleId != null) 'current_couple_id': currentCoupleId,
    };
  }

  /// 複製並更新部分欄位 (Immutable update pattern)
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? currentCoupleId,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      currentCoupleId: currentCoupleId ?? this.currentCoupleId,
    );
  }
}
