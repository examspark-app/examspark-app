import 'dart:convert';
import 'dart:js_interop';

@JS('openExamSparkRazorpay')
external JSPromise<JSString> _openExamSparkRazorpay(JSString optionsJson);

/// Opens Razorpay Checkout.js (see web/index.html bridge).
Future<Map<String, String>> openRazorpayCheckout({
  required String keyId,
  required String gatewayOrderId,
  required int amountPaise,
  String name = 'ExamSpark',
  String? email,
  String? description,
}) async {
  final options = <String, dynamic>{
    'key': keyId,
    'amount': amountPaise,
    'currency': 'INR',
    'name': name,
    'description': description ?? 'ExamSpark subscription / credits',
    'order_id': gatewayOrderId,
    'theme': {'color': '#111111'},
  };
  if (email != null && email.isNotEmpty) {
    options['prefill'] = {'email': email};
  }

  try {
    final jsResult = await _openExamSparkRazorpay(
      jsonEncode(options).toJS,
    ).toDart;
    final map = jsonDecode(jsResult.toDart) as Map<String, dynamic>;
    return {
      'razorpay_payment_id': '${map['razorpay_payment_id'] ?? ''}',
      'razorpay_order_id': '${map['razorpay_order_id'] ?? gatewayOrderId}',
      'razorpay_signature': '${map['razorpay_signature'] ?? ''}',
    };
  } catch (e) {
    final msg = e.toString();
    if (msg.contains('cancelled') || msg.contains('Payment cancelled')) {
      throw StateError('Payment cancelled');
    }
    rethrow;
  }
}
