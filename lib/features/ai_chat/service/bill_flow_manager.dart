import '../model/bill_creation_state.dart';

/// Pure Dart state machine for multi-turn bill creation.
/// Handles user responses like "haa", "10%", "cash" without LLM.
/// LLM is only called for the FIRST message to extract customer + items.
class BillFlowManager {

  // ────────────────────────────────────────────────────────
  //  YES / NO detection
  // ────────────────────────────────────────────────────────
  static bool isYes(String msg) {
    final l = _clean(msg);
    const yesWords = [
      'haa', 'haan', 'han', 'ha ', ' ha', 'yes', 'bilkul', 'zaroor',
      'chahiye', 'dena hai', 'lagao', 'add karo', 'sure', 'ok',
      'okay', 'theek hai', 'theek', 'done', 'correct', 'sahi'
    ];
    return yesWords.any(l.contains) || l.trim() == 'ha' || l.trim() == 'haa';
  }

  static bool isNo(String msg) {
    final l = _clean(msg);
    const noWords = [
      'nahi', 'nai', 'na ', ' na', 'no ', ' no', 'mat', 'skip',
      'chhod', 'rehne do', 'nope', 'not', 'without', 'bina',
      'zero discount', '0 discount', 'koi nahi'
    ];
    return noWords.any(l.contains) || l.trim() == 'na' || l.trim() == 'no';
  }

  // ────────────────────────────────────────────────────────
  //  DISCOUNT parsing
  // ────────────────────────────────────────────────────────
  static Map<String, dynamic>? parseDiscount(String msg) {
    final l = _clean(msg);

    // Percent: "10%", "10 percent", "10 feesad", "das percent"
    final pct = RegExp(r'(\d+(?:\.\d+)?)\s*(?:%|percent|feesad|pratishat)')
        .firstMatch(l);
    if (pct != null) {
      return {'type': 'percent', 'value': double.parse(pct.group(1)!)};
    }

    // Amount: "50 rupees", "₹100", "100 rs", "100 ka"
    final amt = RegExp(
        r'(?:rs\.?|rupees?|₹|inr)?\s*(\d+(?:\.\d+)?)\s*(?:rs\.?|rupees?|₹|off|ka|discount)?')
        .firstMatch(l);
    if (amt != null && l.contains(RegExp(r'\d'))) {
      final val = double.tryParse(amt.group(1) ?? '');
      if (val != null && val > 0) {
        return {'type': 'amount', 'value': val};
      }
    }
    return null;
  }

  // ────────────────────────────────────────────────────────
  //  TAX parsing
  // ────────────────────────────────────────────────────────
  static Map<String, dynamic>? parseTax(String msg) {
    final l = _clean(msg);

    // No tax
    if (l.contains('no tax') || l.contains('tax nahi') ||
        l.contains('koi tax') || l.contains('bina tax') ||
        l.contains('without tax') || l.contains('0%') ||
        l.contains('zero tax') || l.contains('0 percent')) {
      return {'type': 'exclusive', 'rate': 0.0};
    }

    final isInclusive = l.contains('inclusive') || l.contains('andar') ||
        l.contains('shamil') || l.contains('included') || l.contains('sath');
    final taxType = isInclusive ? 'inclusive' : 'exclusive';

    // Extract rate
    final rateMatch =
    RegExp(r'(\d+(?:\.\d+)?)\s*(?:%|percent|gst)').firstMatch(l);
    final rate =
    rateMatch != null ? double.parse(rateMatch.group(1)!) : 0.0;

    return {'type': taxType, 'rate': rate};
  }

  // ────────────────────────────────────────────────────────
  //  PAYMENT parsing
  // ────────────────────────────────────────────────────────
  static Map<String, String>? parsePayment(String msg) {
    final l = _clean(msg);

    if (l.contains('udhaar') || l.contains('credit') ||
        l.contains('baad mein') || l.contains('udhar') ||
        l.contains('badme') || l.contains('later')) {
      return {'mode': 'credit', 'status': 'unpaid'};
    }
    if (l.contains('cheque') || l.contains('chek')) {
      return {'mode': 'cheque', 'status': 'unpaid'};
    }
    if (l.contains('partial') || l.contains('kuch diya') ||
        l.contains('thoda') || l.contains('half')) {
      return {'mode': 'cash', 'status': 'partial'};
    }
    if (l.contains('upi') || l.contains('gpay') || l.contains('googlepay') ||
        l.contains('phonepe') || l.contains('paytm') ||
        l.contains('online') || l.contains('neft') ||
        l.contains('imps') || l.contains('transfer')) {
      final status = l.contains('unpaid') || l.contains('pending')
          ? 'unpaid'
          : 'paid';
      return {'mode': 'upi', 'status': status};
    }
    if (l.contains('cash') || l.contains('nakit') || l.contains('nakad') ||
        l.contains('note') || l.contains('haath mein')) {
      final status = l.contains('unpaid') || l.contains('pending')
          ? 'unpaid'
          : 'paid';
      return {'mode': 'cash', 'status': status};
    }
    if (l.contains('paid') || l.contains('ho gaya') ||
        l.contains('de diya') || l.contains('mil gaya')) {
      return {'mode': 'cash', 'status': 'paid'};
    }
    if (l.contains('unpaid') || l.contains('pending') ||
        l.contains('abhi nahi') || l.contains('baaki')) {
      return {'mode': 'cash', 'status': 'unpaid'};
    }
    return null;
  }

  // ────────────────────────────────────────────────────────
  //  Get next question for current step (used by chat_bloc)
  // ────────────────────────────────────────────────────────
  static String? nextQuestion(BillCreationState state) {
    switch (state.step) {
      case BillStep.collectingItems:
        return 'Kaunsa item aur kitni quantity?\nExample: "apple 5, mango 10"';
      case BillStep.askingDiscount:
        return 'Koi discount dena hai? (haan / nahi)';
      case BillStep.collectingDiscount:
        return 'Kitna discount? Example: "10%" ya "₹50"';
      case BillStep.askingTax:
        return _taxQuestion();
      case BillStep.askingPayment:
        return _paymentQuestion();
      case BillStep.idle:
      case BillStep.ready:
        return null;
    }
  }

  // ────────────────────────────────────────────────────────
  //  MAIN: process user reply given current bill step
  //  Returns (newState, questionToAsk)
  //  questionToAsk == null means state was not handled (send to LLM)
  // ────────────────────────────────────────────────────────
  static (BillCreationState, String?) processReply({
    required String userMessage,
    required BillCreationState state,
  }) {
    switch (state.step) {

    // ── Collecting items ──────────────────────────────────
      case BillStep.collectingItems:
      // Parse items from message
        final parsed = _parseItems(userMessage);
        if (parsed.isEmpty) {
          return (state, 'Kaunsa item aur kitni quantity?\nExample: "apple 5, mango 10" ya "5 apple aur 10 mango"');
        }
        final next = state.copyWith(items: parsed, step: BillStep.askingDiscount);
        return (next, 'Koi discount dena hai? (haan / nahi)');

    // ── Asking discount yes/no ────────────────────────────
      case BillStep.askingDiscount:
      // User might give discount value directly: "10%"
        final disc = parseDiscount(userMessage);
        if (disc != null) {
          final next = state.copyWith(
            discountType: disc['type'] as String,
            discountValue: disc['value'] as double,
            step: BillStep.askingTax,
          );
          return (next, _taxQuestion());
        }
        if (isNo(userMessage)) {
          final next = state.copyWith(
            discountType: 'none',
            discountValue: 0.0,
            step: BillStep.askingTax,
          );
          return (next, _taxQuestion());
        }
        if (isYes(userMessage)) {
          final next = state.copyWith(step: BillStep.collectingDiscount);
          return (next, 'Kitna discount?\nExample: "10%" ya "₹50 off"');
        }
        return (state, 'Discount dena hai? Sirf "haan" ya "nahi" bolein.');

    // ── Collecting discount value ─────────────────────────
      case BillStep.collectingDiscount:
        final disc = parseDiscount(userMessage);
        if (disc == null) {
          return (state, 'Discount samajh nahi aaya.\nExample: "10%" ya "₹50"');
        }
        final next = state.copyWith(
          discountType: disc['type'] as String,
          discountValue: disc['value'] as double,
          step: BillStep.askingTax,
        );
        return (next, _taxQuestion());

    // ── Asking tax ────────────────────────────────────────
      case BillStep.askingTax:
        final tax = parseTax(userMessage);
        if (tax == null) {
          return (state, 'Tax type samajh nahi aaya.\nBolein: "exclusive 18%" ya "inclusive 5%" ya "no tax"');
        }
        final next = state.copyWith(
          taxType: tax['type'] as String,
          taxRate: tax['rate'] as double,
          step: BillStep.askingPayment,
        );
        return (next, _paymentQuestion());

    // ── Asking payment ────────────────────────────────────
      case BillStep.askingPayment:
        final payment = parsePayment(userMessage);
        if (payment == null) {
          return (state, 'Payment samajh nahi aaya.\nBolein: Cash / UPI / GPay / Udhaar / Cheque');
        }
        final next = state.copyWith(
          paymentMode: payment['mode'],
          paymentStatus: payment['status'],
          step: BillStep.ready,
        );
        return (next, null); // null = state is ready, create bill now

      case BillStep.idle:
      case BillStep.ready:
        return (state, null); // not handled by flow manager
    }
  }

  // ────────────────────────────────────────────────────────
  //  ITEM PARSING from free text
  // ────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> _parseItems(String msg) {
    final items = <Map<String, dynamic>>[];

    // Split on comma, "aur", "or", "and", "+"
    final parts = msg
        .split(RegExp(r',|aur\b|or\b|and\b|\+', caseSensitive: false))
        .map((s) => s
        .replaceAll(
        RegExp(r'\b(qty|quantity|piece|pcs|units?|no\.?|number)\b',
            caseSensitive: false),
        '')
        .trim())
        .where((s) => s.isNotEmpty)
        .toList();

    for (final part in parts) {
      // "qty name" → "5 apple"
      final qtyFirst = RegExp(r'^(\d+)\s+(.+)$').firstMatch(part);
      if (qtyFirst != null) {
        final qty = int.tryParse(qtyFirst.group(1)!);
        final name = qtyFirst.group(2)!.trim();
        if (qty != null && name.isNotEmpty) {
          items.add(_item(name, qty));
          continue;
        }
      }
      // "name qty" → "apple 5"
      final nameFirst = RegExp(r'^(.+?)\s+(\d+)$').firstMatch(part);
      if (nameFirst != null) {
        final name = nameFirst.group(1)!.trim();
        final qty = int.tryParse(nameFirst.group(2)!);
        if (qty != null && name.isNotEmpty) {
          items.add(_item(name, qty));
        }
      }
    }
    return items;
  }

  static Map<String, dynamic> _item(String name, int qty) => {
    'name': name,
    'qty': qty,
    'price': null,
    'tax_rate': 0.0,
    'discount_per_item': 0.0,
  };

  static String _taxQuestion() =>
      'Tax inclusive hai ya exclusive?\n'
          '• Exclusive = tax price ke upar add hoga (common)\n'
          '• Inclusive = tax price mein pehle se hai\n'
          'GST % bhi batao. Jaise: "exclusive 18%" ya "no tax"';

  static String _paymentQuestion() =>
      'Payment kaise hui?\n'
          '• Cash\n'
          '• UPI / GPay / PhonePe\n'
          '• Udhaar (credit, baad mein payment)\n'
          '• Cheque';

  static String _clean(String msg) => msg.toLowerCase().trim();
}
