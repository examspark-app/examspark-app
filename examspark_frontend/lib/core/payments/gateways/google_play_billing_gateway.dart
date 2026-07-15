import 'dart:async';

import 'package:examspark_frontend/core/config/app_config.dart';
import 'package:examspark_frontend/core/payments/interfaces/payment_gateway.dart';
import 'package:examspark_frontend/core/payments/models/payment_order.dart';
import 'package:examspark_frontend/core/payments/models/payment_result.dart';
import 'package:examspark_frontend/core/payments/payment_repository.dart';
import 'package:examspark_frontend/core/payments/play_products.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Android — Google Play Billing (subscriptions + one-time packs).
/// Web must not use this gateway (Play policy).
class GooglePlayBillingGateway implements PaymentGatewayInterface {
  final InAppPurchase _iap = InAppPurchase.instance;

  @override
  PaymentGateway get gateway => PaymentGateway.googlePlay;

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
      return PaymentResult.notConfigured('Google Play (FASTAPI_BASE_URL)');
    }
    try {
      final data = await PaymentRepository.instance.createOrder(
        idempotencyKey: idempotencyKey,
        platform: PaymentPlatform.android,
        gateway: PaymentGateway.googlePlay,
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
      final productId = data['google_play_product_id'] as String? ??
          data['gateway_order_id'] as String?;
      return PaymentResult(
        status: PaymentResultStatus.orderCreated,
        orderId: orderId,
        message: '${data['message'] ?? 'Play purchase intent created'}',
        gatewayOrderId: productId,
        razorpayKeyId: null,
      );
    } catch (e) {
      return PaymentResult.failed(e.toString());
    }
  }

  @override
  Future<PaymentResult> initiateCheckout(PaymentOrder order) async {
    final productId = order.googlePlayProductId ?? order.gatewayOrderId;
    if (productId == null || productId.isEmpty) {
      return PaymentResult.failed(
        'Missing Google Play product id',
        orderId: order.orderId,
      );
    }

    final available = await _iap.isAvailable();
    if (!available) {
      return PaymentResult.notConfigured(
        'Google Play Billing (store unavailable on this device)',
      );
    }

    final response = await _iap.queryProductDetails({productId});
    if (response.error != null) {
      return PaymentResult.failed(
        'Product query failed: ${response.error!.message}',
        orderId: order.orderId,
      );
    }
    if (response.productDetails.isEmpty) {
      return PaymentResult.failed(
        'Product not found in Play Console: $productId '
        '(create product + Internal testing AAB first)',
        orderId: order.orderId,
      );
    }

    final productDetails = response.productDetails.first;
    final purchaseParam = PurchaseParam(productDetails: productDetails);

    final completer = Completer<PaymentResult>();
    late StreamSubscription<List<PurchaseDetails>> sub;
    sub = _iap.purchaseStream.listen(
      (purchases) async {
        for (final purchase in purchases) {
          if (purchase.productID != productId) continue;
          if (purchase.status == PurchaseStatus.pending) continue;
          if (purchase.status == PurchaseStatus.canceled) {
            if (!completer.isCompleted) {
              completer.complete(PaymentResult.cancelled(order.orderId));
            }
            await sub.cancel();
            return;
          }
          if (purchase.status == PurchaseStatus.error) {
            if (!completer.isCompleted) {
              completer.complete(
                PaymentResult.failed(
                  purchase.error?.message ?? 'Play purchase error',
                  orderId: order.orderId,
                ),
              );
            }
            await sub.cancel();
            return;
          }
          if (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored) {
            final token = purchase.verificationData.serverVerificationData;
            if (!completer.isCompleted) {
              completer.complete(
                PaymentResult(
                  status: PaymentResultStatus.pending,
                  orderId: order.orderId,
                  message: 'Purchase received — verifying with server',
                  gatewayOrderId: productId,
                  gatewayPaymentId: token,
                ),
              );
            }
            if (purchase.pendingCompletePurchase) {
              await _iap.completePurchase(purchase);
            }
            await sub.cancel();
            return;
          }
        }
      },
      onError: (Object e) {
        if (!completer.isCompleted) {
          completer.complete(
            PaymentResult.failed(e.toString(), orderId: order.orderId),
          );
        }
      },
    );

    final launched = PlayProducts.isSubscriptionProduct(productId)
        ? await _iap.buyNonConsumable(purchaseParam: purchaseParam)
        : await _iap.buyConsumable(purchaseParam: purchaseParam);

    if (!launched && !completer.isCompleted) {
      await sub.cancel();
      return PaymentResult.failed(
        'Could not launch Play Billing UI',
        orderId: order.orderId,
      );
    }

    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        sub.cancel();
        return PaymentResult.failed(
          'Play purchase timed out',
          orderId: order.orderId,
        );
      },
    );
  }

  @override
  Future<PaymentResult> verifyPayment({
    required PaymentOrder order,
    String? gatewayPaymentId,
    String? gatewaySignature,
    Map<String, dynamic>? gatewayPayload,
  }) async {
    final productId = order.googlePlayProductId ??
        order.gatewayOrderId ??
        gatewayPayload?['product_id'] as String?;
    final token = gatewayPaymentId ??
        gatewayPayload?['purchase_token'] as String?;
    if (productId == null || token == null || token.isEmpty) {
      return PaymentResult.failed(
        'Missing purchase token or product id',
        orderId: order.orderId,
      );
    }
    try {
      final data = await PaymentRepository.instance.verifyPayment(
        orderId: order.orderId,
        gateway: PaymentGateway.googlePlay,
        idempotencyKey: 'verify_${order.idempotencyKey}',
        gatewayPaymentId: token,
        gatewayPayload: {
          'purchase_token': token,
          'product_id': productId,
        },
      );
      final status = '${data['status']}'.toLowerCase();
      if (status != 'verified') {
        return PaymentResult.failed(
          '${data['message'] ?? 'Play verification failed'}',
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
