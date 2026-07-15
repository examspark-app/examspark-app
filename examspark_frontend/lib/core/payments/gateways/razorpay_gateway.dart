import 'package:examspark_frontend/core/config/app_config.dart';
import 'package:examspark_frontend/core/payments/interfaces/payment_gateway.dart';
import 'package:examspark_frontend/core/payments/models/payment_order.dart';
import 'package:examspark_frontend/core/payments/models/payment_result.dart';
import 'package:examspark_frontend/core/payments/payment_repository.dart';
import 'package:examspark_frontend/core/payments/razorpay_checkout.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Web — Razorpay primary. Orders + verify go through FastAPI.
class RazorpayGateway implements PaymentGatewayInterface {
  @override
  PaymentGateway get gateway => PaymentGateway.razorpay;

  @override
  bool get isConfigured => AppConfig.isApiConfigured;

  @override
  Future<PaymentResult> createOrder({
    required String planId,
    required int amountPaise,
    required String userId,
    required String idempotencyKey,
    String? creditPackId,
  }) async {
    if (!AppConfig.isApiConfigured) {
      return PaymentResult.notConfigured('Razorpay (FASTAPI_BASE_URL)');
    }
    try {
      final data = await PaymentRepository.instance.createOrder(
        idempotencyKey: idempotencyKey,
        platform: PaymentPlatform.web,
        gateway: PaymentGateway.razorpay,
        planId: creditPackId == null ? planId : null,
        creditPackId: creditPackId,
      );
      final status = '${data['status']}'.toLowerCase();
      final orderId = '${data['order_id'] ?? ''}';
      if (status == 'failed' || orderId.isEmpty) {
        return PaymentResult.failed(
          '${data['message'] ?? 'Order create failed'}',
          orderId: orderId.isEmpty ? null : orderId,
        );
      }
      return PaymentResult(
        status: PaymentResultStatus.orderCreated,
        orderId: orderId,
        message: '${data['message'] ?? 'Order created'}',
        gatewayOrderId: data['gateway_order_id'] as String?,
        razorpayKeyId: data['razorpay_key_id'] as String?,
        creditsAllocated: null,
      );
    } catch (e) {
      return PaymentResult.failed(e.toString());
    }
  }

  @override
  Future<PaymentResult> initiateCheckout(PaymentOrder order) async {
    final keyId = order.razorpayKeyId ??
        dotenv.maybeGet('RAZORPAY_KEY_ID') ??
        '';
    final gatewayOrderId = order.gatewayOrderId;
    if (keyId.isEmpty || gatewayOrderId == null || gatewayOrderId.isEmpty) {
      return PaymentResult.failed(
        'Missing Razorpay key or gateway order id',
        orderId: order.orderId,
      );
    }
    try {
      final result = await openRazorpayCheckout(
        keyId: keyId,
        gatewayOrderId: gatewayOrderId,
        amountPaise: order.amountPaise,
        description: order.creditPackId ?? order.planId,
      );
      return PaymentResult(
        status: PaymentResultStatus.pending,
        orderId: order.orderId,
        message: 'Checkout completed — verifying with server',
        gatewayOrderId: result['razorpay_order_id'],
        gatewayPaymentId: result['razorpay_payment_id'],
        gatewaySignature: result['razorpay_signature'],
        razorpayKeyId: keyId,
      );
    } on StateError catch (e) {
      if (e.message.contains('cancelled')) {
        return PaymentResult.cancelled(order.orderId);
      }
      return PaymentResult.failed(e.message, orderId: order.orderId);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('cancelled')) {
        return PaymentResult.cancelled(order.orderId);
      }
      return PaymentResult.failed(msg, orderId: order.orderId);
    }
  }

  @override
  Future<PaymentResult> verifyPayment({
    required PaymentOrder order,
    String? gatewayPaymentId,
    String? gatewaySignature,
    Map<String, dynamic>? gatewayPayload,
  }) async {
    try {
      final data = await PaymentRepository.instance.verifyPayment(
        orderId: order.orderId,
        gateway: PaymentGateway.razorpay,
        idempotencyKey: 'verify_${order.idempotencyKey}',
        gatewayPaymentId: gatewayPaymentId,
        gatewaySignature: gatewaySignature,
        razorpayOrderId: gatewayPayload?['razorpay_order_id'] as String? ??
            order.gatewayOrderId,
      );
      final status = '${data['status']}'.toLowerCase();
      if (status != 'verified') {
        return PaymentResult.failed(
          '${data['message'] ?? 'Verification failed'}',
          orderId: order.orderId,
        );
      }
      final credits = data['credits_allocated'];
      return PaymentResult(
        status: PaymentResultStatus.verified,
        orderId: order.orderId,
        message: '${data['message'] ?? 'Payment verified'}',
        creditsAllocated: credits is int ? credits : int.tryParse('$credits'),
      );
    } catch (e) {
      return PaymentResult.failed(e.toString(), orderId: order.orderId);
    }
  }
}
