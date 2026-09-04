import '../model/chat_models.dart';

abstract class ChatState {}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {
  final List<ChatMessage> messages;
  ChatLoading({required this.messages});
}

/// Gateway path only — the answer is streaming in token by token.
/// [messages] already includes the in-progress assistant message as its last item.
class ChatStreaming extends ChatState {
  final List<ChatMessage> messages;
  final String partialText;
  ChatStreaming({required this.messages, required this.partialText});
}

class ChatSuccess extends ChatState {
  final List<ChatMessage> messages;
  final ActionResult lastResult;
  ChatSuccess({required this.messages, required this.lastResult});
}

class ChatError extends ChatState {
  final List<ChatMessage> messages;
  final String error;
  ChatError({required this.messages, required this.error});
}
