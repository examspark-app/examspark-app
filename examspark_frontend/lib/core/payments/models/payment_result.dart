/// Payment result — never fake success.
enum PaymentResultStatus {
  notConfigured,
  orderCreated,
  pending,
  verified,
  failed,
  cancelled,
}

class PaymentResult {
  final PaymentResultStatus status;
  final String? orderId;
  final String message;
  final int? creditsAllocated;

  const PaymentResult({
    required this.status,
    this.orderId,
    required this.message,
    this.creditsAllocated,
  });

  bool get isSuccess => status == PaymentResultStatus.verified;

  factory PaymentResult.notConfigured(String feature) => PaymentResult(
        status: PaymentResultStatus.notConfigured,
        message: '$feature not configured — TODO: add API keys',
      );

  factory PaymentResult.pending(String orderId) => PaymentResult(
        status: PaymentResultStatus.pending,
        orderId: orderId,
        message: 'Payment pending verification',
      );
}
