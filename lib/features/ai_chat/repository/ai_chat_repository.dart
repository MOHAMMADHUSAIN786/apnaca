import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../database/app_database.dart';
import '../model/bill_creation_state.dart';
import '../model/chat_models.dart';
import '../rag/rag_memory_service.dart';
import '../service/action_executor.dart';
import '../service/action_parser.dart';
import '../service/agent_gateway_client.dart';
import '../service/master_prompt_service.dart';
import '../service/openrouter_service.dart';
import '../../subscription/service/subscription_service.dart';

class AiChatRepository {
  final OpenRouterService _llm;
  final ActionExecutor _executor;
  final AppDatabase _db;
  final RagMemoryService _rag;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final AgentGatewayClient _gateway;

  /// sessionId → server conversationId. A new session (e.g. after "clear chat")
  /// has no entry, so the gateway starts a fresh conversation automatically.
  final Map<String, String> _gatewayConversations = {};

  AiChatRepository({
    required OpenRouterService llm,
    ActionExecutor? executor,
    AppDatabase? db,
    RagMemoryService? rag,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AgentGatewayClient? gateway,
  })  : _llm = llm,
        _executor = executor ?? ActionExecutor(),
        _db = db ?? AppDatabase.instance,
        _rag = rag ?? RagMemoryService(),
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _gateway = gateway ?? AgentGatewayClient();

  // ── Normal LLM message flow ────────────────────────────────────────────────

  Future<ActionResult> sendMessage({
    required String userMessage,
    required List<ChatMessage> history,
    required String sessionId,
    /// Called (gateway path only) with the full answer text as it streams in.
    void Function(String textSoFar)? onToken,
  }) async {
    try {
      // ── SUBSCRIPTION CHECK: AI prompt limit ─────────────────────────────
      final promptCheck = await SubscriptionService.instance.canUseAiPrompt();
      if (!promptCheck.allowed) {
        return ActionResult.error(
          message: '🔒 ${promptCheck.reason ?? "Daily AI prompt limit reached. Upgrade your plan for more prompts."}',
        );
      }

      // ── AGENT GATEWAY (Phase 2) — feature-flagged ──────────────────────
      if (AgentGatewayConfig.enabled) {
        try {
          return await _sendViaGateway(
            userMessage: userMessage,
            sessionId: sessionId,
            onToken: onToken,
          );
        } catch (e) {
          // Gateway unreachable / failed → fall back to the local path below.
          await _logError(
            type: 'gateway_error',
            userMessage: userMessage,
            rawResponse: '',
            error: e.toString(),
          );
        }
      }

      final dbContext = await _db.getFullContextForAi();
      final ragContext = await _rag.buildRagContextString(sessionId: sessionId);
      final analyticsContext = await _db.getAnalyticsContextForAi();

      final systemPrompt = MasterPromptService.buildSystemPrompt(
        dbContext: dbContext,
        ragContext: ragContext,
        analyticsContext: analyticsContext,
      );

      final rawJson = await _llm.chat(
        systemPrompt: systemPrompt,
        history: history.length > 15 ? history.sublist(history.length - 15) : history,
        userMessage: userMessage,
      );

      // ── Increment AI prompt count AFTER successful LLM call ──────────────
      SubscriptionService.instance.incrementAiPromptCount().catchError((_) {});

      // ── Parse & execute ──────────────────────────────────────────
      ParsedAction action;
      ActionResult result;

      try {
        action = ActionParser.parse(rawJson);
      } catch (parseErr) {
        // Log parse error silently — show friendly message to user
        await _logError(
          type: 'parse_error',
          userMessage: userMessage,
          rawResponse: rawJson,
          error: parseErr.toString(),
        );
        return ActionResult.error(
          message: 'Samajh nahi aaya. Thoda alag tarike se bolein.\n'
              'Example: "apple item add karo 5 qty 50 price"',
        );
      }

      try {
        result = await _executor.execute(action);
      } catch (execErr) {
        // Log execution error silently
        await _logError(
          type: 'executor_error',
          userMessage: userMessage,
          rawResponse: rawJson,
          error: execErr.toString(),
          action: action.type.name,
        );
        return ActionResult.error(
          message: 'Kuch gadbad ho gayi. Dobara try karein.',
        );
      }

      // ── Save to RAG ──────────────────────────────────────────────
      try {
        final allItems = (await _db.getAllItems()).map((i) => i.name).toList();
        final allCustomers = (await _db.getAllCustomers()).map((c) => c.name).toList();
        final extraction = RagMemoryService.extractEntities(userMessage, allItems, allCustomers);
        _saveToRag(
          sessionId: sessionId,
          userMessage: userMessage,
          aiReply: result.reply,
          action: action.type.name,
          mentionedItems: extraction.items,
          mentionedCustomers: extraction.customers,
          billNumber: result.detailCard?['Bill No'] as String?,
        );
      } catch (_) {
        // RAG save failure is non-critical — ignore
      }

      return result;
    } catch (e) {
      // Network / top-level error
      await _logError(
        type: 'network_error',
        userMessage: userMessage,
        rawResponse: '',
        error: e.toString(),
      );

      final isNetwork = e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException') ||
          e.toString().contains('HandshakeException');

      if (isNetwork) {
        return ActionResult.error(
          message: '📶 Internet connection nahi hai ya slow hai. '
              'Network check karein aur dobara try karein.',
        );
      }
      return ActionResult.error(
        message: '⚠️ Kuch gadbad ho gayi. Thodi der baad try karein.',
      );
    }
  }

  // ── Bill creation from state ───────────────────────────────────────────────

  Future<ActionResult> createBillFromState({
    required BillCreationState state,
    required String sessionId,
  }) async {
    try {
      final result = await _executor.createBillFromState(state);

      _rag.saveMessage(
        sessionId: sessionId,
        role: 'assistant',
        content: result.reply,
        action: 'createSaleBill',
        billNumber: result.detailCard?['Bill No'] as String?,
      );

      return result;
    } catch (e) {
      await _logError(
        type: 'bill_creation_error',
        userMessage: 'Bill create: ${state.customerName}',
        rawResponse: '',
        error: e.toString(),
      );
      return ActionResult.error(
        message: '⚠️ Bill banate waqt error aaya. Dobara try karein.',
      );
    }
  }

  // ── Agent Gateway path ────────────────────────────────────────────────────
  // Sends the turn to the server (server holds the LLM key, does tool-calling +
  // permission checks). Read answers come back as text; write actions come back
  // as "proposed actions" that we apply locally via ActionExecutor.

  Future<ActionResult> _sendViaGateway({
    required String userMessage,
    required String sessionId,
    void Function(String textSoFar)? onToken,
  }) async {
    final context = await _db.getBusinessContextForGateway();

    final buf = StringBuffer();
    final turn = await _gateway.chat(
      message: userMessage,
      businessContext: context,
      conversationId: _gatewayConversations[sessionId],
      onEvent: onToken == null
          ? null
          : (e) {
              // A new agent step supersedes any partial text from the previous one.
              if (e.type == 'step_start') {
                buf.clear();
              } else if (e.type == 'text_delta') {
                buf.write(e.data['text'] as String? ?? '');
                onToken(buf.toString());
              }
            },
    );
    _gatewayConversations[sessionId] = turn.conversationId;

    SubscriptionService.instance.incrementAiPromptCount().catchError((_) {});

    final (gwTable, gwDetail) = _mapGatewayCards(turn.cards);

    // Informational answer, nothing to apply.
    if (turn.proposedActions.isEmpty) {
      return ActionResult.success(
        reply: turn.finalText.trim().isEmpty ? '✅' : turn.finalText.trim(),
        tableData: gwTable,
        detailCard: gwDetail,
      );
    }

    // A bill proposal → run it through the existing bill flow so the
    // ChatBloc state machine (items / discount / tax / payment) takes over.
    for (final a in turn.proposedActions) {
      if (a.tool == 'create_sale_bill' || a.tool == 'create_purchase_bill') {
        return _executor.execute(_proposedToParsed(a.tool, a.args));
      }
    }

    // Apply non-destructive writes now; collect destructive ones for an
    // in-chat confirm prompt.
    final applied = <Map<String, dynamic>>[];
    final pending = <PendingAiAction>[];
    ActionResult? last;

    for (final a in turn.proposedActions) {
      if (a.requiresConfirmation) {
        pending.add(PendingAiAction(
          id: a.id,
          tool: a.tool,
          args: a.args,
          label: _labelForAction(a.tool, a.args),
        ));
        continue;
      }
      try {
        final data = await _enrichActionData(a.tool, a.args);
        last = await _executor.execute(_proposedToParsed(a.tool, data));
        applied.add({'tool': a.tool, 'args': a.args, 'result': 'applied'});
      } catch (_) {
        applied.add({'tool': a.tool, 'args': a.args, 'result': 'failed'});
      }
    }

    if (applied.isNotEmpty) {
      _gateway
          .ackActions(conversationId: turn.conversationId, applied: applied)
          .catchError((_) {});
    }

    final reply = turn.finalText.trim();

    if (pending.isNotEmpty) {
      return ActionResult.confirmRequired(
        reply: reply.isEmpty ? 'Confirm karein?' : reply,
        pendingActions: pending,
        conversationId: turn.conversationId,
        tableData: last?.tableData ?? gwTable,
        detailCard: last?.detailCard ?? gwDetail,
      );
    }

    return ActionResult.success(
      reply: reply.isEmpty ? (last?.reply ?? '✅') : reply,
      tableData: last?.tableData ?? gwTable,
      detailCard: last?.detailCard ?? gwDetail,
    );
  }

  /// Applies (or rejects) destructive actions the user confirmed in the chat.
  Future<ActionResult> applyConfirmedActions({
    required List<PendingAiAction> actions,
    required String? conversationId,
    required bool approved,
  }) async {
    if (!approved) {
      _gateway
          .ackActions(
            conversationId: conversationId ?? '',
            applied: actions
                .map((a) => {'tool': a.tool, 'args': a.args, 'result': 'rejected'})
                .toList(),
          )
          .catchError((_) {});
      return ActionResult.success(reply: '❌ Theek hai, cancel kar diya.');
    }

    final ack = <Map<String, dynamic>>[];
    final replies = <String>[];
    ActionResult? last;

    for (final a in actions) {
      try {
        final data = await _enrichActionData(a.tool, a.args);
        final r = await _executor.execute(_proposedToParsed(a.tool, data));
        last = r;
        if (r.reply.trim().isNotEmpty) replies.add(r.reply.trim());
        ack.add({'tool': a.tool, 'args': a.args, 'result': 'applied'});
      } catch (_) {
        replies.add('⚠️ ${a.label} — nahi ho paya.');
        ack.add({'tool': a.tool, 'args': a.args, 'result': 'failed'});
      }
    }

    _gateway
        .ackActions(conversationId: conversationId ?? '', applied: ack)
        .catchError((_) {});

    return ActionResult.success(
      reply: replies.isEmpty ? '✅ Ho gaya.' : replies.join('\n'),
      tableData: last?.tableData,
      detailCard: last?.detailCard,
    );
  }

  String _labelForAction(String tool, Map<String, dynamic> d) {
    switch (tool) {
      case 'delete_item':
        return 'Item "${d['name']}" delete karein';
      case 'delete_customer':
        return 'Customer "${d['name']}" delete karein';
      case 'delete_supplier':
        return 'Supplier "${d['name']}" delete karein';
      case 'stock_adjustment':
        return '"${d['name']}" ka stock ${d['qty']} set karein';
      default:
        return '$tool $d';
    }
  }

  /// Maps gateway render-cards to the single tableData / detailCard the chat
  /// bubble supports (first table, first detail).
  (List<Map<String, dynamic>>?, Map<String, dynamic>?) _mapGatewayCards(
      List<Map<String, dynamic>> cards) {
    List<Map<String, dynamic>>? table;
    Map<String, dynamic>? detail;
    for (final c in cards) {
      if (c['type'] == 'table' && table == null) {
        final rows = (c['rows'] as List? ?? const [])
            .map((r) => (r as Map).cast<String, dynamic>())
            .toList();
        if (rows.isNotEmpty) table = rows;
      } else if (c['type'] == 'detail' && detail == null) {
        final fields = (c['fields'] as Map? ?? const {}).cast<String, dynamic>();
        if (fields.isNotEmpty) detail = {'type': 'analytics', ...fields};
      }
    }
    return (table, detail);
  }

  ParsedAction _proposedToParsed(String tool, Map<String, dynamic> d) {
    switch (tool) {
      case 'create_customer':
        return ParsedAction(type: AiActionType.createCustomer, data: {
          'name': d['name'],
          'phone': d['phone'],
          'email': d['email'],
          'gst_number': d['gstNumber'],
          'state': d['state'],
        }, reply: '');
      case 'create_item':
        return ParsedAction(type: AiActionType.createItem, data: {
          'name': d['name'],
          'qty': d['qty'],
          'price': d['price'],
        }, reply: '"${d['name']}" add kar diya ✓');
      case 'delete_item':
        return ParsedAction(
            type: AiActionType.deleteItem,
            data: {...d}, // includes resolved 'id' from _enrichActionData
            reply: '🗑️ "${d['name']}" delete kar diya');
      case 'delete_customer':
        return ParsedAction(
            type: AiActionType.deleteCustomer,
            data: {...d},
            reply: '🗑️ "${d['name']}" delete kar diya');
      case 'delete_supplier':
        return ParsedAction(
            type: AiActionType.deleteSupplier,
            data: {...d},
            reply: '🗑️ "${d['name']}" delete kar diya');
      case 'stock_adjustment':
        return ParsedAction(type: AiActionType.stockAdjustment, data: {
          'name': d['name'],
          'qty': d['qty'],
          'reason': d['reason'],
        }, reply: '"${d['name']}" ka stock ${d['qty']} set kar diya ✓');
      case 'create_sale_bill':
        return ParsedAction(type: AiActionType.createSaleBill, data: {
          'customer_name': d['customerName'],
          'items': d['items'],
          'discount_type': d['discountType'],
          'discount_value': d['discountValue'],
          'tax_type': d['taxType'],
          'tax_rate': d['taxRate'],
          'payment_mode': d['paymentMode'],
          'payment_status': d['paymentStatus'],
        }, reply: 'Bill bana raha hoon...');
      case 'create_purchase_bill':
        return ParsedAction(type: AiActionType.createPurchaseBill, data: {
          'supplier_name': d['supplierName'],
          'items': d['items'],
          'tax_type': d['taxType'],
          'tax_rate': d['taxRate'],
          'payment_mode': d['paymentMode'],
          'payment_status': d['paymentStatus'],
        }, reply: 'Purchase bill bana raha hoon...');
      default:
        return ParsedAction(
            type: AiActionType.error,
            data: const {},
            reply: 'Yeh action abhi support nahi hai.');
    }
  }

  /// Resolves a name → local row id for tools whose ActionExecutor branch needs
  /// an id (delete_*/update_*). Stock tools resolve by name themselves.
  Future<Map<String, dynamic>> _enrichActionData(
      String tool, Map<String, dynamic> src) async {
    final d = Map<String, dynamic>.from(src);
    final name = (d['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return d;

    if (tool == 'delete_item' || tool == 'update_item') {
      final it = await _db.getItemByName(name) ?? await _db.getItemFuzzy(name);
      if (it?.id != null) d['id'] = it!.id;
    } else if (tool == 'delete_customer' || tool == 'update_customer') {
      final c = await _db.getCustomerByName(name) ?? await _db.getCustomerFuzzy(name);
      if (c?.id != null) d['id'] = c!.id;
    } else if (tool == 'delete_supplier' || tool == 'update_supplier') {
      final s = await _db.getSupplierByName(name) ?? await _db.getSupplierFuzzy(name);
      if (s?.id != null) d['id'] = s!.id;
    }
    return d;
  }

  // ── Error logging to Firestore ─────────────────────────────────────────────
  // Silently logs errors — user ko kuch nahi dikhta
  Future<void> _logError({
    required String type,
    required String userMessage,
    required String rawResponse,
    required String error,
    String? action,
  }) async {
    // Always log to Flutter dev console
    developer.log(
      '[$type] user: "$userMessage" | action: $action | error: $error',
      name: 'ApnaCA.AI',
      error: error,
    );

    // Log to Firestore silently (non-blocking)
    try {
      final uid = _auth.currentUser?.uid;
      await _firestore
          .collection('ai_error_logs')
          .add({
        'uid': uid ?? 'unknown',
        'type': type,
        'user_message': userMessage,
        'action': action,
        'raw_response': rawResponse.length > 500
            ? rawResponse.substring(0, 500)
            : rawResponse,
        'error': error.length > 300 ? error.substring(0, 300) : error,
        'timestamp': FieldValue.serverTimestamp(),
        'app': 'ApnaCA',
      });
    } catch (_) {
      // Firestore log failure is completely silent
    }
  }

  // ── RAG helper ─────────────────────────────────────────────────────────────
  void _saveToRag({
    required String sessionId,
    required String userMessage,
    required String aiReply,
    required String action,
    required List<String> mentionedItems,
    required List<String> mentionedCustomers,
    String? billNumber,
  }) {
    _rag.saveMessage(
      sessionId: sessionId,
      role: 'user',
      content: userMessage,
      action: action,
      mentionedItems: mentionedItems,
      mentionedCustomers: mentionedCustomers,
      billNumber: billNumber,
    );
    _rag.saveMessage(
      sessionId: sessionId,
      role: 'assistant',
      content: aiReply,
      action: action,
      billNumber: billNumber,
    );
  }
}