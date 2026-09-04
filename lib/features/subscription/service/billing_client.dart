// Talks to the Agent Gateway's billing routes. The gateway holds the Razorpay
// SECRET key, computes the amount, creates the order, and is the ONLY writer of
// the subscription plan (via the signature-verified webhook).
//
// Requires AgentGatewayConfig.baseUrl to be set (same gateway as the AI chat).

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../ai_chat/service/agent_gateway_client.dart' show AgentGatewayConfig;

class BillingOrder {
  final String orderId;
  final int amountPaise;
  final String currency;
  final String keyId; // Razorpay publishable key — safe on the client

  const BillingOrder({
    required this.orderId,
    required this.amountPaise,
    required this.currency,
    required this.keyId,
  });
}

class GatewaySubscription {
  final String plan; // free | silver | gold
  final String? billingCycle;
  final DateTime? expiryDate;
  final bool isActive;

  const GatewaySubscription({
    required this.plan,
    this.billingCycle,
    this.expiryDate,
    required this.isActive,
  });
}

class BillingClient {
  final http.Client _http;
  BillingClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  bool get available => AgentGatewayConfig.baseUrl.isNotEmpty;

  Future<Map<String, String>> _authHeaders() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw Exception('Not signed in');
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
  }

  /// Creates a Razorpay order on the server for [plan] ('silver'|'gold') and
  /// [cycle] ('monthly'|'yearly'). The amount is computed server-side.
  Future<BillingOrder> createOrder({
    required String plan,
    required String cycle,
  }) async {
    final res = await _http
        .post(
          Uri.parse('${AgentGatewayConfig.baseUrl}/v1/billing/order'),
          headers: await _authHeaders(),
          body: jsonEncode({'plan': plan, 'cycle': cycle}),
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      throw Exception('Order failed (${res.statusCode}): ${res.body}');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return BillingOrder(
      orderId: j['orderId'] as String,
      amountPaise: (j['amount'] as num).toInt(),
      currency: j['currency'] as String? ?? 'INR',
      keyId: j['keyId'] as String,
    );
  }

  /// Authoritative plan state. Poll this after payment until the plan flips.
  Future<GatewaySubscription> fetchSubscription() async {
    final res = await _http
        .get(
          Uri.parse('${AgentGatewayConfig.baseUrl}/v1/billing/subscription'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Subscription fetch failed (${res.statusCode})');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return GatewaySubscription(
      plan: j['plan'] as String? ?? 'free',
      billingCycle: j['billingCycle'] as String?,
      expiryDate: DateTime.tryParse(j['expiryDate'] as String? ?? ''),
      isActive: j['isActive'] == true,
    );
  }
}
