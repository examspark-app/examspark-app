import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:examspark_frontend/core/config/app_config.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/payments/models/payment_order.dart';

/// FastAPI payment client — create order / verify / status.
class PaymentRepository {
  PaymentRepository._();

  static final PaymentRepository instance = PaymentRepository._();

  Future<String> _accessToken() async {
    var session = SupabaseClient.instance.currentSession;
    if (session != null && session.isExpired) {
      try {
        final refreshed =
            await SupabaseClient.instance.client.auth.refreshSession();
        session = refreshed.session;
      } catch (_) {}
    }
    final token = session?.accessToken;
    if (token == null) {
      throw StateError('No active session — please log in again');
    }
    return token;
  }

  Uri _uri(String path) {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }
    final base = AppConfig.resolvedApiBaseUrl.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$base$path');
  }

  Future<Map<String, dynamic>> createOrder({
    required String idempotencyKey,
    required PaymentPlatform platform,
    required PaymentGateway gateway,
    String? planId,
    String? creditPackId,
  }) async {
    final token = await _accessToken();
    final body = <String, dynamic>{
      'platform': platform.name,
      'gateway': _gatewayApiName(gateway),
      'idempotency_key': idempotencyKey,
    };
    if (planId != null && planId.isNotEmpty && planId != 'free') {
      body['plan_id'] = planId;
    }
    if (creditPackId != null && creditPackId.isNotEmpty) {
      body['credit_pack_id'] = creditPackId;
    }

    final response = await http.post(
      _uri('/api/v1/payments/orders'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw Exception(_errorMessage(data, response.statusCode));
    }
    return data;
  }

  Future<Map<String, dynamic>> verifyPayment({
    required String orderId,
    required PaymentGateway gateway,
    required String idempotencyKey,
    String? gatewayPaymentId,
    String? gatewaySignature,
    String? razorpayOrderId,
    Map<String, dynamic>? gatewayPayload,
  }) async {
    final token = await _accessToken();
    final payload = <String, dynamic>{...?gatewayPayload};
    if (razorpayOrderId != null) {
      payload['razorpay_order_id'] = razorpayOrderId;
    }

    final response = await http.post(
      _uri('/api/v1/payments/verify'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'order_id': orderId,
        'gateway': _gatewayApiName(gateway),
        'gateway_payment_id': gatewayPaymentId,
        'gateway_signature': gatewaySignature,
        'gateway_payload': payload,
        'idempotency_key': idempotencyKey,
      }),
    );
    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw Exception(_errorMessage(data, response.statusCode));
    }
    return data;
  }

  String _gatewayApiName(PaymentGateway g) {
    switch (g) {
      case PaymentGateway.razorpay:
        return 'razorpay';
      case PaymentGateway.phonepe:
        return 'phonepe';
      case PaymentGateway.googlePlay:
        return 'google_play';
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return {};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {'raw': decoded};
  }

  String _errorMessage(Map<String, dynamic> data, int status) {
    final detail = data['detail'] ?? data['message'];
    if (detail is String) return detail;
    return 'Payment API error ($status)';
  }
}
