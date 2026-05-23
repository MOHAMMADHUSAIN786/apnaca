import 'dart:convert';
import '../model/chat_models.dart';

class ActionParser {
  static ParsedAction parse(String rawResponse) {
    try {
      String cleaned = rawResponse.trim()
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) {
        return _fallback('JSON nahi mila response mein.');
      }
      cleaned = cleaned.substring(start, end + 1);

      final Map<String, dynamic> json = jsonDecode(cleaned);
      final actionStr = (json['action'] as String? ?? '').toLowerCase().trim();
      final data = (json['data'] as Map<String, dynamic>?) ?? {};
      final reply = (json['reply'] as String?) ?? 'Processing...';
      final type = _parseType(actionStr);

      return ParsedAction(
        type: type,
        data: data,
        reply: reply,
        askField: type == AiActionType.ask ? (json['field'] as String?) : null,
      );
    } catch (_) {
      return _fallback('Response parse nahi hua. Dobara try karein.');
    }
  }

  static AiActionType _parseType(String s) {
    switch (s) {
      // Items
      case 'create_item':         return AiActionType.createItem;
      case 'update_item':         return AiActionType.updateItem;
      case 'delete_item':         return AiActionType.deleteItem;
      case 'list_items':          return AiActionType.listItems;
      case 'show_item_detail':    return AiActionType.showItemDetail;
      // Customers
      case 'create_customer':     return AiActionType.createCustomer;
      case 'update_customer':     return AiActionType.updateCustomer;
      case 'delete_customer':     return AiActionType.deleteCustomer;
      case 'list_customers':      return AiActionType.listCustomers;
      case 'show_customer_detail':return AiActionType.showCustomerDetail;
      // Flow
      case 'ask':                 return AiActionType.ask;
      case 'confirm':             return AiActionType.confirm;
      case 'clarify':             return AiActionType.clarify;
      default:                    return AiActionType.error;
    }
  }

  static ParsedAction _fallback(String msg) => ParsedAction(
        type: AiActionType.error,
        data: {},
        reply: msg,
      );
}
