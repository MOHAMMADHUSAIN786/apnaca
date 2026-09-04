import 'dart:io';

import '../model/chat_models.dart';

abstract class ChatEvent {}

class SendMessageEvent extends ChatEvent {
  final String message;
  SendMessageEvent(this.message);
}

class ClearChatEvent extends ChatEvent {}

/// User tapped Yes/No on a destructive AI action proposed by the gateway.
class ConfirmAiActionsEvent extends ChatEvent {
  final List<PendingAiAction> actions;
  final String? conversationId;
  final bool approved;
  ConfirmAiActionsEvent({
    required this.actions,
    required this.conversationId,
    required this.approved,
  });
}

/// Fired when user picks an image for logo or signature during bill branding flow.
class BrandingImageUploadedEvent extends ChatEvent {
  final File imageFile;
  /// 'logo' or 'signature'
  final String imageType;
  BrandingImageUploadedEvent({required this.imageFile, required this.imageType});
}
