// lib/features/ai_chat/repository/ai_chat_repository.dart
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../database/app_database.dart';
import '../../customer/model/customer_model.dart';
import '../../item/model/item_model.dart';
import '../../supplier/model/supplier_model.dart';
import '../model/bill_creation_state.dart';
import '../model/chat_models.dart';
import '../rag/rag_memory_service.dart';
import '../service/action_executor.dart';
import '../service/action_parser.dart';
import '../service/master_prompt_service.dart';
import '../service/openrouter_service.dart';

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

  // ════════════════════════════════════════════════════════════════════════
  //  SEND MESSAGE
  //  FIX 5 — contextDepth parameter added (default 10, 15 during bill flow)
  // ════════════════════════════════════════════════════════════════════════
  Future<ActionResult> sendMessage({
    required String userMessage,
    required List<ChatMessage> history,
    required String sessionId,
    String detectedLanguage = 'hinglish',
    int contextDepth = 10, // FIX 5
  }) async {
    try {
      final dbContext = await _rag.buildDbContext(_db);

      // FIX 5 — BEFORE: _rag.buildRagContext(sessionId)  (limit hardcoded to 6)
      // AFTER:  contextDepth passed through so bill flow gets 15 messages of context
      final ragContext = await _rag.buildRagContext(
        sessionId,
        contextDepth: contextDepth,
      );
      final analyticsContext = await _db.getAnalyticsContextForAi();

      final systemPrompt = MasterPromptService.buildSystemPrompt(
        dbContext: dbContext,
        ragContext: ragContext,
        analyticsContext: analyticsContext,
        detectedLanguage: detectedLanguage,
      );

      final rawJson = await _llm.chat(
        systemPrompt: systemPrompt,
        history: history.length > 15 ? history.sublist(history.length - 15) : history,
        userMessage: userMessage,
      );

      // ── Parse ────────────────────────────────────────────────────────
      ParsedAction action;
      ActionResult result;

      try {
        action = ActionParser.parse(rawJson);
      } catch (parseErr) {
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

      // ── Execute ──────────────────────────────────────────────────────
      try {
        result = await _executor.execute(action);
      } catch (execErr) {
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

      // ── FIX 6 — Save to RAG (AWAITED, not fire-and-forget) ──────────
      // BEFORE: _saveToRag(...)  — fire-and-forget void, errors silently swallowed
      // AFTER:  await _saveToRag(...)  wrapped in try/catch with proper logging
      try {
        final allItems     = (await _db.getAllItems()).map((i) => i.name).toList();
        final allCustomers = (await _db.getAllCustomers()).map((c) => c.name).toList();
        final extraction   = _extractEntities(userMessage, allItems, allCustomers);
        await _saveToRag(
          sessionId: sessionId,
          userMessage: userMessage,
          aiReply: result.reply,
          action: action.type.name,
          mentionedItems: extraction.$1,
          mentionedCustomers: extraction.$2,
          billNumber: result.detailCard?['Bill No'] as String?,
        );
      } catch (ragErr) {
        // FIX 6 — BEFORE: catch (_) {}  (silently swallowed)
        // AFTER:  proper log so RAG failures are visible in debug console
        developer.log('RAG save failed: $ragErr', name: 'ApnaCA.RAG');
      }

      return result;
    } catch (e) {
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

  // ════════════════════════════════════════════════════════════════════════
  //  FIX 7 — executeDirectAction
  //  New method called by ChatBloc AFTER user confirms a pending delete.
  //  BEFORE: no such method — deletes executed immediately without confirmation
  //  AFTER:  bloc stores ParsedAction, calls this after user says "haan"
  // ════════════════════════════════════════════════════════════════════════
  Future<ActionResult> executeDirectAction({
    required ParsedAction action,
    required String sessionId,
  }) async {
    try {
      final result = await _executor.execute(action);
      // Save confirmed delete to RAG
      try {
        await _saveToRag(
          sessionId: sessionId,
          userMessage: '[confirmed delete: ${action.type.name}]',
          aiReply: result.reply,
          action: action.type.name,
          mentionedItems: [],
          mentionedCustomers: [],
        );
      } catch (ragErr) {
        developer.log('RAG save failed after delete: $ragErr', name: 'ApnaCA.RAG');
      }
      return result;
    } catch (e) {
      return ActionResult.error(message: '⚠️ Delete nahi ho saka: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BILL CREATION FROM STATE
  // ════════════════════════════════════════════════════════════════════════
  Future<ActionResult> createBillFromState({
    required BillCreationState state,
    required String sessionId,
  }) async {
    try {
      final result = await _executor.createBillFromState(state);
      // FIX 6 — await the RAG save here too
      try {
        await _rag.saveMessage(
          sessionId: sessionId,
          role: 'assistant',
          content: result.reply,
          action: 'createSaleBill',
          billNumber: result.detailCard?['Bill No'] as String?,
        );
      } catch (ragErr) {
        developer.log('RAG save failed (bill creation): $ragErr', name: 'ApnaCA.RAG');
      }
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

  // ════════════════════════════════════════════════════════════════════════
  //  FIX 8 — createEntityByName — TYPE-SAFE OptionalStep parameter
  //
  //  BEFORE:
  //    required dynamic type
  //    final typeName = type.toString().toLowerCase();
  //    if (typeName.contains('customer')) { ... }
  //    — brittle string matching, breaks on enum rename
  //
  //  AFTER:
  //    required OptionalStep entityType
  //    switch (entityType) { case OptionalStep.customer: ... }
  //    — compile-time type-safe, exhaustive switch
  // ════════════════════════════════════════════════════════════════════════
  Future<ActionResult> createEntityByName({
    required String name,
    required OptionalStep entityType, // FIX 8 — was: required dynamic type
    required String sessionId,
  }) async {
    try {
      // FIX 8 — BEFORE: if (typeName.contains('customer')) (string hack)
      // AFTER:  switch on enum — exhaustive, type-safe, no string matching
      switch (entityType) {
        case OptionalStep.customer:
          if (await _db.customerNameExists(name)) {
            return ActionResult.error(
                message: '⚠️ "$name" customer pehle se exist karta hai.');
          }
          final cId = await _db.insertCustomer(CustomerModel(name: name));
          return ActionResult.success(
              reply: '✅ "$name" customer add ho gaya!', affectedId: cId);

        case OptionalStep.supplier:
          if (await _db.supplierNameExists(name)) {
            return ActionResult.error(
                message: '⚠️ "$name" supplier pehle se exist karta hai.');
          }
          final sId = await _db.insertSupplier(SupplierModel(name: name));
          return ActionResult.success(
              reply: '✅ "$name" supplier add ho gaya!', affectedId: sId);

        case OptionalStep.item:
        case OptionalStep.none: // 'none' falls through to item as safe default
          if (await _db.itemNameExists(name)) {
            return ActionResult.error(
                message: '⚠️ "$name" item pehle se exist karta hai.');
          }
          final iId = await _db.insertItem(ItemModel(name: name, qty: 0, price: 0));
          return ActionResult.success(
              reply: '✅ "$name" item add ho gaya!', affectedId: iId);
      }
    } catch (e) {
      return ActionResult.error(message: '⚠️ Save nahi ho saka: $e');
    }
  }

  // ── Entity extraction ────────────────────────────────────────────────────

  (List<String>, List<String>) _extractEntities(
      String message,
      List<String> allItems,
      List<String> allCustomers,
      ) {
    final lowerMsg = message.toLowerCase();
    final items     = allItems.where((i) => lowerMsg.contains(i.toLowerCase())).toList();
    final customers = allCustomers.where((c) => lowerMsg.contains(c.toLowerCase())).toList();
    return (items, customers);
  }

  // ── Error logging ────────────────────────────────────────────────────────

  Future<void> _logError({
    required String type,
    required String userMessage,
    required String rawResponse,
    required String error,
    String? action,
  }) async {
    developer.log(
      '[$type] user: "$userMessage" | action: $action | error: $error',
      name: 'ApnaCA.AI',
      error: error,
    );
    try {
      final uid = _auth.currentUser?.uid;
      await _firestore.collection('ai_error_logs').add({
        'uid': uid ?? 'unknown',
        'type': type,
        'user_message': userMessage,
        'action': action,
        'raw_response':
        rawResponse.length > 500 ? rawResponse.substring(0, 500) : rawResponse,
        'error': error.length > 300 ? error.substring(0, 300) : error,
        'timestamp': FieldValue.serverTimestamp(),
        'app': 'ApnaCA',
      });
    } catch (_) {}
  }

  // ════════════════════════════════════════════════════════════════════════
  //  FIX 6 — _saveToRag returns Future<void> (not void)
  //
  //  BEFORE: void _saveToRag(...)  — caller could not await it
  //  AFTER:  Future<void> _saveToRag(...)  — caller awaits + catches errors
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _saveToRag({
    required String sessionId,
    required String userMessage,
    required String aiReply,
    required String action,
    required List<String> mentionedItems,
    required List<String> mentionedCustomers,
    String? billNumber,
  }) async {
    // FIX 6 — Both calls are now awaited inside this Future<void> method
    await _rag.saveMessage(
      sessionId: sessionId,
      role: 'user',
      content: userMessage,
      action: action,
      mentionedItems: mentionedItems,
      mentionedCustomers: mentionedCustomers,
      billNumber: billNumber,
    );
    await _rag.saveMessage(
      sessionId: sessionId,
      role: 'assistant',
      content: aiReply,
      action: action,
      billNumber: billNumber,
    );
  }
}