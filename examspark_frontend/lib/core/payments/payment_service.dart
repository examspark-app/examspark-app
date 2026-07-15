import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:examspark_frontend/core/config/app_config.dart';
import 'package:examspark_frontend/core/payments/gateways/google_play_billing_gateway.dart';
import 'package:examspark_frontend/core/payments/gateways/phonepe_gateway.dart';
import 'package:examspark_frontend/core/payments/gateways/razorpay_gateway.dart';
import 'package:examspark_frontend/core/payments/interfaces/payment_gateway.dart';
import 'package:examspark_frontend/core/payments/models/payment_order.dart';
import 'package:examspark_frontend/core/payments/models/payment_result.dart';
import 'package:examspark_frontend/core/payments/play_products.dart';
import 'package:examspark_frontend/core/payments/subscription_plans.dart';

/// Payment orchestrator — no fake success.
///
/// Web: Razorpay Checkout → FastAPI verify.
/// Android: Google Play Billing → FastAPI verify (never Razorpay for Play subs).
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

    if (!AppConfig.isApiConfigured) {
      return PaymentResult.notConfigured('FASTAPI_BASE_URL');
    }

    if (kIsWeb) {
      return _purchaseViaRazorpay(
        planId: plan.id,
        amountPaise: plan.priceInrPaise,
        userId: userId,
      );
    }

    return _purchaseViaGooglePlay(
      planId: plan.id,
      amountPaise: plan.priceInrPaise,
      userId: userId,
      playProductId: PlayProducts.productForPlan(plan.id),
    );
  }

  Future<PaymentResult> purchaseCreditPack({
    required String userId,
    required CreditPackDef pack,
  }) async {
    if (!AppConfig.isApiConfigured) {
      return PaymentResult.notConfigured('FASTAPI_BASE_URL');
    }

    if (kIsWeb) {
      return _purchaseViaRazorpay(
        planId: 'free',
        amountPaise: pack.priceInrPaise,
        userId: userId,
        creditPackId: pack.id,
      );
    }

    return _purchaseViaGooglePlay(
      planId: 'free',
      amountPaise: pack.priceInrPaise,
      userId: userId,
      creditPackId: pack.id,
      playProductId: PlayProducts.productForPack(pack.id),
    );
  }

  Future<PaymentResult> _purchaseViaRazorpay({
    required String planId,
    required int amountPaise,
    required String userId,
    String? creditPackId,
  }) async {
    final idempotencyKey = generateIdempotencyKey();
    final gateway = _razorpay;

    final orderResult = await gateway.createOrder(
      planId: planId,
      amountPaise: amountPaise,
      userId: userId,
      idempotencyKey: idempotencyKey,
      creditPackId: creditPackId,
    );

    if (orderResult.status != PaymentResultStatus.orderCreated &&
        orderResult.status != PaymentResultStatus.pending) {
      return orderResult;
    }

    final order = PaymentOrder(
      orderId: orderResult.orderId ?? '',
      planId: planId,
      amountPaise: amountPaise,
      gateway: PaymentGateway.razorpay,
      platform: PaymentPlatform.web,
      idempotencyKey: idempotencyKey,
      gatewayOrderId: orderResult.gatewayOrderId,
      razorpayKeyId: orderResult.razorpayKeyId,
      creditPackId: creditPackId,
    );

    final checkout = await gateway.initiateCheckout(order);
    if (checkout.status == PaymentResultStatus.cancelled) {
      return checkout;
    }
    if (checkout.status != PaymentResultStatus.pending) {
      return checkout;
    }

    return gateway.verifyPayment(
      order: order,
      gatewayPaymentId: checkout.gatewayPaymentId,
      gatewaySignature: checkout.gatewaySignature,
      gatewayPayload: {
        'razorpay_order_id': checkout.gatewayOrderId ?? order.gatewayOrderId,
      },
    );
  }

  Future<PaymentResult> _purchaseViaGooglePlay({
    required String planId,
    required int amountPaise,
    required String userId,
    String? creditPackId,
    String? playProductId,
  }) async {
    if (playProductId == null || playProductId.isEmpty) {
      return PaymentResult.failed('No Play product mapped for this item');
    }

    final idempotencyKey = generateIdempotencyKey();
    final gateway = _googlePlay;

    final orderResult = await gateway.createOrder(
      planId: planId,
      amountPaise: amountPaise,
      userId: userId,
      idempotencyKey: idempotencyKey,
      creditPackId: creditPackId,
    );

    if (orderResult.status != PaymentResultStatus.orderCreated &&
        orderResult.status != PaymentResultStatus.pending) {
      return orderResult;
    }

    final productId = orderResult.gatewayOrderId ?? playProductId;
    final order = PaymentOrder(
      orderId: orderResult.orderId ?? '',
      planId: planId,
      amountPaise: amountPaise,
      gateway: PaymentGateway.googlePlay,
      platform: PaymentPlatform.android,
      idempotencyKey: idempotencyKey,
      gatewayOrderId: productId,
      googlePlayProductId: productId,
      creditPackId: creditPackId,
    );

    final checkout = await gateway.initiateCheckout(order);
    if (checkout.status == PaymentResultStatus.cancelled) {
      return checkout;
    }
    if (checkout.status != PaymentResultStatus.pending) {
      return checkout;
    }

    return gateway.verifyPayment(
      order: order,
      gatewayPaymentId: checkout.gatewayPaymentId,
      gatewayPayload: {
        'purchase_token': checkout.gatewayPaymentId,
        'product_id': productId,
      },
    );
  }

  Future<PaymentResult> verifyAndActivate({
    required String userId,
    required PaymentOrder order,
    String? gatewayPaymentId,
    String? gatewaySignature,
    Map<String, dynamic>? gatewayPayload,
  }) async {
    return _activeGateway.verifyPayment(
      order: order,
      gatewayPaymentId: gatewayPaymentId,
      gatewaySignature: gatewaySignature,
      gatewayPayload: gatewayPayload,
    );
  }
}
