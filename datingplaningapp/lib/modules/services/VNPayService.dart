import 'dart:convert';
import 'package:crypto/crypto.dart';

class VNPayService {
  static const String vnpUrl =
      "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html";
  static const String vnpTmnCode = "IO13U7HK";
  static const String vnpHashSecret = "6JV609J6CW3PAHC9UBMMNFBHGN1A7VW6";
  static const String vnpReturnUrl = "myapp://vnpay_callback";

  static const Map<String, Map<String, int>> packages = {
    "basic": {"amount": 50000, "coins": 500},
    "standard": {"amount": 100000, "coins": 1100},
    "premium": {"amount": 200000, "coins": 2300},
    "vip_1month": {"amount": 300000, "coins": 0},
    "vip_3months": {"amount": 800000, "coins": 0},
    "vip_1year": {"amount": 3000000, "coins": 0},
  };

  static String createPaymentUrl({
    required String orderId,
    required int amount,
    required String orderInfo,
    String locale = 'vn',
  }) {
    final params = {
      'vnp_Version': '2.1.0',
      'vnp_Command': 'pay',
      'vnp_TmnCode': vnpTmnCode,
      'vnp_Amount': (amount * 100).toString(),
      'vnp_CreateDate': _getVnpDateTime(),
      'vnp_CurrCode': 'VND',
      'vnp_IpAddr': '127.0.0.1',
      'vnp_Locale': locale,
      'vnp_OrderInfo': orderInfo,
      'vnp_OrderType': 'other',
      'vnp_ReturnUrl': vnpReturnUrl,
      'vnp_TxnRef': orderId,
    };

    // Sắp xếp
    final sortedKeys = params.keys.toList()..sort();

    // 🔹 Tạo query string và sign data CÙNG LÚC
    final queryParts = <String>[];

    for (final key in sortedKeys) {
      final value = params[key]!;
      final encodedValue = Uri.encodeQueryComponent(value);
      queryParts.add('$key=$encodedValue');
    }

    final signData = queryParts.join('&');
    final secureHash = _hmacSHA512(vnpHashSecret, signData);

    print('Sign Data: $signData');
    print('Hash: $secureHash');

    return '$vnpUrl?$signData&vnp_SecureHash=$secureHash';
  }

  static bool validateCallback(Map<String, String> params) {
    final secureHash = params['vnp_SecureHash'];
    final paramsToHash = Map<String, String>.from(params)
      ..remove('vnp_SecureHash')
      ..remove('vnp_SecureHashType');

    final sortedParams = Map.fromEntries(
      paramsToHash.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );

    final rawData =
        sortedParams.entries.map((e) => '${e.key}=${e.value}').join('&');

    final calculatedHash = _hmacSHA512(vnpHashSecret, rawData);

    return secureHash == calculatedHash;
  }

  static String _hmacSHA512(String key, String data) {
    final hmac = Hmac(sha512, utf8.encode(key));
    final digest = hmac.convert(utf8.encode(data));
    return digest.toString(); // Đã là hex string đầy đủ
  }

  static String _getVnpDateTime() {
    final now = DateTime.now();
    return '${now.year}${_padZero(now.month)}${_padZero(now.day)}'
        '${_padZero(now.hour)}${_padZero(now.minute)}${_padZero(now.second)}';
  }

  static String _padZero(int value) => value.toString().padLeft(2, '0');
}
