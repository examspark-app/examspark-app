enum PaymentPlatform { web, android }

enum PaymentGateway { razorpay, phonepe, googlePlay }

enum PaymentFlowStep {
  choosePlan,
  createOrder,
  pendingPayment,
  verifyPayment,
  activateSubscription,
  allocateCredits,
  storeTransaction,
}

class PaymentOrder {
  final String orderId;
  final String planId;
  final int amountPaise;
  final String currency;
  final PaymentGateway gateway;
  final PaymentPlatform platform;
  final String idempotencyKey;
  final String? gatewayOrderId;
  final String? razorpayKeyId;
  final String? googlePlayProductId;
  final String? creditPackId;

  const PaymentOrder({
    required this.orderId,
    required this.planId,
    required this.amountPaise,
    this.currency = 'INR',
    required this.gateway,
    required this.platform,
    required this.idempotencyKey,
    this.gatewayOrderId,
    this.razorpayKeyId,
    this.googlePlayProductId,
    this.creditPackId,
  });
}
