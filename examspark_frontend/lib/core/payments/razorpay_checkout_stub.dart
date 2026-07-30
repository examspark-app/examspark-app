/// Non-web stub — Razorpay Checkout is Web-only for Session 6.
Future<Map<String, String>> openRazorpayCheckout({
  required String keyId,
  required String gatewayOrderId,
  required int amountPaise,
  String name = 'ExamSpark',
  String? email,
  String? description,
}) async {
  throw UnsupportedError(
    'Razorpay Checkout is only available on Flutter Web in Session 6. '
    'Android uses Google Play Billing (stub).',
  );
}
