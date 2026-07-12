import 'package:examspark_frontend/core/payments/models/payment_order.dart';
import 'package:examspark_frontend/core/payments/models/payment_result.dart';

/// Abstract payment gateway — plug Razorpay / PhonePe / Google Play later.
abstract class PaymentGatewayInterface {
  PaymentGateway get gateway;
  bool get isConfigured;

  Future<PaymentResult> createOrder({
    required String planId,
    required int amountPaise,
    required String userId,
    required String idempotencyKey,
    String? creditPackId,
  });

  Future<PaymentResult> initiateCheckout(PaymentOrder order);

  Future<PaymentResult> verifyPayment({
    required PaymentOrder order,
    String? gatewayPaymentId,
    String? gatewaySignature,
    Map<String, dynamic>? gatewayPayload,
  });
}
