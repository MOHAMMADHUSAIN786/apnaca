import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../database/app_database.dart';
import '../model/chat_models.dart';
import '../service/action_executor.dart';
import '../service/action_parser.dart';
import '../service/master_prompt_service.dart';
import '../service/openrouter_service.dart';

class AiChatRepository {
  final OpenRouterService _llm;
  final ActionExecutor _executor;
  final AppDatabase _db;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AiChatRepository({
    required OpenRouterService llm,
    ActionExecutor? executor,
    AppDatabase? db,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _llm = llm,
        _executor = executor ?? ActionExecutor(),
        _db = db ?? AppDatabase.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<ActionResult> sendMessage({
    required String userMessage,
    required List<ChatMessage> history,
  }) async {
    // 1. Live DB context (items + customers)
    final dbContext = await _db.getFullContextForAi();

    // 2. Build system prompt
    final systemPrompt = MasterPromptService.buildSystemPrompt(
      dbContext: dbContext,
    );

    // 3. Call LLM
    final rawJson = await _llm.chat(
      systemPrompt: systemPrompt,
      history: history,
      userMessage: userMessage,
    );

    // 4. Parse
    final action = ActionParser.parse(rawJson);

    // 5. Execute DB operation
    final result = await _executor.execute(action);

    // 6. Log query to Firestore for accuracy improvement
    _logQueryAsync(
      userMessage: userMessage,
      aiAction: action.type.name,
      aiReply: action.reply,
      success: result.type == ActionResultType.success,
    );

    return result;
  }

  // Fire and forget — does not block the main flow
  void _logQueryAsync({
    required String userMessage,
    required String aiAction,
    required String aiReply,
    required bool success,
  }) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _firestore
        .collection('ai_queries')
        .doc(uid)
        .collection('logs')
        .add({
      'query': userMessage,
      'action': aiAction,
      'reply': aiReply,
      'success': success,
      'timestamp': FieldValue.serverTimestamp(),
    }).catchError((_) {
      // Silent fail — logging should never break the app
    });
  }
}
