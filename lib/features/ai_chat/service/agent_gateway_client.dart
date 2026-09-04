// Thin client for the ApnaCA Agent Gateway (server/).
//
// NOT wired into the app yet. Phase 2 integration:
//   1. Provision the gateway (Cloud Run) + set AgentGatewayConfig.baseUrl.
//   2. In AiChatRepository, when `useGateway` flag is on, call
//      `AgentGatewayClient.chat(...)` instead of OpenRouterService +
//      ActionParser + ActionExecutor.
//   3. Apply each returned proposed action via the existing ActionExecutor,
//      showing a confirm dialog when `requiresConfirmation` is true, then
//      POST /v1/agent/actions/ack with the outcomes.
//
// Offline, keep the current local path as a read-only fallback.

import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AgentGatewayConfig {
  /// e.g. https://apnaca-agent-gateway-xxxx.a.run.app
  static String baseUrl = const String.fromEnvironment(
    'AGENT_GATEWAY_URL',
    defaultValue: '',
  );

  /// Master switch. Off until the gateway is deployed + tested.
  static bool enabled = false;
}

/// One event from the SSE stream.
class AgentEvent {
  final String type; // step_start | tool_call | tool_result | message | error | done | conversation
  final Map<String, dynamic> data;
  const AgentEvent(this.type, this.data);
}

class ProposedAction {
  final String id;
  final String tool;
  final Map<String, dynamic> args;
  final bool requiresConfirmation;

  const ProposedAction({
    required this.id,
    required this.tool,
    required this.args,
    required this.requiresConfirmation,
  });

  factory ProposedAction.fromJson(Map<String, dynamic> j) => ProposedAction(
        id: j['id'] as String,
        tool: j['tool'] as String,
        args: (j['args'] as Map?)?.cast<String, dynamic>() ?? const {},
        requiresConfirmation: j['requiresConfirmation'] == true,
      );
}

class AgentTurnResult {
  final String conversationId;
  final String finalText;
  final List<ProposedAction> proposedActions;

  /// Renderable cards from read tools. Each is either
  ///   {type:'table', title?, rows:[{col:val}]}  or
  ///   {type:'detail', title?, fields:{k:v}}
  final List<Map<String, dynamic>> cards;

  const AgentTurnResult({
    required this.conversationId,
    required this.finalText,
    required this.proposedActions,
    this.cards = const [],
  });
}

class AgentGatewayClient {
  final http.Client _http;
  AgentGatewayClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  /// Runs one agent turn. [onEvent] receives streamed progress events;
  /// the returned future completes with the final result.
  ///
  /// [businessContext] is the compact snapshot the gateway needs (items,
  /// customers, suppliers, recentBills, analytics) — build it from AppDatabase.
  Future<AgentTurnResult> chat({
    required String message,
    required Map<String, dynamic> businessContext,
    String? conversationId,
    void Function(AgentEvent event)? onEvent,
  }) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw Exception('Not signed in');

    final req = http.Request('POST', Uri.parse('${AgentGatewayConfig.baseUrl}/v1/agent/chat'))
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'text/event-stream'
      ..body = jsonEncode({
        'conversationId': conversationId,
        'message': message,
        'context': businessContext,
      });

    final resp = await _http.send(req).timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200) {
      final body = await resp.stream.bytesToString();
      throw Exception('Gateway ${resp.statusCode}: $body');
    }

    String convId = conversationId ?? '';
    String finalText = '';
    final proposed = <ProposedAction>[];
    final cards = <Map<String, dynamic>>[];

    // Minimal SSE parser: events are separated by a blank line; we only need
    // the `data:` payload (one line per event here).
    await for (final chunk
        in resp.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      final line = chunk.trim();
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty) continue;

      final Map<String, dynamic> j;
      try {
        j = jsonDecode(payload) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }

      if (j.containsKey('conversationId') && !j.containsKey('type')) {
        convId = j['conversationId'] as String? ?? convId;
        onEvent?.call(AgentEvent('conversation', j));
        continue;
      }

      final type = j['type'] as String? ?? '';
      onEvent?.call(AgentEvent(type, j));

      if (type == 'message') {
        finalText = j['text'] as String? ?? finalText;
      } else if (type == 'card') {
        final card = j['card'];
        if (card is Map) cards.add(card.cast<String, dynamic>());
      } else if (type == 'done') {
        finalText = j['text'] as String? ?? finalText;
        for (final a in (j['proposedActions'] as List? ?? const [])) {
          proposed.add(ProposedAction.fromJson((a as Map).cast<String, dynamic>()));
        }
        final doneCards = j['cards'] as List? ?? const [];
        if (doneCards.isNotEmpty) {
          cards
            ..clear()
            ..addAll(doneCards.map((c) => (c as Map).cast<String, dynamic>()));
        }
      } else if (type == 'error') {
        throw Exception(j['message'] as String? ?? 'Agent error');
      }
    }

    return AgentTurnResult(
      conversationId: convId,
      finalText: finalText,
      proposedActions: proposed,
      cards: cards,
    );
  }

  /// Report which proposed actions were applied locally (for audit + metering).
  Future<void> ackActions({
    required String conversationId,
    required List<Map<String, dynamic>> applied, // {tool, args, result}
  }) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) return;
    await _http.post(
      Uri.parse('${AgentGatewayConfig.baseUrl}/v1/agent/actions/ack'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'conversationId': conversationId, 'applied': applied}),
    );
  }
}
