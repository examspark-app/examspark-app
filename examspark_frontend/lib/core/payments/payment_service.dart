import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show debugPrint;
import 'package:in_app_purchase/in_app_purchase.dart'; // Naya import
import 'package:shared_preferences/shared_preferences.dart';

import 'package:examspark_frontend/core/config/app_config.dart';
import 'package:examspark_frontend/core/payments/gateways/google_play_billing_gateway.dart';
import 'package:examspark_frontend/core/payments/gateways/phonepe_gateway.dart';
import 'package:examspark_frontend/core/payments/gateways/razorpay_gateway.dart';
import 'package:examspark_frontend/core/payments/interfaces/payment_gateway.dart';
import 'package:examspark_frontend/core/payments/models/payment_order.dart';
import 'package:examspark_frontend/core/payments/models/payment_result.dart';
import 'package:examspark_frontend/core/payments/payment_repository.dart';
import 'package:examspark_frontend/core/payments/play_products.dart';
import 'package:examspark_frontend/core/payments/subscription_plans.dart';

/// Payment orchestrator — no fake success (except explicit IS_TESTING mock).
///
/// Web: Razorpay Checkout → FastAPI verify.
/// Android: Google Play Billing → FastAPI verify (never Razorpay for Play subs).
/// Dev: when [AppConfig.isTesting], skips gateways → FastAPI mock +50 credits.
class PaymentService {
  PaymentService._();

  static final PaymentService instance = PaymentService._();

  final RazorpayGateway _razorpay = RazorpayGateway();
  final PhonePeGateway _phonepe = PhonePeGateway();
  final GooglePlayBillingGateway _googlePlay = GooglePlayBillingGateway();

  // Background listener variable
  StreamSubscription<List<PurchaseDetails>>? _iapStreamSubscription;
  bool _initialized = false;
  static const _pendingOrderPrefix = 'play_pending_order_';

  // App start hone par background purchases sunne ke liye
  void initialize() {
    if (!kIsWeb && !_initialized) {
      _initialized = true;
      final Stream<List<PurchaseDetails>> purchaseUpdated =
          InAppPurchase.instance.purchaseStream;
      
      _iapStreamSubscription = purchaseUpdated.listen((purchases) {
        _handleBackgroundPurchases(purchases);
      }, onDone: () {
        _iapStreamSubscription?.cancel();
      }, onError: (Object error) {
        debugPrint('Global IAP Error: $error');
      });
    }
  }

  // Pending/Background purchases ko verify karne ke liye
  Future<void> _handleBackgroundPurchases(List<PurchaseDetails> purchases) async {
    for (var purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased || 
          purchase.status == PurchaseStatus.restored) {
        
          if (purchase.pendingCompletePurchase) {
          final token = purchase.verificationData.serverVerificationData;
          final productId = purchase.productID;
            final prefs = await SharedPreferences.getInstance();
            final orderId = prefs.getString('$_pendingOrderPrefix$token');
            if (orderId == null || orderId.isEmpty) {
              debugPrint('Pending Play purchase has no local order mapping');
              continue;
            }
          
          try {
            final data = await PaymentRepository.instance.verifyPayment(
              orderId: orderId,
              gateway: PaymentGateway.googlePlay,
              idempotencyKey: 'recovery_$token',
              gatewayPaymentId: token,
              gatewayPayload: {
                'purchase_token': token,
                'product_id': productId,
                'is_subscription': PlayProducts.isSubscriptionProduct(productId),
              },
            );

            final status = '${data['status']}'.toLowerCase();
            if (status == 'verified') {
              await InAppPurchase.instance.completePurchase(purchase);
              await prefs.remove('$_pendingOrderPrefix$token');
            }
          } catch (e) {
            debugPrint('Background verification failed: $e');
          }
        }
      }
    }
  }

  void dispose() {
    _iapStreamSubscription?.cancel();
    _iapStreamSubscription = null;
    _initialized = false;
  }

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

    if (AppConfig.isTesting) {
      return _mockDevPurchase(
        kind: 'subscription',
        planId: plan.id,
      );
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

    if (AppConfig.isTesting) {
      return _mockDevPurchase(
        kind: 'credit_pack',
        creditPackId: pack.id,
      );
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

  Future<PaymentResult> _mockDevPurchase({
    required String kind,
    String? planId,
    String? creditPackId,
  }) async {
    try {
      final data = await PaymentRepository.instance.mockDevPurchase(
        kind: kind,
        planId: planId,
        creditPackId: creditPackId,
      );
      final credits = data['credits_allocated'];
      return PaymentResult(
        status: PaymentResultStatus.verified,
        message: (data['message'] as String?) ??
            'Dev mock purchase — credits added',
        creditsAllocated: credits is int ? credits : 50,
      );
    } catch (e) {
      return PaymentResult.failed(e.toString());
    }
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

    final token = checkout.gatewayPaymentId;
    if (token != null && token.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_pendingOrderPrefix$token', order.orderId);
    }

    final result = await gateway.verifyPayment(
      order: order,
      gatewayPaymentId: checkout.gatewayPaymentId,
      gatewayPayload: {
        'purchase_token': checkout.gatewayPaymentId,
        'product_id': productId,
      },
    );
    if (result.status == PaymentResultStatus.verified &&
        token != null &&
        token.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_pendingOrderPrefix$token');
    }
    return result;
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