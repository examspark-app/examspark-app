import 'package:examspark_frontend/core/payments/interfaces/payment_gateway.dart';
import 'package:examspark_frontend/core/payments/models/payment_order.dart';
import 'package:examspark_frontend/core/payments/models/payment_result.dart';

/// Web — Razorpay primary. TODO: Razorpay Integration
class RazorpayGateway implements PaymentGatewayInterface {
  @override
  PaymentGateway get gateway => PaymentGateway.razorpay;

  @override
  bool get isConfigured {
    // TODO: Razorpay Integration — read from .env RAZORPAY_KEY_ID
    return false;
  }

  @override
  Future<PaymentResult> createOrder({
    required String planId,
    required int amountPaise,
    required String userId,
    required String idempotencyKey,
    String? creditPackId,
  }) async {
    if (!isConfigured) {
      return PaymentResult.notConfigured('Razorpay');
    }
    // TODO: Razorpay Integration
    // Razorpay().createOrder(amount: amountPaise, currency: 'INR', ...)
    return PaymentResult.pending('pending_razorpay');
  }

  @override
  Future<PaymentResult> initiateCheckout(PaymentOrder order) async {
    // TODO: Razorpay Integration
    // Razorpay.open({ key, order_id, ... })
    return PaymentResult.notConfigured('Razorpay checkout');
  }

  @override
  Future<PaymentResult> verifyPayment({
    required PaymentOrder order,
    String? gatewayPaymentId,
    String? gatewaySignature,
    Map<String, dynamic>? gatewayPayload,
  }) async {
    // TODO: Razorpay Integration — server-side verify via FastAPI
    return PaymentResult(
      status: PaymentResultStatus.pending,
      orderId: order.orderId,
      message: 'TODO: Razorpay signature verification',
    );
  }
}
