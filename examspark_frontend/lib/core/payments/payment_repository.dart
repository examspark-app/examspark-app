// FastAPI payment API client — TODO: wire when backend URL configured.
import 'package:examspark_frontend/core/config/app_config.dart';

class PaymentRepository {
  PaymentRepository._();
  static final PaymentRepository instance = PaymentRepository._();

  bool get isConfigured => AppConfig.isApiConfigured;

  Future<Map<String, dynamic>> createOrder({
    required String userId,
    required String planId,
    required String platform,
    required String gateway,
    required String idempotencyKey,
    String? creditPackId,
  }) async {
    // TODO: POST ${AppConfig.apiBaseUrl}/api/v1/payments/orders
    if (!isConfigured) {
      throw PaymentRepositoryException('API base URL not configured');
    }
    throw PaymentRepositoryException('TODO: HTTP client for createOrder');
  }

  Future<Map<String, dynamic>> verifyPayment({
    required String orderId,
    required String userId,
    required String gateway,
    required String idempotencyKey,
    String? gatewayPaymentId,
    String? gatewaySignature,
    Map<String, dynamic>? gatewayPayload,
  }) async {
    // TODO: POST ${AppConfig.apiBaseUrl}/api/v1/payments/verify
    if (!isConfigured) {
      throw PaymentRepositoryException('API base URL not configured');
    }
    throw PaymentRepositoryException('TODO: HTTP client for verifyPayment');
  }
}

class PaymentRepositoryException implements Exception {
  final String message;
  PaymentRepositoryException(this.message);
}
