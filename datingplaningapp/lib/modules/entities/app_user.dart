class AppUser {
  final String uid;
  final String email;
  final String? name;
  final String? partnerId;
  final bool isVip;
  final DateTime? vipExpiryDate;
  final int coins; // Số xu hiện có
  final List<String>? transactionHistory; // Lịch sử giao dịch

  AppUser({
    required this.uid,
    required this.email,
    this.name,
    this.partnerId,
    this.isVip = false,
    this.vipExpiryDate,
    this.coins = 0,
    this.transactionHistory,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      email: data["email"] ?? "",
      name: data["name"],
      partnerId: data["partnerId"],
      isVip: data["isVip"] ?? false,
      vipExpiryDate: data["vipExpiryDate"] != null
          ? DateTime.parse(data["vipExpiryDate"])
          : null,
      coins: data["coins"] ?? 0,
      transactionHistory: data["transactionHistory"] != null
          ? List<String>.from(data["transactionHistory"])
          : null,
    );
  }

  get profileImage => null;

  Map<String, dynamic> toMap() {
    return {
      "uid": uid,
      "email": email,
      "name": name,
      "partnerId": partnerId,
      "isVip": isVip,
      "vipExpiryDate": vipExpiryDate?.toIso8601String(),
      "coins": coins,
      "transactionHistory": transactionHistory,
    };
  }

  // Kiểm tra VIP còn hạn không
  bool get isVipActive {
    if (!isVip) return false;
    if (vipExpiryDate == null) return false;
    return DateTime.now().isBefore(vipExpiryDate!);
  }

  // Copy with method để cập nhật
  AppUser copyWith({
    String? uid,
    String? email,
    String? name,
    String? partnerId,
    bool? isVip,
    DateTime? vipExpiryDate,
    int? coins,
    List<String>? transactionHistory,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      partnerId: partnerId ?? this.partnerId,
      isVip: isVip ?? this.isVip,
      vipExpiryDate: vipExpiryDate ?? this.vipExpiryDate,
      coins: coins ?? this.coins,
      transactionHistory: transactionHistory ?? this.transactionHistory,
    );
  }
}

// Biến global
AppUser? currentUser;
