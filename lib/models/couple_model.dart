/// Couple Model
/// 對應 Firestore 的 couples 集合
/// 這是整個 App 的核心資料結構
class CoupleModel {
  final String id;
  final List<String> userIds; // 兩個使用者的 UID
  final Map<String, double> totalBalance; // {uid1: paid_total, uid2: paid_total}
  final double jointPotBalance; // 公基金總額
  final String? inviteCode; // 6 位數邀請碼

  CoupleModel({
    required this.id,
    required this.userIds,
    required this.totalBalance,
    this.jointPotBalance = 0.0,
    this.inviteCode,
  });

  factory CoupleModel.fromMap(Map<String, dynamic> map, String id) {
    // Firestore 的 Map 需要轉換型別
    final balanceMap = map['total_balance'] as Map<String, dynamic>? ?? {};
    final balance = balanceMap.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    );

    return CoupleModel(
      id: id,
      userIds: List<String>.from(map['user_ids'] ?? []),
      totalBalance: balance,
      jointPotBalance: (map['joint_pot_balance'] as num?)?.toDouble() ?? 0.0,
      inviteCode: map['invite_code'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_ids': userIds,
      'total_balance': totalBalance,
      'joint_pot_balance': jointPotBalance,
      if (inviteCode != null) 'invite_code': inviteCode,
    };
  }

  /// 計算淨餘額 (Net Balance)
  /// 例如：如果 Alice 付了 $1000，Bob 付了 $500，則 Alice 應得 $250，Bob 欠 $250
  /// 返回：{uid1: net_amount, uid2: net_amount}
  /// 正數表示「應得」，負數表示「應付」
  Map<String, double> calculateNetBalance() {
    if (userIds.length != 2) return {};

    final uid1 = userIds[0];
    final uid2 = userIds[1];
    final paid1 = totalBalance[uid1] ?? 0.0;
    final paid2 = totalBalance[uid2] ?? 0.0;
    final totalPaid = paid1 + paid2;
    final perPerson = totalPaid / 2;

    return {
      uid1: paid1 - perPerson, // 如果為正，表示 uid1 應得；負數表示應付
      uid2: paid2 - perPerson,
    };
  }

  CoupleModel copyWith({
    String? id,
    List<String>? userIds,
    Map<String, double>? totalBalance,
    double? jointPotBalance,
    String? inviteCode,
  }) {
    return CoupleModel(
      id: id ?? this.id,
      userIds: userIds ?? this.userIds,
      totalBalance: totalBalance ?? this.totalBalance,
      jointPotBalance: jointPotBalance ?? this.jointPotBalance,
      inviteCode: inviteCode ?? this.inviteCode,
    );
  }
}
