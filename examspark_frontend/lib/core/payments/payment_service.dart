import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:examspark_frontend/core/payments/gateways/google_play_billing_gateway.dart';
import 'package:examspark_frontend/core/payments/gateways/phonepe_gateway.dart';
import 'package:examspark_frontend/core/payments/gateways/razorpay_gateway.dart';
import 'package:examspark_frontend/core/payments/interfaces/payment_gateway.dart';
import 'package:examspark_frontend/core/payments/models/payment_order.dart';
import 'package:examspark_frontend/core/payments/models/payment_result.dart';
import 'package:examspark_frontend/core/payments/subscription_plans.dart';

/// Payment orchestrator — no fake success, no hardcoded payment completion.
///
/// Flow:
/// User → Choose Plan → Create Order → Pending → Verify → Activate → Credits → Transaction
class PaymentService {
  PaymentService._();

  static final PaymentService instance = PaymentService._();

  final RazorpayGateway _razorpay = RazorpayGateway();
  final PhonePeGateway _phonepe = PhonePeGateway();
  final GooglePlayBillingGateway _googlePlay = GooglePlayBillingGateway();

  PaymentGatewayInterface get _activeGateway {
    if (kIsWeb) {
      if (_razorpay.isConfigured) return _razorpay;
      if (_phonepe.isConfigured) return _phonepe;
      return _razorpay;
    }
    return _googlePlay;
  }

  PaymentPlatform get platform =>
      kIsWeb ? PaymentPlatform.web : PaymentPlatform.android;

  bool get isConfigured => _activeGateway.isConfigured;

  String generateIdempotencyKey() =>
      'idem_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';

  /// Full checkout flow — stops at pending if gateway not configured.
  Future<PaymentResult> purchasePlan({
    required String userId,
    required SubscriptionPlanDef plan,
  }) async {
    if (plan.priceInrPaise == 0) {
      return const PaymentResult(
        status: PaymentResultStatus.verified,
        message: 'Free plan — no payment required',
        creditsAllocated: 50,
      );
    }

    final idempotencyKey = generateIdempotencyKey();
    final gateway = _activeGateway;

    if (!gateway.isConfigured) {
      return PaymentResult.notConfigured(_gatewayLabel(gateway));
    }

    final orderResult = await gateway.createOrder(
      planId: plan.id,
      amountPaise: plan.priceInrPaise,
      userId: userId,
      idempotencyKey: idempotencyKey,
    );

    if (orderResult.status != PaymentResultStatus.pending &&
        orderResult.status != PaymentResultStatus.orderCreated) {
      return orderResult;
    }

    // TODO: PaymentRepository.createOrder when FastAPI is reachable
    final order = PaymentOrder(
      orderId: orderResult.orderId ?? 'pending',
      planId: plan.id,
      amountPaise: plan.priceInrPaise,
      gateway: gateway.gateway,
      platform: platform,
      idempotencyKey: idempotencyKey,
    );

    final checkout = await gateway.initiateCheckout(order);
    if (checkout.status != PaymentResultStatus.pending) {
      return checkout;
    }

    return PaymentResult.pending(order.orderId);
  }

  Future<PaymentResult> purchaseCreditPack({
    required String userId,
    required CreditPackDef pack,
  }) async {
    final gateway = _activeGateway;
    if (!gateway.isConfigured) {
      return PaymentResult.notConfigured(_gatewayLabel(gateway));
    }
    // TODO: Credit pack checkout — same flow as plan
    return PaymentResult.notConfigured('Credit pack purchase');
  }

  Future<PaymentResult> verifyAndActivate({
    required String userId,
    required PaymentOrder order,
    String? gatewayPaymentId,
    String? gatewaySignature,
    Map<String, dynamic>? gatewayPayload,
  }) async {
    final gateway = _activeGateway;
    final localVerify = await gateway.verifyPayment(
      order: order,
      gatewayPaymentId: gatewayPaymentId,
      gatewaySignature: gatewaySignature,
      gatewayPayload: gatewayPayload,
    );

    if (localVerify.status != PaymentResultStatus.verified) {
      // TODO: PaymentRepository.verifyPayment → FastAPI
      return PaymentResult(
        status: PaymentResultStatus.pending,
        orderId: order.orderId,
        message: 'Awaiting server verification — TODO: FastAPI',
      );
    }

    return localVerify;
  }

  String _gatewayLabel(PaymentGatewayInterface g) {
    switch (g.gateway) {
      case PaymentGateway.razorpay:
        return 'Razorpay';
      case PaymentGateway.phonepe:
        return 'PhonePe';
      case PaymentGateway.googlePlay:
        return 'Google Play Billing';
    }
  }
}
