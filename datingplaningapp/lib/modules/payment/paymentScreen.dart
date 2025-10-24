import 'package:datingplaningapp/modules/services/VnPayLinkListener.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
// Import các services và entities
import '../services/VNPayService.dart';
import '../services/paymentService.dart';
import '../entities/app_user.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({Key? key}) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentService _paymentService = PaymentService();
  final VnPayLinkListener _linkListener = VnPayLinkListener();

  String? selectedPackage;
  bool isProcessing = false;

  final List<PackageInfo> packages = [
    PackageInfo(
      id: 'basic',
      name: 'Gói Cơ Bản',
      amount: 50000,
      coins: 500,
      icon: Icons.monetization_on,
      color: Colors.blue,
    ),
    PackageInfo(
      id: 'standard',
      name: 'Gói Tiêu Chuẩn',
      amount: 100000,
      coins: 1100,
      icon: Icons.stars,
      color: Colors.purple,
      bonus: '+10% xu',
    ),
    PackageInfo(
      id: 'premium',
      name: 'Gói Cao Cấp',
      amount: 200000,
      coins: 2300,
      icon: Icons.diamond,
      color: Colors.orange,
      bonus: '+15% xu',
    ),
    PackageInfo(
      id: 'vip_1month',
      name: 'VIP 1 Tháng',
      amount: 300000,
      duration: '30 ngày',
      icon: Icons.workspace_premium,
      color: Colors.amber,
      isVip: true,
    ),
    PackageInfo(
      id: 'vip_3months',
      name: 'VIP 3 Tháng',
      amount: 800000,
      duration: '90 ngày',
      icon: Icons.workspace_premium,
      color: Colors.deepPurple,
      isVip: true,
      bonus: 'Tiết kiệm 11%',
    ),
    PackageInfo(
      id: 'vip_1year',
      name: 'VIP 1 Năm',
      amount: 3000000,
      duration: '365 ngày',
      icon: Icons.workspace_premium,
      color: Colors.red,
      isVip: true,
      bonus: 'Tiết kiệm 17%',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // 🔹 BẮT ĐẦU LẮNG NGHE DEEP LINK
    _linkListener.startListening(context);
  }

  @override
  void dispose() {
    // 🔹 HỦY LISTENER KHI WIDGET BỊ DISPOSE
    _linkListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nạp Tiền & Nâng Cấp VIP'),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildUserInfoCard(),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Gói Nạp Xu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...packages
                    .where((p) => !p.isVip)
                    .map((p) => _buildPackageCard(p)),
                const SizedBox(height: 24),
                const Text(
                  'Gói VIP',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...packages
                    .where((p) => p.isVip)
                    .map((p) => _buildPackageCard(p)),
              ],
            ),
          ),
          if (selectedPackage != null) _buildPaymentButton(),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: currentUser?.isVipActive == true
              ? [Colors.amber, Colors.orange]
              : [Colors.blue, Colors.purple],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Icon(
              currentUser?.isVipActive == true
                  ? Icons.workspace_premium
                  : Icons.person,
              size: 32,
              color: Colors.amber,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentUser?.name ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentUser?.isVipActive == true
                      ? 'VIP đến ${_formatDate(currentUser!.vipExpiryDate!)}'
                      : 'Người dùng thường',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(Icons.monetization_on,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${currentUser?.coins ?? 0}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Text(
                'Xu',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(PackageInfo package) {
    final isSelected = selectedPackage == package.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? package.color : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => selectedPackage = package.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: package.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(package.icon, color: package.color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      package.isVip ? package.duration! : '${package.coins} xu',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    if (package.bonus != null)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          package.bonus!,
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${_formatCurrency(package.amount)}đ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: package.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentButton() {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              gradient: isProcessing
                  ? LinearGradient(
                      colors: [Colors.grey.shade400, Colors.grey.shade300],
                    )
                  : LinearGradient(
                      colors: [
                        Colors.blue.shade600,
                        Colors.purple.shade500,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isProcessing
                      ? Colors.grey.withOpacity(0.3)
                      : Colors.blue.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isProcessing ? null : _processPayment,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: isProcessing
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Đang xử lý thanh toán...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.9),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.payment_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Thanh Toán Ngay',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ));
  }

  Future<void> _processPayment() async {
    if (currentUser == null || selectedPackage == null) return;

    setState(() => isProcessing = true);

    try {
      // Tạo transaction
      final transaction = await _paymentService.createDepositTransaction(
        userId: currentUser!.uid,
        packageId: selectedPackage!,
      );

      print('✅ Transaction created: ${transaction.id}');

      // Tạo URL thanh toán VNPay
      final paymentUrl = VNPayService.createPaymentUrl(
        orderId: transaction.id,
        amount: transaction.amount,
        orderInfo: 'Nap tien - $selectedPackage',
      );

      print('💳 Opening payment URL...');

      // Mở trình duyệt thanh toán
      final uri = Uri.parse(paymentUrl);
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (launched) {
          print('✅ Payment URL opened successfully');

          // Hiển thị thông báo cho user
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đang chuyển đến trang thanh toán...'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        throw Exception('Không thể mở URL thanh toán');
      }
    } catch (e) {
      print('❌ Payment error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isProcessing = false);
      }
    }
  }

  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class PackageInfo {
  final String id;
  final String name;
  final int amount;
  final int? coins;
  final String? duration;
  final IconData icon;
  final Color color;
  final String? bonus;
  final bool isVip;

  PackageInfo({
    required this.id,
    required this.name,
    required this.amount,
    this.coins,
    this.duration,
    required this.icon,
    required this.color,
    this.bonus,
    this.isVip = false,
  });
}
