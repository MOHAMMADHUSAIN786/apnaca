import 'package:flutter_bloc/flutter_bloc.dart';

import '../model/bill_creation_state.dart';
import '../model/chat_models.dart';
import '../repository/ai_chat_repository.dart';
import '../service/bill_flow_manager.dart';
import '../service/input_validator.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final AiChatRepository _repository;
  final List<ChatMessage> _history = [];

  // Session tracking for RAG
  String _sessionId = _generateSessionId();
  static String _generateSessionId() =>
      'session_${DateTime.now().millisecondsSinceEpoch}';

  // ✅ Bill creation state machine — lives in Dart, NOT LLM
  BillCreationState _billState = BillCreationState.empty;

  ChatBloc({required AiChatRepository repository})
      : _repository = repository,
        super(ChatInitial()) {
    on<SendMessageEvent>(_onSendMessage);
    on<ClearChatEvent>(_onClearChat);
  }

  Future<void> _onSendMessage(
      SendMessageEvent event,
      Emitter<ChatState> emit,
      ) async {
    final userMsg = event.message.trim();
    if (userMsg.isEmpty) return;

    // Security validation
    final validationError = InputValidator.validate(userMsg);
    if (validationError != null) {
      _addMsg(role: 'user', content: userMsg);
      _addMsg(role: 'assistant', content: '🚫 $validationError');
      emit(ChatError(messages: List.from(_history), error: validationError));
      return;
    }

    _addMsg(role: 'user', content: userMsg);
    emit(ChatLoading(messages: List.from(_history)));

    try {
      // ── BILL FLOW: if active, handle in Dart ─────────────────
      if (_billState.isActive && !_billState.isReady) {
        final (newState, question) = BillFlowManager.processReply(
          userMessage: userMsg,
          state: _billState,
        );
        _billState = newState;

        if (question != null) {
          // Still collecting — show question to user
          _addMsg(role: 'assistant', content: question);
          emit(ChatSuccess(
            messages: List.from(_history),
            lastResult: ActionResult.needsInput(
                question: question, field: 'bill_flow'),
          ));
          return;
        }

        // question == null means state is READY — create bill now
        if (_billState.isReady) {
          final result = await _repository.createBillFromState(
            state: _billState,
            sessionId: _sessionId,
          );
          _billState = BillCreationState.empty; // reset
          if (result.isSubscriptionRequired) {
            _addMsg(role: 'assistant', content: result.reply, isSubscriptionRequired: true);
            emit(ChatSuccess(messages: List.from(_history), lastResult: result));
            return;
          }
          _addMsg(
            role: 'assistant',
            content: result.reply,
            tableData: result.tableData,
            detailCard: result.detailCard,
          );
          emit(ChatSuccess(messages: List.from(_history), lastResult: result));
          return;
        }
      }

      // ── NORMAL: send to LLM ───────────────────────────────────
      final result = await _repository.sendMessage(
        userMessage: userMsg,
        history: _history,
        sessionId: _sessionId,
      );

      // ✅ If LLM wants to start a bill, hand off to flow manager
      if (result.type == ActionResultType.startBillFlow) {
        _billState = result.initialBillState!;

        // ── If ALL fields already provided by user in one message → create immediately
        if (_billState.isReady) {
          final billResult = await _repository.createBillFromState(
            state: _billState,
            sessionId: _sessionId,
          );
          _billState = BillCreationState.empty;
          if (billResult.isSubscriptionRequired) {
            _addMsg(role: 'assistant', content: billResult.reply, isSubscriptionRequired: true);
            emit(ChatSuccess(messages: List.from(_history), lastResult: billResult));
            return;
          }
          _addMsg(
            role: 'assistant',
            content: billResult.reply,
            tableData: billResult.tableData,
            detailCard: billResult.detailCard,
          );
          emit(ChatSuccess(messages: List.from(_history), lastResult: billResult));
          return;
        }

        // ── Otherwise ask the first missing question
        final question = _billState.step == BillStep.collectingItems
            ? 'Kaunsa item aur kitni quantity?\nExample: "apple 5, mango 10"'
            : BillFlowManager.nextQuestion(_billState);
        final q = question ?? 'Koi discount dena hai? (haan / nahi)';
        _addMsg(role: 'assistant', content: q);
        emit(ChatSuccess(
          messages: List.from(_history),
          lastResult: ActionResult.needsInput(question: q, field: 'items'),
        ));
        return;
      }

      _addMsg(
        role: 'assistant',
        content: result.reply,
        tableData: result.tableData,
        detailCard: result.detailCard,
        isCustomerNotFound: result.isCustomerNotFound,
        isSubscriptionRequired: result.isSubscriptionRequired,
      );
      emit(ChatSuccess(messages: List.from(_history), lastResult: result));
    } catch (e) {
      final errMsg = 'Network error: ${e.toString()}';
      _addMsg(role: 'assistant', content: errMsg);
      emit(ChatError(messages: List.from(_history), error: errMsg));
    }
  }

  void _onClearChat(ClearChatEvent event, Emitter<ChatState> emit) {
    _history.clear();
    _billState = BillCreationState.empty;
    _sessionId = _generateSessionId();
    emit(ChatInitial());
  }

  void _addMsg({
    required String role,
    required String content,
    List<Map<String, dynamic>>? tableData,
    Map<String, dynamic>? detailCard,
    bool isCustomerNotFound = false,
    bool isSubscriptionRequired = false,
  }) {
    _history.add(ChatMessage(
      role: role,
      content: content,
      tableData: tableData,
      detailCard: detailCard,
      isCustomerNotFound: isCustomerNotFound,
      isSubscriptionRequired: isSubscriptionRequired,
    ));
  }
}
