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

class AiChatRepository {
  final OpenRouterService _llm;
  final ActionExecutor _executor;
  final AppDatabase _db;
  final RagMemoryService _rag;
  final FirebaseAuth _auth;

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
        _auth = auth ?? FirebaseAuth.instance;

  // ── Normal LLM message flow ────────────────────────────────────

  Future<ActionResult> sendMessage({
    required String userMessage,
    required List<ChatMessage> history,
    required String sessionId,
  }) async {
    final dbContext = await _db.getFullContextForAi();
    final ragContext =
    await _rag.buildRagContextString(sessionId: sessionId);

    final systemPrompt = MasterPromptService.buildSystemPrompt(
      dbContext: dbContext,
      ragContext: ragContext,
    );

    final rawJson = await _llm.chat(
      systemPrompt: systemPrompt,
      history: history.length > 15
          ? history.sublist(history.length - 15)
          : history,
      userMessage: userMessage,
    );

    final action = ActionParser.parse(rawJson);
    final result = await _executor.execute(action);

    // Save to RAG
    final allItems = (await _db.getAllItems()).map((i) => i.name).toList();
    final allCustomers =
    (await _db.getAllCustomers()).map((c) => c.name).toList();
    final extraction =
    RagMemoryService.extractEntities(userMessage, allItems, allCustomers);
    _saveToRag(
      sessionId: sessionId,
      userMessage: userMessage,
      aiReply: result.reply,
      action: action.type.name,
      mentionedItems: extraction.items,
      mentionedCustomers: extraction.customers,
      billNumber: result.detailCard?['Bill No'] as String?,
    );

    return result;
  }

  // ✅ Called by ChatBloc when BillFlowManager says state is ready
  Future<ActionResult> createBillFromState({
    required BillCreationState state,
    required String sessionId,
  }) async {
    final result = await _executor.createBillFromState(state);

    // Log to RAG
    _rag.saveMessage(
      sessionId: sessionId,
      role: 'assistant',
      content: result.reply,
      action: 'createSaleBill',
      billNumber: result.detailCard?['Bill No'] as String?,
    );

    return result;
  }

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
        billNumber: billNumber);
    _rag.saveMessage(
        sessionId: sessionId,
        role: 'assistant',
        content: aiReply,
        action: action,
        billNumber: billNumber);
  }
}
