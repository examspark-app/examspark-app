import 'dart:async';

import 'package:examspark_frontend/core/config/app_config.dart';
import 'package:examspark_frontend/core/payments/interfaces/payment_gateway.dart';
import 'package:examspark_frontend/core/payments/models/payment_order.dart';
import 'package:examspark_frontend/core/payments/models/payment_result.dart';
import 'package:examspark_frontend/core/payments/payment_repository.dart';
import 'package:url_launcher/url_launcher.dart';

/// Web — PhonePe Standard Checkout. Opens PhonePe's hosted pay page in the
/// browser (redirect flow); after the user completes payment there, they
/// land back on PHONEPE_REDIRECT_URL and the app calls verifyPayment(),
/// which asks the backend to check the real status with PhonePe.
class PhonePeGateway implements PaymentGatewayInterface {
  @override
  PaymentGateway get gateway => PaymentGateway.phonepe;

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
      return PaymentResult.notConfigured('PhonePe (FASTAPI_BASE_URL)');
    }
    try {
      final data = await PaymentRepository.instance.createOrder(
        idempotencyKey: idempotencyKey,
        platform: PaymentPlatform.web,
        gateway: PaymentGateway.phonepe,
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
      // Backend puts the PhonePe redirect/checkout URL in gateway_order_id.
      return PaymentResult(
        status: PaymentResultStatus.orderCreated,
        orderId: orderId,
        message: '${data['message'] ?? 'Order created'}',
        gatewayOrderId: data['gateway_order_id'] as String?,
        razorpayKeyId: null,
      );
    } catch (e) {
      return PaymentResult.failed(e.toString());
    }
  }

  @override
  Future<PaymentResult> initiateCheckout(PaymentOrder order) async {
    final checkoutUrl = order.gatewayOrderId;
    if (checkoutUrl == null || checkoutUrl.isEmpty) {
      return PaymentResult.failed(
        'Missing PhonePe checkout URL',
        orderId: order.orderId,
      );
    }
    final uri = Uri.tryParse(checkoutUrl);
    if (uri == null) {
      return PaymentResult.failed(
        'Invalid PhonePe checkout URL',
        orderId: order.orderId,
      );
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      return PaymentResult.failed(
        'Could not open PhonePe checkout',
        orderId: order.orderId,
      );
    }
    // PhonePe is a redirect flow — we can't capture completion in-page like
    // Razorpay's popup. The caller should call verifyPayment() once the
    // user returns to the app (e.g. on app resume / redirect landing page).
    return PaymentResult(
      status: PaymentResultStatus.pending,
      orderId: order.orderId,
      message: 'Complete payment in the browser, then return to the app',
    );
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
        gateway: PaymentGateway.phonepe,
        idempotencyKey: 'verify_${order.idempotencyKey}',
        gatewayPaymentId: gatewayPaymentId,
        gatewaySignature: gatewaySignature,
        razorpayOrderId: null,
      );
      final status = '${data['status']}'.toLowerCase();
      if (status != 'verified') {
        return PaymentResult.failed(
          '${data['message'] ?? 'PhonePe verification failed'}',
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