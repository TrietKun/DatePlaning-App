enum TransactionType {
  deposit, // Nạp tiền
  upgrade, // Nâng cấp VIP
  purchase, // Mua hàng
}

enum TransactionStatus {
  pending,
  success,
  failed,
  cancelled,
}

class Transaction {
  final String id;
  final String userId;
  final TransactionType type;
  final TransactionStatus status;
  final int amount; // Số tiền VND
  final int coins; // Số xu nhận được
  final String? vnpayTransactionId;
  final DateTime createdAt;
  final DateTime? completedAt;
  final Map<String, dynamic>? metadata;

  Transaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.amount,
    required this.coins,
    this.vnpayTransactionId,
    required this.createdAt,
    this.completedAt,
    this.metadata,
  });

  factory Transaction.fromMap(String id, Map<String, dynamic> data) {
    return Transaction(
      id: id,
      userId: data["userId"],
      type: TransactionType.values.firstWhere(
        (e) => e.toString() == 'TransactionType.${data["type"]}',
      ),
      status: TransactionStatus.values.firstWhere(
        (e) => e.toString() == 'TransactionStatus.${data["status"]}',
      ),
      amount: data["amount"],
      coins: data["coins"] ?? 0,
      vnpayTransactionId: data["vnpayTransactionId"],
      createdAt: DateTime.parse(data["createdAt"]),
      completedAt: data["completedAt"] != null 
          ? DateTime.parse(data["completedAt"]) 
          : null,
      metadata: data["metadata"],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "userId": userId,
      "type": type.toString().split('.').last,
      "status": status.toString().split('.').last,
      "amount": amount,
      "coins": coins,
      "vnpayTransactionId": vnpayTransactionId,
      "createdAt": createdAt.toIso8601String(),
      "completedAt": completedAt?.toIso8601String(),
      "metadata": metadata,
    };
  }
}