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

  const PaymentOrder({
    required this.orderId,
    required this.planId,
    required this.amountPaise,
    this.currency = 'INR',
    required this.gateway,
    required this.platform,
    required this.idempotencyKey,
  });
}
