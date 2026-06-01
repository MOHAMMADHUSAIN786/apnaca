// lib/features/ai_chat/service/bill_flow_manager.dart
//
// FIXES:
// • BUG C: Duplicate items in purchase bill — parseItems deduplicates
// • Better qty/price parsing: "10 100", "10 qty", "₹100", "@100"
// • Payment: "cash kar do", "udhaar pe" all handled
// • Item parsing: comma, "aur", "or", "+", newline separators
//
import '../model/bill_creation_state.dart';

class BillFlowManager {

  // ─────────────────────────────────────────────────────────────────
  //  YES / NO
  // ─────────────────────────────────────────────────────────────────
  static bool isYes(String msg) {
    final l = _c(msg);
    const yes = ['haa', 'haan', 'han', 'yes', 'bilkul', 'zaroor', 'chahiye',
      'dena hai', 'lagao', 'sure', 'ok', 'okay', 'theek', 'done', 'correct', 'sahi', 'kar do'];
    return yes.any(l.contains) || l == 'ha' || l == 'haa' || l == 'yes';
  }

  static bool isNo(String msg) {
    final l = _c(msg);
    const no = ['nahi', 'nai', 'na ', ' na', 'no ', ' no', 'mat', 'skip', 'chhod',
      'nope', 'bina', 'without', 'nhi', '0 discount', 'zero discount'];
    return no.any(l.contains) || l == 'na' || l == 'no' || l == 'nahi' || l == 'nai' || l == 'nhi';
  }

  // ─────────────────────────────────────────────────────────────────
  //  QTY PARSER
  //  Accepts: "10", "10 qty", "qty 10", "10 piece", "dus", "ten"
  // ─────────────────────────────────────────────────────────────────
  static int? parseQty(String msg) {
    final l = _c(msg);
    // Don't parse if price keywords present and no qty keyword
    if (RegExp(r'₹|rs\.?\s*\d|\bprice\b|\brate\b').hasMatch(l) &&
        !RegExp(r'\b(qty|quantity|piece|pcs|units?|no\.?)\b').hasMatch(l)) {
      return null;
    }
    // Word numbers
    const wm = {'ek':1,'do':2,'teen':3,'char':4,'paanch':5,'chhe':6,'saath':7,
      'aath':8,'nau':9,'das':10,'bees':20,'tees':30,'chalis':40,'pachaas':50,'sau':100,
      'one':1,'two':2,'three':3,'four':4,'five':5,'six':6,'seven':7,'eight':8,
      'nine':9,'ten':10,'twenty':20,'fifty':50,'hundred':100};
    for (final e in wm.entries) {
      if (RegExp(r'\b' + e.key + r'\b').hasMatch(l)) return e.value;
    }
    // Strip qty-noise then extract number
    final stripped = l.replaceAll(
        RegExp(r'\b(qty|quantity|piece|pieces|pcs|units?|no\.?|number)\b'), '').trim();
    if (RegExp(r'₹|rs\.?\s*\d|\bprice\b').hasMatch(stripped)) return null;
    final m = RegExp(r'\b(\d+)\b').firstMatch(stripped);
    return m != null ? int.tryParse(m.group(1)!) : null;
  }

  // ─────────────────────────────────────────────────────────────────
  //  PRICE PARSER
  //  Accepts: "100", "₹100", "rs100", "price 100", "@100", "100/-"
  // ─────────────────────────────────────────────────────────────────
  static double? parsePrice(String msg) {
    final l = _c(msg);
    if (RegExp(r'^\d+\s*(qty|piece|pcs|units?|number|no\.?)$').hasMatch(l.trim())) return null;
    final patterns = [
      RegExp(r'(?:₹|rs\.?\s*|inr\s*)(\d+(?:\.\d+)?)', caseSensitive: false),
      RegExp(r'(?:price|rate|at|@)\s*(\d+(?:\.\d+)?)', caseSensitive: false),
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:rs\.?|rupees?|/-)', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(l);
      if (m != null) {
        final v = double.tryParse(m.group(1)!);
        if (v != null && v > 0) return v;
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────
  //  QTY+PRICE COMBINED — "10 100" = qty:10 price:100
  // ─────────────────────────────────────────────────────────────────
  static Map<String, dynamic>? parseQtyAndPrice(String msg) {
    final l = _c(msg);
    // "qty:10 price:100"
    final eqQ = RegExp(r'qty\s*[=:]\s*(\d+)', caseSensitive: false).firstMatch(l);
    final eqP = RegExp(r'price\s*[=:]\s*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(l);
    if (eqQ != null && eqP != null) {
      return {'qty': int.parse(eqQ.group(1)!), 'price': double.parse(eqP.group(1)!)};
    }
    // Tagged qty + tagged price
    final tQ = RegExp(r'(\d+)\s*(qty|quantity|piece|pcs|units?)', caseSensitive: false).firstMatch(l);
    final tP = RegExp(r'(?:₹|rs\.?\s*|price\s*|rate\s*|@)(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(l);
    if (tQ != null && tP != null) {
      return {'qty': int.parse(tQ.group(1)!), 'price': double.parse(tP.group(1)!)};
    }
    // "10 100" — two bare numbers → first=qty, second=price
    final two = RegExp(r'^(\d+)\s+(\d+(?:\.\d+)?)$').firstMatch(l.trim());
    if (two != null) {
      return {'qty': int.parse(two.group(1)!), 'price': double.parse(two.group(2)!)};
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────
  //  DISCOUNT
  // ─────────────────────────────────────────────────────────────────
  static Map<String, dynamic>? parseDiscount(String msg) {
    final l = _c(msg);
    if (isNo(l) || l.contains('no discount') || l.contains('discount nahi') ||
        l.contains('bina discount') || l.contains('discount mat') ||
        l.contains('without discount') || l.contains('0 discount') || l.contains('zero discount')) {
      return {'type': 'none', 'value': 0.0};
    }
    final pct = RegExp(r'(\d+(?:\.\d+)?)\s*(?:%|percent|feesad)').firstMatch(l);
    if (pct != null) return {'type': 'percent', 'value': double.parse(pct.group(1)!)};
    final amt = RegExp(r'(?:₹|rs\.?|rupees?)?\s*(\d+(?:\.\d+)?)\s*(?:rs\.?|rupees?|₹|off|discount)?').firstMatch(l);
    if (amt != null && l.contains(RegExp(r'\d'))) {
      final v = double.tryParse(amt.group(1) ?? '');
      if (v != null && v > 0) return {'type': 'amount', 'value': v};
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────
  //  TAX
  // ─────────────────────────────────────────────────────────────────
  static Map<String, dynamic>? parseTax(String msg) {
    final l = _c(msg);
    if (l == 'no' || l == 'nahi' || l == 'na' || l == 'nai' || l == 'nhi' ||
        l.contains('no tax') || l.contains('tax nahi') || l.contains('bina tax') ||
        l.contains('without tax') || l.contains('0%') || l.contains('zero tax') ||
        l.contains('no gst') || l.contains('gst nahi') || l.contains('tax nhi')) {
      return {'type': 'exclusive', 'rate': 0.0};
    }
    final isInclusive = l.contains('inclusive') || l.contains('andar') || l.contains('shamil');
    final taxType = isInclusive ? 'inclusive' : 'exclusive';
    final rateMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:%|percent|gst)').firstMatch(l);
    if (rateMatch != null) return {'type': taxType, 'rate': double.parse(rateMatch.group(1)!)};
    // Solo number in tax step
    final solo = RegExp(r'^\s*(\d+(?:\.\d+)?)\s*$').firstMatch(l);
    if (solo != null) return {'type': taxType, 'rate': double.parse(solo.group(1)!)};
    return null;
  }

  // ─────────────────────────────────────────────────────────────────
  //  PAYMENT — all variants including "cash kar do", "udhaar pe"
  // ─────────────────────────────────────────────────────────────────
  static Map<String, String>? parsePayment(String msg) {
    final l = _c(msg);
    if (l.contains('udhaar') || l.contains('udhar') || l.contains('baad mein') ||
        l.contains('badme') || l.contains('later') || l.contains('credit') ||
        l.contains('udhaar pe') || l.contains('baad me') || l.contains('abhi nahi')) {
      return {'mode': 'udhar', 'status': 'unpaid'};
    }
    if (l.contains('cheque') || l.contains('chek') || l.contains('check')) {
      return {'mode': 'cheque', 'status': 'unpaid'};
    }
    if (l.contains('partial') || l.contains('kuch diya') || l.contains('thoda') || l.contains('half')) {
      return {'mode': 'cash', 'status': 'partial'};
    }
    if (l.contains('upi') || l.contains('gpay') || l.contains('googlepay') ||
        l.contains('phonepe') || l.contains('paytm') || l.contains('online') ||
        l.contains('neft') || l.contains('imps') || l.contains('g pay') || l.contains('phone pe')) {
      return {'mode': 'upi', 'status': l.contains('unpaid') || l.contains('pending') ? 'unpaid' : 'paid'};
    }
    // "cash kar do", "cash karo", "nakad", "nakit"
    if (l.contains('cash') || l.contains('nakit') || l.contains('nakad') ||
        l.contains('note') || l.contains('haath mein')) {
      return {'mode': 'cash', 'status': l.contains('unpaid') || l.contains('pending') ? 'unpaid' : 'paid'};
    }
    if (l.contains('paid') || l.contains('ho gaya') || l.contains('de diya')) {
      return {'mode': 'cash', 'status': 'paid'};
    }
    if (l.contains('unpaid') || l.contains('pending') || l.contains('baaki')) {
      return {'mode': 'cash', 'status': 'unpaid'};
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────
  //  NEXT QUESTION
  // ─────────────────────────────────────────────────────────────────
  static String? nextQuestion(BillCreationState state) {
    switch (state.step) {
      case BillStep.collectingItems:
        return 'Kaunsa item aur kitni quantity?\nExample: "apple 5, mango 10"';
      case BillStep.askingDiscount:
        return 'Koi discount dena hai? (haan / nahi)';
      case BillStep.collectingDiscount:
        return 'Kitna discount? Example: "10%" ya "₹50"';
      case BillStep.askingTax:
        return _taxQ();
      case BillStep.askingPayment:
        return _payQ();
      case BillStep.askingBranding:
        return _brandQ();
      case BillStep.collectingLogo:
        return '📎 Company logo ki photo bhejein:';
      case BillStep.collectingSignature:
        return '📎 Signature ki photo bhejein:\n(Skip: "nahi" bolein)';
      case BillStep.idle:
      case BillStep.ready:
        return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  PROCESS REPLY — main state machine
  // ─────────────────────────────────────────────────────────────────
  static (BillCreationState, String?) processReply({
    required String userMessage,
    required BillCreationState state,
  }) {
    switch (state.step) {

      case BillStep.collectingItems:
        final parsed = _parseItems(userMessage);
        if (parsed.isEmpty) {
          return (state, 'Samajh nahi aaya.\nExample: "apple 5" ya "5 apple, 3 mango"');
        }
        return (state.copyWith(items: parsed, step: BillStep.askingDiscount),
        'Koi discount dena hai? (haan / nahi)');

      case BillStep.askingDiscount:
        final disc = parseDiscount(userMessage);
        if (disc != null) {
          return (state.copyWith(discountType: disc['type'] as String,
              discountValue: disc['value'] as double, step: BillStep.askingTax), _taxQ());
        }
        if (isYes(userMessage)) {
          return (state.copyWith(step: BillStep.collectingDiscount),
          'Kitna discount?\nExample: "10%" ya "₹50 off"');
        }
        if (isNo(userMessage)) {
          return (state.copyWith(discountType: 'none', discountValue: 0.0,
              step: BillStep.askingTax), _taxQ());
        }
        return (state, 'Discount dena hai? "haan" ya "nahi" bolein.');

      case BillStep.collectingDiscount:
        final disc2 = parseDiscount(userMessage);
        if (disc2 == null) return (state, 'Discount samajh nahi aaya.\nExample: "10%" ya "₹50"');
        return (state.copyWith(discountType: disc2['type'] as String,
            discountValue: disc2['value'] as double, step: BillStep.askingTax), _taxQ());

      case BillStep.askingTax:
        final tax = parseTax(userMessage);
        if (tax == null) return (state, 'Tax samajh nahi aaya.\n"exclusive 18%" ya "no tax"');
        return (state.copyWith(taxType: tax['type'] as String,
            taxRate: tax['rate'] as double, step: BillStep.askingPayment), _payQ());

      case BillStep.askingPayment:
        final pay = parsePayment(userMessage);
        if (pay == null) return (state, 'Payment samajh nahi aaya.\nCash / UPI / Udhaar?');
        return (state.copyWith(paymentMode: pay['mode'],
            paymentStatus: pay['status'], step: BillStep.askingBranding), null);

      case BillStep.askingBranding:
        if (isNo(userMessage)) return (state.copyWith(brandingSkipped: true, step: BillStep.ready), null);
        if (isYes(userMessage)) return (state.copyWith(step: BillStep.collectingLogo),
        '📎 Company logo ki photo bhejein:');
        return (state, _brandQ());

      case BillStep.collectingLogo:
      case BillStep.collectingSignature:
        final skip = isNo(userMessage) || userMessage.toLowerCase().contains('skip') ||
            userMessage.toLowerCase().contains('nahi') || userMessage.toLowerCase().contains('nhi');
        if (skip) {
          if (state.step == BillStep.collectingLogo) {
            return (state.copyWith(companyLogoUrl: '', step: BillStep.collectingSignature),
            '📎 Signature ki photo bhejein:\n(Skip: "nahi" bolein)');
          } else {
            return (state.copyWith(signatureUrl: '', step: BillStep.ready), null);
          }
        }
        return (state, state.step == BillStep.collectingLogo
            ? '📎 Logo bhejein ya "nahi" bolein.'
            : '📎 Signature bhejein ya "nahi" bolein.');

      case BillStep.idle:
      case BillStep.ready:
        return (state, null);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  ITEM PARSING — deduplicates (BUG C FIX)
  //  Separators: comma, "aur", "or", "and", "+", newline
  // ─────────────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> _parseItems(String msg) {
    final normalized = msg
        .replaceAll(RegExp(r'\baur\b|\bor\b|\band\b', caseSensitive: false), ',')
        .replaceAll(RegExp(r'[+;\n\r]+'), ',');

    final parts = normalized.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    final seen = <String>{};
    final items = <Map<String, dynamic>>[];

    for (final part in parts) {
      final item = _parseSingle(part);
      if (item != null) {
        final nameLower = (item['name'] as String).toLowerCase();
        if (!seen.contains(nameLower)) {       // BUG C FIX — deduplicate
          seen.add(nameLower);
          items.add(item);
        }
      }
    }

    if (items.isEmpty) {
      final single = _parseSingle(msg.trim());
      if (single != null) items.add(single);
    }
    return items;
  }

  static Map<String, dynamic>? _parseSingle(String part) {
    final cleaned = part.replaceAll(
        RegExp(r'\b(qty|quantity|piece|pieces|pcs|units?|no\.?|number)\b',
            caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleaned.isEmpty) return null;

    // "5 apple"
    final qF = RegExp(r'^(\d+)\s+(.+)$').firstMatch(cleaned);
    if (qF != null) {
      final qty = int.tryParse(qF.group(1)!);
      final name = qF.group(2)!.trim();
      if (qty != null && qty > 0 && name.isNotEmpty) return _item(name, qty);
    }
    // "apple 5"
    final nF = RegExp(r'^(.+?)\s+(\d+)$').firstMatch(cleaned);
    if (nF != null) {
      final name = nF.group(1)!.trim();
      final qty = int.tryParse(nF.group(2)!);
      if (qty != null && qty > 0 && name.isNotEmpty) return _item(name, qty);
    }
    // Only text (default qty=1)
    if (RegExp(r'^[a-zA-Z\u0900-\u097F ]+$').hasMatch(cleaned) && cleaned.length > 1) {
      return _item(cleaned, 1);
    }
    return null;
  }

  static Map<String, dynamic> _item(String name, int qty) => {
    'name': name, 'qty': qty, 'price': null, 'tax_rate': 0.0, 'discount_per_item': 0.0,
  };

  static String _taxQ() =>
      'Tax inclusive hai ya exclusive?\n'
          '• Exclusive = tax price ke upar add hoga (common)\n'
          '• Inclusive = tax price mein pehle se hai\n'
          'GST % batao. Jaise: "exclusive 18%" ya "no tax"';

  static String _payQ() =>
      'Payment kaise?\n• Cash\n• UPI / GPay / PhonePe\n• Udhaar\n• Cheque';

  static String _brandQ() =>
      '🏢 Bill mein company logo aur signature add karna hai?\n'
          '(Ek baar upload, hamesha automatically lagega)\n\n'
          '• "Haan" — upload karein\n• "Nahi" — skip karein';

  static String _c(String msg) => msg.toLowerCase().trim();
}