import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uni_links/uni_links.dart';
import '../services/VNPayService.dart';
import '../services/paymentService.dart';

class VnPayLinkListener {
  StreamSubscription? _sub;
  final PaymentService _paymentService = PaymentService();

  void startListening(BuildContext context) {
    // Lắng nghe deep link
    _sub = uriLinkStream.listen((Uri? uri) async {
      if (uri == null) return;

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
      final initialUri = await getInitialUri();
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
    try {
      // 🔹 Parse params thủ công để giữ nguyên encoding
      final params = _parseQueryString(uri.query);

      print('📩 VNPay callback received:');
      print('Full URI: $uri');
      print('Raw query: ${uri.query}');
      print('Params count: ${params.length}');
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
        // Xử lý callback qua PaymentService
        final processed = await _paymentService.handleVNPayCallback(params);

        if (processed) {
          final amount = int.tryParse(params['vnp_Amount'] ?? '0') ?? 0;
          final orderId = params['vnp_TxnRef'] ?? '';
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
    }
  }

  void _showDialog(
    BuildContext context, {
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess ? Colors.green : Colors.red,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSuccess ? Colors.green : Colors.red,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 15),
            ),
            if (isSuccess) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Số dư đã được cập nhật vào tài khoản',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: isSuccess ? Colors.green : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // Refresh màn hình payment để cập nhật UI
              if (isSuccess && context.mounted) {
                Navigator.of(context).pop(); // Quay lại màn hình trước
              }
            },
            child: const Text(
              'Đóng',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
  }

  _parseQueryString(String query) {
    final Map<String, String> params = {};
    final pairs = query.split('&');
    for (var pair in pairs) {
      final keyValue = pair.split('=');
      if (keyValue.length == 2) {
        final key = Uri.decodeComponent(keyValue[0]);
        final value = Uri.decodeComponent(keyValue[1]);
        params[key] = value;
      }
    }
    return params;
  }
}
