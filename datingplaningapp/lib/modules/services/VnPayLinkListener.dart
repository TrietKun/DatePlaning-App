import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import '../services/VNPayService.dart';
import '../services/paymentService.dart';

class VnPayLinkListener {
  StreamSubscription? _sub;
  final PaymentService _paymentService = PaymentService();
  final AppLinks _appLinks = AppLinks();

  // 🔹 Thêm Set để track các transaction đã xử lý
  final Set<String> _processedTransactions = {};
  bool _isProcessing = false;

  void startListening(BuildContext context) {
    // Lắng nghe deep link
    _sub = _appLinks.uriLinkStream.listen((Uri uri) async {
      print('🔗 Received deep link: $uri');

      // Kiểm tra xem có phải là VNPay callback không
      if (uri.scheme == 'myapp' && uri.host == 'vnpay_callback') {
        await _handleVNPayCallback(context, uri);
      }
    }, onError: (err) {
      print('❌ Deep link error: $err');
    });

    // Kiểm tra deep link khi app mở lại từ background
    _checkInitialLink(context);
  }

  // Kiểm tra link ban đầu khi app được mở từ deep link
  Future<void> _checkInitialLink(BuildContext context) async {
    try {
      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null) {
        print('🔗 Initial link: $initialUri');
        if (initialUri.scheme == 'myapp' &&
            initialUri.host == 'vnpay_callback') {
          await _handleVNPayCallback(context, initialUri);
        }
      }
    } catch (e) {
      print('❌ Error getting initial link: $e');
    }
  }

  Future<void> _handleVNPayCallback(BuildContext context, Uri uri) async {
    // 🔹 Tránh xử lý trùng lặp
    if (_isProcessing) {
      print('⚠️ Already processing a callback, skipping...');
      return;
    }

    try {
      _isProcessing = true;

      // 🔹 Parse params thủ công để giữ nguyên encoding
      final params = _parseQueryString(uri.query);
      final orderId = params['vnp_TxnRef'] ?? '';

      // 🔹 Kiểm tra xem transaction này đã được xử lý chưa
      if (_processedTransactions.contains(orderId)) {
        print('⚠️ Transaction $orderId already processed, skipping...');
        return;
      }

      print('📩 VNPay callback received:');
      print('Full URI: $uri');
      print('Raw query: ${uri.query}');
      print('Params count: ${params.length}');
      print('Order ID: $orderId');
      print('---');
      params.forEach((key, value) {
        print('  $key: $value');
      });
      print('---');

      // Validate chữ ký
      print('🔐 Validating signature...');
      final isValid = VNPayService.validateCallback(params);

      if (!isValid) {
        _showDialog(
          context,
          title: '❌ Lỗi bảo mật',
          message: 'Chữ ký không hợp lệ. Vui lòng liên hệ hỗ trợ.',
          isSuccess: false,
        );
        return;
      }

      // Kiểm tra response code
      final responseCode = params['vnp_ResponseCode'];
      final isSuccess = responseCode == '00';

      if (isSuccess) {
        // 🔹 Đánh dấu transaction đã xử lý TRƯỚC KHI gọi service
        _processedTransactions.add(orderId);

        // Xử lý callback qua PaymentService
        final processed = await _paymentService.handleVNPayCallback(params);

        if (processed) {
          final amount = int.tryParse(params['vnp_Amount'] ?? '0') ?? 0;
          final transactionNo = params['vnp_TransactionNo'] ?? '';

          _showDialog(
            context,
            title: '🎉 Thanh toán thành công',
            message: 'Mã đơn hàng: $orderId\n'
                'Số tiền: ${_formatAmount(amount)} VNĐ\n'
                'Mã GD VNPay: $transactionNo\n\n'
                'Tài khoản của bạn đã được cập nhật!',
            isSuccess: true,
          );
        } else {
          // 🔹 Nếu xử lý thất bại, remove khỏi set để có thể retry
          _processedTransactions.remove(orderId);

          _showDialog(
            context,
            title: '❌ Lỗi xử lý',
            message: 'Không thể cập nhật giao dịch. Vui lòng liên hệ hỗ trợ.',
            isSuccess: false,
          );
        }
      } else {
        // Thanh toán thất bại
        final errorMessage = _getErrorMessage(responseCode);
        _showDialog(
          context,
          title: '❌ Thanh toán thất bại',
          message: errorMessage,
          isSuccess: false,
        );
      }
    } catch (e) {
      print('❌ Error handling VNPay callback: $e');
      _showDialog(
        context,
        title: '❌ Có lỗi xảy ra',
        message: 'Không thể xử lý kết quả thanh toán: $e',
        isSuccess: false,
      );
    } finally {
      _isProcessing = false;
    }
  }

  // 🔹 Parse query string thủ công để giữ nguyên encoding từ VNPay
  Map<String, String> _parseQueryString(String query) {
    final params = <String, String>{};
    if (query.isEmpty) return params;

    for (final pair in query.split('&')) {
      final parts = pair.split('=');
      if (parts.length == 2) {
        final key = parts[0];
        final value = parts[1]; // Giữ nguyên, không decode
        params[key] = value;
      }
    }
    return params;
  }

  void _showDialog(
    BuildContext context, {
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    // 🔹 Kiểm tra context còn valid không
    if (!context.mounted) {
      print('⚠️ Context not mounted, skipping dialog');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isSuccess
                    ? [
                        Colors.green.shade400,
                        Colors.green.shade600,
                      ]
                    : [
                        Colors.red.shade400,
                        Colors.red.shade600,
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSuccess ? Icons.check_circle : Icons.error,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Message
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();

                      // 🔹 Nếu thành công, không pop màn hình payment
                      // Để PaymentScreen tự refresh qua didChangeDependencies hoặc setState
                      if (isSuccess) {
                        print(
                            '✅ Dialog closed, payment screen should refresh automatically');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: isSuccess
                          ? Colors.green.shade600
                          : Colors.red.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Đóng',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatAmount(int amount) {
    final value = amount / 100;
    return value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  String _getErrorMessage(String? code) {
    switch (code) {
      case '07':
        return 'Trừ tiền thành công. Giao dịch bị nghi ngờ (liên quan tới lừa đảo, giao dịch bất thường).';
      case '09':
        return 'Thẻ/Tài khoản chưa đăng ký dịch vụ InternetBanking tại ngân hàng.';
      case '10':
        return 'Khách hàng xác thực thông tin thẻ/tài khoản không đúng quá 3 lần';
      case '11':
        return 'Đã hết hạn chờ thanh toán. Vui lòng thực hiện lại giao dịch.';
      case '12':
        return 'Thẻ/Tài khoản của khách hàng bị khóa.';
      case '13':
        return 'Quý khách nhập sai mật khẩu xác thực giao dịch (OTP).';
      case '24':
        return 'Khách hàng hủy giao dịch';
      case '51':
        return 'Tài khoản không đủ số dư để thực hiện giao dịch.';
      case '65':
        return 'Tài khoản đã vượt quá hạn mức giao dịch trong ngày.';
      case '75':
        return 'Ngân hàng thanh toán đang bảo trì.';
      case '79':
        return 'Nhập sai mật khẩu thanh toán quá số lần quy định.';
      default:
        return 'Giao dịch thất bại. Mã lỗi: $code';
    }
  }

  void dispose() {
    _sub?.cancel();
    _processedTransactions.clear(); // 🔹 Clear khi dispose
    _isProcessing = false;
  }
}
