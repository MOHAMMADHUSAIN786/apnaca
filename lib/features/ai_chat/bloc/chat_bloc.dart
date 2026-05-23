import 'package:flutter_bloc/flutter_bloc.dart';
import '../model/chat_models.dart';
import '../repository/ai_chat_repository.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final AiChatRepository _repository;
  final List<ChatMessage> _history = [];

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

    _history.add(ChatMessage(role: 'user', content: userMsg));
    emit(ChatLoading(messages: List.from(_history)));

    try {
      final result = await _repository.sendMessage(
        userMessage: userMsg,
        history: _history,
      );

      // Store both tableData AND detailCard in the message
      // so they persist across future state changes
      _history.add(ChatMessage(
        role: 'assistant',
        content: result.reply,
        tableData: result.tableData,
        detailCard: result.detailCard,
      ));

      emit(ChatSuccess(messages: List.from(_history), lastResult: result));
    } catch (e) {
      final errMsg = 'Network error: ${e.toString()}';
      _history.add(ChatMessage(role: 'assistant', content: errMsg));
      emit(ChatError(messages: List.from(_history), error: errMsg));
    }
  }

  void _onClearChat(ClearChatEvent event, Emitter<ChatState> emit) {
    _history.clear();
    emit(ChatInitial());
  }
}
