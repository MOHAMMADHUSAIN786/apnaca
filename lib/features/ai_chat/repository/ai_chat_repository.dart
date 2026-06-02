import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../database/app_database.dart';
import '../model/bill_creation_state.dart';
import '../model/chat_models.dart';
import '../rag/rag_memory_service.dart';
import '../service/action_executor.dart';
import '../service/action_parser.dart';
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

  AiChatRepository({
    required OpenRouterService llm,
    ActionExecutor? executor,
    AppDatabase? db,
    RagMemoryService? rag,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _llm = llm,
        _executor = executor ?? ActionExecutor(),
        _db = db ?? AppDatabase.instance,
        _rag = rag ?? RagMemoryService(),
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  // ── Normal LLM message flow ────────────────────────────────────────────────

  Future<ActionResult> sendMessage({
    required String userMessage,
    required List<ChatMessage> history,
    required String sessionId,
  }) async {
    try {
      // ── SUBSCRIPTION CHECK: AI prompt limit ─────────────────────────────
      final promptCheck = await SubscriptionService.instance.canUseAiPrompt();
      if (!promptCheck.allowed) {
        return ActionResult.error(
          message: '🔒 ${promptCheck.reason ?? "Daily AI prompt limit reached. Upgrade your plan for more prompts."}',
        );
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