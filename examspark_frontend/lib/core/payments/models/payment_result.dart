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
  final String? gatewayOrderId;
  final String? gatewayPaymentId;
  final String? gatewaySignature;
  final String? razorpayKeyId;

  const PaymentResult({
    required this.status,
    this.orderId,
    required this.message,
    this.creditsAllocated,
    this.gatewayOrderId,
    this.gatewayPaymentId,
    this.gatewaySignature,
    this.razorpayKeyId,
  });

  bool get isSuccess => status == PaymentResultStatus.verified;

  factory PaymentResult.notConfigured(String feature) => PaymentResult(
        status: PaymentResultStatus.notConfigured,
        message: '$feature not configured — add keys / FASTAPI_BASE_URL',
      );

  factory PaymentResult.pending(String orderId) => PaymentResult(
        status: PaymentResultStatus.pending,
        orderId: orderId,
        message: 'Payment pending verification',
      );

  factory PaymentResult.cancelled([String? orderId]) => PaymentResult(
        status: PaymentResultStatus.cancelled,
        orderId: orderId,
        message: 'Payment cancelled',
      );

  factory PaymentResult.failed(String message, {String? orderId}) =>
      PaymentResult(
        status: PaymentResultStatus.failed,
        orderId: orderId,
        message: message,
      );
}
