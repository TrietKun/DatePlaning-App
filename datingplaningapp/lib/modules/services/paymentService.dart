import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:datingplaningapp/modules/entities/transaction.dart';
import 'package:datingplaningapp/modules/services/VNPayService.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Tạo giao dịch nạp tiền
  Future<Transaction> createDepositTransaction({
    required String userId,
    required String packageId,
  }) async {
    final package = VNPayService.packages[packageId];
    if (package == null) throw Exception("Gói không tồn tại");

    final transaction = Transaction(
      id: '', // Firestore sẽ tạo ID
      userId: userId,
      type: packageId.contains('vip') 
          ? TransactionType.upgrade 
          : TransactionType.deposit,
      status: TransactionStatus.pending,
      amount: package['amount']!,
      coins: package['coins']!,
      createdAt: DateTime.now(),
      metadata: {
        'packageId': packageId,
      },
    );

    final docRef = await _firestore
        .collection('transactions')
        .add(transaction.toMap());

    return transaction.copyWith(id: docRef.id);
  }

  // Xử lý callback từ VNPay
  Future<bool> handleVNPayCallback(Map<String, String> params) async {
    // Validate signature
    if (!VNPayService.validateCallback(params)) {
      print("Invalid VNPay signature");
      return false;
    }

    final orderId = params['vnp_TxnRef'];
    final responseCode = params['vnp_ResponseCode'];
    final isSuccess = responseCode == '00';

    // Cập nhật transaction
    final transactionRef = _firestore.collection('transactions').doc(orderId);
    final transactionDoc = await transactionRef.get();
    
    if (!transactionDoc.exists) return false;

    final transaction = Transaction.fromMap(orderId!, transactionDoc.data()!);

    await transactionRef.update({
      'status': isSuccess ? 'success' : 'failed',
      'completedAt': DateTime.now().toIso8601String(),
      'vnpayTransactionId': params['vnp_TransactionNo'],
    });

    if (isSuccess) {
      // Cập nhật user
      await _updateUserAfterPayment(transaction);
    }

    return isSuccess;
  }

  // Cập nhật user sau khi thanh toán thành công
  Future<void> _updateUserAfterPayment(Transaction transaction) async {
    final userRef = _firestore.collection('users').doc(transaction.userId);
    final userDoc = await userRef.get();
    
    if (!userDoc.exists) return;

    final userData = userDoc.data()!;
    final packageId = transaction.metadata?['packageId'] as String?;

    if (packageId?.contains('vip') == true) {
      // Nâng cấp VIP
      DateTime vipExpiry;
      final currentExpiry = userData['vipExpiryDate'] != null
          ? DateTime.parse(userData['vipExpiryDate'])
          : DateTime.now();

      if (packageId == 'vip_1month') {
        vipExpiry = currentExpiry.add(Duration(days: 30));
      } else if (packageId == 'vip_3months') {
        vipExpiry = currentExpiry.add(Duration(days: 90));
      } else if (packageId == 'vip_1year') {
        vipExpiry = currentExpiry.add(Duration(days: 365));
      } else {
        vipExpiry = currentExpiry;
      }

      await userRef.update({
        'isVip': true,
        'vipExpiryDate': vipExpiry.toIso8601String(),
      });
    } else {
      // Nạp xu
      final currentCoins = userData['coins'] ?? 0;
      await userRef.update({
        'coins': currentCoins + transaction.coins,
      });
    }

    // Thêm vào lịch sử giao dịch
    await userRef.update({
      'transactionHistory': FieldValue.arrayUnion([transaction.id]),
    });
  }

  // Lấy lịch sử giao dịch của user
  Stream<List<Transaction>> getUserTransactions(String userId) {
    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Transaction.fromMap(doc.id, doc.data()))
            .toList());
  }
}

// Extension method cho Transaction
extension TransactionExtension on Transaction {
  Transaction copyWith({
    String? id,
    String? userId,
    TransactionType? type,
    TransactionStatus? status,
    int? amount,
    int? coins,
    String? vnpayTransactionId,
    DateTime? createdAt,
    DateTime? completedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Transaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      coins: coins ?? this.coins,
      vnpayTransactionId: vnpayTransactionId ?? this.vnpayTransactionId,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}