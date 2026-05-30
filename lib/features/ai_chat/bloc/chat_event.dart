import 'dart:io';

abstract class ChatEvent {}

class SendMessageEvent extends ChatEvent {
  final String message;
  SendMessageEvent(this.message);
}

class ClearChatEvent extends ChatEvent {}

/// Fired when user picks an image for logo or signature during bill branding flow.
class BrandingImageUploadedEvent extends ChatEvent {
  final File imageFile;
  /// 'logo' or 'signature'
  final String imageType;
  BrandingImageUploadedEvent({required this.imageFile, required this.imageType});
}
