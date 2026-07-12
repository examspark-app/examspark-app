import 'package:examspark_frontend/core/payments/interfaces/payment_gateway.dart';
import 'package:examspark_frontend/core/payments/models/payment_order.dart';
import 'package:examspark_frontend/core/payments/models/payment_result.dart';

/// Web — optional future. TODO: PhonePe Integration
class PhonePeGateway implements PaymentGatewayInterface {
  @override
  PaymentGateway get gateway => PaymentGateway.phonepe;

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
    return PaymentResult.notConfigured('PhonePe');
  }

  @override
  Future<PaymentResult> initiateCheckout(PaymentOrder order) async {
    // TODO: PhonePe Integration
    return PaymentResult.notConfigured('PhonePe checkout');
  }

  @override
  Future<PaymentResult> verifyPayment({
    required PaymentOrder order,
    String? gatewayPaymentId,
    String? gatewaySignature,
    Map<String, dynamic>? gatewayPayload,
  }) async {
    // TODO: PhonePe Integration
    return PaymentResult(
      status: PaymentResultStatus.pending,
      orderId: order.orderId,
      message: 'TODO: PhonePe verification',
    );
  }
}
