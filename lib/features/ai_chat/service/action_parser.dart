import 'dart:convert';
import '../model/chat_models.dart';

class ActionParser {
  static ParsedAction parse(String rawResponse) {
    final r1 = _tryParse(rawResponse);
    if (r1 != null) return r1;
    final r2 = _extractAnyJson(rawResponse);
    if (r2 != null) return r2;
    final r3 = _fuzzyFallback(rawResponse);
    if (r3 != null) return r3;
    return _error('Samajh nahi aaya, dobara try karein.');
  }

  static ParsedAction? _tryParse(String raw) {
    try {
      String s = raw
          .trim()
          .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      final start = s.indexOf('{');
      final end = s.lastIndexOf('}');
      if (start == -1 || end <= start) return null;
      return _build(jsonDecode(s.substring(start, end + 1)));
    } catch (_) {
      return null;
    }
  }

  static ParsedAction? _extractAnyJson(String raw) {
    try {
      final matches = RegExp(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)?\}').allMatches(raw);
      for (final m in matches) {
        try {
          final json = jsonDecode(m.group(0)!);
          if (json is Map<String, dynamic> && json.containsKey('action')) {
            return _build(json);
          }
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  static ParsedAction? _fuzzyFallback(String raw) {
    final l = raw.toLowerCase();
    if (_has(l, ['sale bill', 'bil banao', 'bill bana', 'invoice', 'bill banao', 'bill create'])) {
      return ParsedAction(type: AiActionType.createSaleBill, data: {}, reply: 'Kis customer ka bill banana hai?');
    }
    if (_has(l, ['purchase bill', 'kharida', 'kharidi', 'purchase banao', 'purchase create'])) {
      return ParsedAction(type: AiActionType.createPurchaseBill, data: {}, reply: 'Konsa supplier aur kaunsa item?');
    }
    if (_has(l, ['item list', 'sab item', 'all item', 'items dikhao', 'show item', 'list item'])) {
      return ParsedAction(type: AiActionType.listItems, data: {}, reply: 'Yeh rahe aapke items:');
    }
    if (_has(l, ['customer list', 'sab customer', 'all customer'])) {
      return ParsedAction(type: AiActionType.listCustomers, data: {}, reply: 'Yeh rahe aapke customers:');
    }
    if (_has(l, ['supplier list', 'sab supplier', 'all supplier'])) {
      return ParsedAction(type: AiActionType.listSuppliers, data: {}, reply: 'Yeh rahe aapke suppliers:');
    }
    if (_has(l, ['bill list', 'sab bill', 'all bill', 'bills dikhao'])) {
      return ParsedAction(type: AiActionType.listSaleBills, data: {}, reply: 'Yeh rahe aapke bills:');
    }
    if (_has(l, ['purchase list', 'sab purchase', 'purchase bills dikhao'])) {
      return ParsedAction(type: AiActionType.listPurchaseBills, data: {}, reply: 'Yeh rahe purchase bills:');
    }
    if (_has(l, ['aaj', 'today', 'sale kitna', 'sale kya', 'kitni sale'])) {
      return ParsedAction(type: AiActionType.getAnalytics, data: {'period': 'today'}, reply: 'Aaj ki sale:');
    }
    if (_has(l, ['low stock', 'kam stock', 'khatam'])) {
      return ParsedAction(type: AiActionType.getAnalytics, data: {'period': 'low_stock'}, reply: 'Low stock items:');
    }
    if (_has(l, ['unpaid', 'udhaar', 'baaki'])) {
      return ParsedAction(type: AiActionType.getAnalytics, data: {'period': 'unpaid'}, reply: 'Unpaid bills:');
    }
    if (_has(l, ['top item', 'best selling', 'jyada bika'])) {
      return ParsedAction(type: AiActionType.getAnalytics, data: {'period': 'top_items'}, reply: 'Top selling items:');
    }
    return null;
  }

  static bool _has(String text, List<String> kws) => kws.any(text.contains);

  static ParsedAction _build(Map<String, dynamic> json) {
    final action = (json['action'] as String? ?? '').toLowerCase().trim();
    final raw = json['data'];
    final data = raw is Map<String, dynamic>
        ? raw
        : (raw == null ? <String, dynamic>{} : <String, dynamic>{});
    final reply = (json['reply'] as String?) ?? '...';
    final type = _type(action);
    return ParsedAction(
      type: type,
      data: data,
      reply: reply,
      askField: type == AiActionType.ask ? (json['field'] as String?) : null,
    );
  }

  static AiActionType _type(String s) {
    switch (s) {
      case 'create_item':                 return AiActionType.createItem;
      case 'update_item':                 return AiActionType.updateItem;
      case 'delete_item':                 return AiActionType.deleteItem;
      case 'list_items':                  return AiActionType.listItems;
      case 'show_item_detail':            return AiActionType.showItemDetail;
      case 'show_item_transactions':      return AiActionType.showItemTransactions;
      case 'create_customer':             return AiActionType.createCustomer;
      case 'update_customer':             return AiActionType.updateCustomer;
      case 'delete_customer':             return AiActionType.deleteCustomer;
      case 'list_customers':              return AiActionType.listCustomers;
      case 'show_customer_detail':        return AiActionType.showCustomerDetail;
      case 'create_supplier':             return AiActionType.createSupplier;
      case 'update_supplier':             return AiActionType.updateSupplier;
      case 'delete_supplier':             return AiActionType.deleteSupplier;
      case 'list_suppliers':              return AiActionType.listSuppliers;
      case 'show_supplier_detail':        return AiActionType.showSupplierDetail;
      case 'create_sale_bill':            return AiActionType.createSaleBill;
      case 'list_sale_bills':             return AiActionType.listSaleBills;
      case 'show_sale_bill_detail':       return AiActionType.showSaleBillDetail;
      case 'update_sale_bill_status':     return AiActionType.updateSaleBillStatus;
      case 'create_purchase_bill':        return AiActionType.createPurchaseBill;
      case 'list_purchase_bills':         return AiActionType.listPurchaseBills;
      case 'show_purchase_bill_detail':   return AiActionType.showPurchaseBillDetail;
      case 'update_purchase_bill_status': return AiActionType.updatePurchaseBillStatus;
      case 'get_analytics':               return AiActionType.getAnalytics;
      case 'ask':                         return AiActionType.ask;
      case 'confirm':                     return AiActionType.confirm;
      case 'clarify':                     return AiActionType.clarify;
      default:                            return AiActionType.error;
    }
  }

  static ParsedAction _error(String msg) =>
      ParsedAction(type: AiActionType.error, data: {}, reply: msg);
}
