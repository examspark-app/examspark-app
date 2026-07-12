import 'package:examspark_frontend/core/payments/interfaces/payment_gateway.dart';
import 'package:examspark_frontend/core/payments/models/payment_order.dart';
import 'package:examspark_frontend/core/payments/models/payment_result.dart';

/// Android — Google Play Billing only (no Razorpay subscriptions on Android).
/// TODO: Google Play Billing
/// Add dependency: in_app_purchase or billing_client wrapper when implementing.
class GooglePlayBillingGateway implements PaymentGatewayInterface {
  @override
  PaymentGateway get gateway => PaymentGateway.googlePlay;

  @override
  bool get isConfigured => false;

  @override
  Future<PaymentResult> createOrder({
    required String planId,
    required int amountPaise,
    required String userId,
    required String idempotencyKey,
    String? creditPackId,
  }) async {
    // TODO: Google Play Billing — queryProductDetails, no server order for subs
    return PaymentResult.notConfigured('Google Play Billing');
  }

  @override
  Future<PaymentResult> initiateCheckout(PaymentOrder order) async {
    // TODO: Google Play Billing
    // BillingClient.launchBillingFlow() for subscription SKU
    return PaymentResult.notConfigured('Google Play purchase flow');
  }

  @override
  Future<PaymentResult> verifyPayment({
    required PaymentOrder order,
    String? gatewayPaymentId,
    String? gatewaySignature,
    Map<String, dynamic>? gatewayPayload,
  }) async {
    // TODO: Google Play Billing — send purchaseToken to FastAPI /verify
    return PaymentResult(
      status: PaymentResultStatus.pending,
      orderId: order.orderId,
      message: 'TODO: Server-side Play purchase verification',
    );
  }
}
