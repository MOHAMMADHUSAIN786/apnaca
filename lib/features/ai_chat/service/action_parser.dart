// lib/features/ai_chat/service/action_parser.dart
//
// FIX SUMMARY:
// BUG4 — fuzzy fallback expanded; fewer "Samajh nahi aaya"
// PART3 — new action types: edit_sale_bill, edit_purchase_bill,
//         bulk_update_prices, mark_multiple_bills_paid, search_bills,
//         delete_sale_bill, delete_purchase_bill

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
    return _error('Samajh nahi aaya, dobara try karein.\nExample: "Raj ko 5 apple ka bill" ya "Apple item add karo"');
  }

  // ── 1. Clean JSON parse ─────────────────────────────────────────
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

  // ── 2. Extract any JSON block ───────────────────────────────────
  static ParsedAction? _extractAnyJson(String raw) {
    try {
      final matches =
      RegExp(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)?\}').allMatches(raw);
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

  // ── 3. Fuzzy fallback — BUG4 FIX ───────────────────────────────
  static ParsedAction? _fuzzyFallback(String raw) {
    final l = raw.toLowerCase().trim();

    // ── EDIT BILL ─────────────────────────────────────────────────
    if (_has(l, ['edit', 'badlo', 'change karo', 'update karo', 'modify'])) {
      if (_has(l, ['purchase', 'pb-'])) {
        return ParsedAction(
          type: AiActionType.editPurchaseBill,
          data: {},
          reply: 'Konsa purchase bill edit karna hai? Bill number batao (jaise: PB-2026-0001)',
        );
      }
      if (_has(l, ['sale', 'sb-', 'bill', 'invoice'])) {
        return ParsedAction(
          type: AiActionType.editSaleBill,
          data: {},
          reply: 'Konsa sale bill edit karna hai? Bill number batao (jaise: SB-2026-0001)',
        );
      }
    }

    // ── DELETE BILL ───────────────────────────────────────────────
    if (_has(l, ['delete', 'hatao', 'cancel', 'remove'])) {
      if (_has(l, ['purchase', 'pb-'])) {
        return ParsedAction(
          type: AiActionType.deletePurchaseBill,
          data: {},
          reply: 'Konsa purchase bill delete karna hai?',
        );
      }
      if (_has(l, ['sale', 'sb-', 'invoice'])) {
        return ParsedAction(
          type: AiActionType.deleteSaleBill,
          data: {},
          reply: 'Konsa sale bill delete karna hai?',
        );
      }
    }

    // ── MARK MULTIPLE PAID ────────────────────────────────────────
    if (_has(l, ['sab', 'all', 'saare']) &&
        _has(l, ['paid', 'clear', 'settle'])) {
      return ParsedAction(
        type: AiActionType.markMultipleBillsPaid,
        data: {},
        reply: 'Konse bills paid karne hain? Customer name ya "aaj ke sab" batao.',
      );
    }

    // ── BILL PAID STATUS ──────────────────────────────────────────
    if (_has(l, ['paid karna', 'paid mark', 'paid kar do', 'paid karo']) &&
        _has(l, ['purchase'])) {
      return ParsedAction(
        type: AiActionType.updatePurchaseBillStatus,
        data: {'payment_status': 'paid'},
        reply: 'Konsa purchase bill paid karna hai? Bill number batao (jaise: PB-2026-0001)',
        askField: 'bill_number',
      );
    }
    if (_has(l, ['paid karna', 'paid mark', 'paid kar do', 'paid karo']) &&
        _has(l, ['sale', 'invoice', 'bill'])) {
      return ParsedAction(
        type: AiActionType.updateSaleBillStatus,
        data: {'payment_status': 'paid'},
        reply: 'Konsa bill paid karna hai? Bill number batao (jaise: SB-2026-0001)',
        askField: 'bill_number',
      );
    }

    // ── BULK PRICE UPDATE ─────────────────────────────────────────
    if (_has(l, ['sab items', 'all items', 'sabki price', 'sab ki price']) &&
        _has(l, ['price', 'rate', 'badha', 'ghata', 'kar do'])) {
      return ParsedAction(
        type: AiActionType.bulkUpdatePrices,
        data: {},
        reply: 'Kitna change karna hai? Example: "10% badha do" ya "sab ki price 20% increase karo"',
      );
    }

    // ── SEARCH BILLS ──────────────────────────────────────────────
    if (_has(l, ['dhundo', 'search', 'find', 'karo dhundh']) &&
        _has(l, ['bill', 'invoice'])) {
      return ParsedAction(
        type: AiActionType.searchBills,
        data: {},
        reply: 'Kya dhundna hai? Amount, date, customer name, ya status batao.',
      );
    }

    // ── NO NAME GIVEN — ask directly (BUG FIX) ──────────────────────────────
    // "customer add karo", "naya customer", "customer chahiye" without any name
    if (_has(l, ['customer add', 'naya customer', 'customer banana',
      'customer chahiye', 'customer bnao', 'add customer',
      'new customer', 'customer register', 'customer banao']) &&
        !_hasName(l)) {
      return ParsedAction(
        type: AiActionType.ask,
        data: {'field': 'name'},
        reply: 'Customer ka naam kya hai?',
        askField: 'name',
      );
    }

    // "supplier add karo" — no name
    if (_has(l, ['supplier add', 'naya supplier', 'supplier banana',
      'add supplier', 'new supplier', 'supplier bnao',
      'supplier banao', 'supplier chahiye']) &&
        !_hasName(l)) {
      return ParsedAction(
        type: AiActionType.ask,
        data: {'field': 'name'},
        reply: 'Supplier ka naam kya hai?',
        askField: 'name',
      );
    }

    // "item add karo" — no name
    if (_has(l, ['item add', 'naya item', 'item banana', 'add item',
      'new item', 'item bnao', 'item create',
      'item banao', 'item chahiye']) &&
        !_hasName(l)) {
      return ParsedAction(
        type: AiActionType.ask,
        data: {'field': 'name'},
        reply: 'Item ka naam kya hai?',
        askField: 'name',
      );
    }

    // ── SALE BILL CREATION ────────────────────────────────────────
    if (_has(l, ['sale bill', 'bil banao', 'bill bana', 'invoice', 'bill banao', 'bill create', 'bill karo'])) {
      return ParsedAction(
          type: AiActionType.createSaleBill, data: {}, reply: 'Kis customer ka bill banana hai?');
    }

    // ── PURCHASE BILL CREATION ────────────────────────────────────
    if (_has(l, ['purchase bill', 'kharida', 'kharidi', 'purchase banao', 'purchase create', 'purchase karo'])) {
      return ParsedAction(
          type: AiActionType.createPurchaseBill, data: {}, reply: 'Konsa supplier aur kaunsa item?');
    }

    // ── LISTS ─────────────────────────────────────────────────────
    if (_has(l, ['item list', 'sab item', 'all item', 'items dikhao', 'show item', 'list item', 'items kya hain'])) {
      return ParsedAction(type: AiActionType.listItems, data: {}, reply: 'Yeh rahe aapke items:');
    }
    if (_has(l, ['customer list', 'sab customer', 'all customer', 'customers dikhao'])) {
      return ParsedAction(type: AiActionType.listCustomers, data: {}, reply: 'Yeh rahe aapke customers:');
    }
    if (_has(l, ['supplier list', 'sab supplier', 'all supplier', 'suppliers dikhao'])) {
      return ParsedAction(type: AiActionType.listSuppliers, data: {}, reply: 'Yeh rahe aapke suppliers:');
    }
    if (_has(l, ['bill list', 'sab bill', 'all bill', 'bills dikhao', 'sale bills'])) {
      return ParsedAction(type: AiActionType.listSaleBills, data: {}, reply: 'Yeh rahe aapke bills:');
    }
    if (_has(l, ['purchase list', 'sab purchase', 'purchase bills dikhao'])) {
      return ParsedAction(type: AiActionType.listPurchaseBills, data: {}, reply: 'Yeh rahe purchase bills:');
    }

    // ── ANALYTICS ─────────────────────────────────────────────────
    if (_has(l, ['aaj', 'today', 'sale kitna', 'sale kya', 'kitni sale', 'aaj ki sale'])) {
      return ParsedAction(type: AiActionType.getAnalytics, data: {'period': 'today'}, reply: 'Aaj ki sale:');
    }
    if (_has(l, ['is hafte', 'week', 'saat din'])) {
      return ParsedAction(type: AiActionType.getAnalytics, data: {'period': 'week'}, reply: 'Is hafte ki sale:');
    }
    if (_has(l, ['is mahine', 'month', 'mahina', 'monthly'])) {
      return ParsedAction(type: AiActionType.getAnalytics, data: {'period': 'month'}, reply: 'Is mahine ki sale:');
    }
    if (_has(l, ['profit', 'kamayi', 'munafa'])) {
      return ParsedAction(type: AiActionType.getAnalytics, data: {'period': 'profit_summary'}, reply: 'Profit summary:');
    }
    if (_has(l, ['low stock', 'kam stock', 'khatam', 'khatam hone wala'])) {
      return ParsedAction(type: AiActionType.getAnalytics, data: {'period': 'low_stock'}, reply: 'Low stock items:');
    }
    if (_has(l, ['unpaid', 'udhaar', 'baaki']) &&
        !_has(l, ['paid karna', 'paid karo', 'paid mark'])) {
      return ParsedAction(type: AiActionType.getAnalytics, data: {'period': 'unpaid'}, reply: 'Unpaid bills:');
    }
    if (_has(l, ['top item', 'best selling', 'jyada bika', 'sabse jyada'])) {
      return ParsedAction(type: AiActionType.getAnalytics, data: {'period': 'top_items'}, reply: 'Top selling items:');
    }
    if (_has(l, ['top customer', 'sabse jyada kharida', 'best customer'])) {
      return ParsedAction(type: AiActionType.getAnalytics, data: {'period': 'top_customers'}, reply: 'Top customers:');
    }
    if (_has(l, ['inventory', 'stock value', 'total stock', 'stock kitna'])) {
      return ParsedAction(type: AiActionType.getAnalytics, data: {'period': 'inventory_value'}, reply: 'Inventory:');
    }
    if (_has(l, ['business summary', 'business ka', 'overall', 'sab dikhao'])) {
      return ParsedAction(type: AiActionType.getAnalytics, data: {'period': 'business_summary'}, reply: 'Business summary:');
    }

    return null;
  }

  static bool _has(String text, List<String> kws) => kws.any(text.contains);

  // Returns true if message has a capitalized word (likely a name)
  // Used to differentiate "customer add karo" vs "Rohit customer add karo"
  static bool _hasName(String lowerText) {
    // Check original case via simple heuristic:
    // if there's a word that doesn't match common action words, assume name present
    const actionWords = {
      'customer', 'supplier', 'item', 'add', 'karo', 'naya', 'banana',
      'chahiye', 'banao', 'create', 'register', 'new', 'ek', 'bnao',
      'bill', 'sale', 'purchase', 'me', 'mera', 'meri', 'hai', 'hain',
    };
    final words = lowerText.trim().split(RegExp(r'\s+'));
    final nonActionWords = words.where((w) =>
    w.length > 2 && !actionWords.contains(w)).toList();
    return nonActionWords.isNotEmpty;
  }

  // ── Build ParsedAction from JSON map ───────────────────────────
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
      askField: type == AiActionType.ask
          ? (json['field'] as String? ?? json['askField'] as String?)
          : null,
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
      case 'bulk_update_prices':          return AiActionType.bulkUpdatePrices;
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
      case 'edit_sale_bill':              return AiActionType.editSaleBill;
      case 'delete_sale_bill':            return AiActionType.deleteSaleBill;
      case 'mark_multiple_bills_paid':    return AiActionType.markMultipleBillsPaid;
      case 'search_bills':                return AiActionType.searchBills;
      case 'create_purchase_bill':        return AiActionType.createPurchaseBill;
      case 'list_purchase_bills':         return AiActionType.listPurchaseBills;
      case 'show_purchase_bill_detail':   return AiActionType.showPurchaseBillDetail;
      case 'update_purchase_bill_status': return AiActionType.updatePurchaseBillStatus;
      case 'edit_purchase_bill':          return AiActionType.editPurchaseBill;
      case 'delete_purchase_bill':        return AiActionType.deletePurchaseBill;
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