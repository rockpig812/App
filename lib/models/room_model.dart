enum RoomType { personal, group }

/// Room Model
/// 對應 Firestore 的 rooms 集合
class RoomModel {
  final String id;
  final String name;
  final List<String> userIds;
  final Map<String, double> totalBalance; // {uid: paid_total}
  final double jointPotBalance;
  final String? inviteCode;
  final RoomType type;

  RoomModel({
    required this.id,
    required this.name,
    required this.userIds,
    required this.totalBalance,
    this.jointPotBalance = 0.0,
    this.inviteCode,
    required this.type,
  });

  factory RoomModel.fromMap(Map<String, dynamic> map, String id) {
    final balanceMap = map['total_balance'] as Map<String, dynamic>? ?? {};
    final balance = balanceMap.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    );

    return RoomModel(
      id: id,
      name: map['name'] ?? '',
      userIds: List<String>.from(map['user_ids'] ?? []),
      totalBalance: balance,
      jointPotBalance: (map['joint_pot_balance'] as num?)?.toDouble() ?? 0.0,
      inviteCode: map['invite_code'],
      type: RoomType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'group'),
        orElse: () => RoomType.group,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'user_ids': userIds,
      'total_balance': totalBalance,
      'joint_pot_balance': jointPotBalance,
      'type': type.name,
      if (inviteCode != null) 'invite_code': inviteCode,
    };
  }

  /// 計算淨餘額 (Net Balance)
  /// 返回：{uid: net_amount}
  /// 正數表示「應得」，負數表示「應付」
  Map<String, double> calculateNetBalance() {
    if (userIds.isEmpty) return {};
    if (userIds.length == 1) return {userIds[0]: 0.0};

    double totalPaid = 0.0;
    for (var uid in userIds) {
      totalPaid += totalBalance[uid] ?? 0.0;
    }

    final perPerson = totalPaid / userIds.length;
    final Map<String, double> netBalances = {};

    for (var uid in userIds) {
      final paid = totalBalance[uid] ?? 0.0;
      netBalances[uid] = paid - perPerson;
    }

    return netBalances;
  }

  RoomModel copyWith({
    String? id,
    String? name,
    List<String>? userIds,
    Map<String, double>? totalBalance,
    double? jointPotBalance,
    String? inviteCode,
    RoomType? type,
  }) {
    return RoomModel(
      id: id ?? this.id,
      name: name ?? this.name,
      userIds: userIds ?? this.userIds,
      totalBalance: totalBalance ?? this.totalBalance,
      jointPotBalance: jointPotBalance ?? this.jointPotBalance,
      inviteCode: inviteCode ?? this.inviteCode,
      type: type ?? this.type,
    );
  }
}
