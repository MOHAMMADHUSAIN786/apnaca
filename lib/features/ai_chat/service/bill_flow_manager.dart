import '../model/bill_creation_state.dart';

/// Pure Dart state machine for multi-turn bill creation.
/// LLM extracts customer + items + any known fields in first message.
/// This class handles ONLY the missing fields — skips what AI already gave.
class BillFlowManager {

  // ─────────────────────────────────────────────────────────────────
  //  YES / NO
  // ─────────────────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────────────────
  //  DISCOUNT
  // ─────────────────────────────────────────────────────────────────
  static Map<String, dynamic>? parseDiscount(String msg) {
    final l = _clean(msg);

    // Explicit "no discount" variants
    if (isNo(l) ||
        l.contains('no discount') || l.contains('discount nahi') ||
        l.contains('bina discount') || l.contains('without discount') ||
        l.contains('0 discount') || l.contains('zero discount') ||
        l.contains('koi discount nahi')) {
      return {'type': 'none', 'value': 0.0};
    }

    final pct = RegExp(r'(\d+(?:\.\d+)?)\s*(?:%|percent|feesad|pratishat)')
        .firstMatch(l);
    if (pct != null) {
      return {'type': 'percent', 'value': double.parse(pct.group(1)!)};
    }

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

  // ─────────────────────────────────────────────────────────────────
  //  TAX
  // ─────────────────────────────────────────────────────────────────
  static Map<String, dynamic>? parseTax(String msg) {
    final l = _clean(msg);

    // No tax variants
    if (l == 'no' || l == 'nahi' || l == 'na' ||
        l.contains('no tax') || l.contains('tax nahi') ||
        l.contains('koi tax') || l.contains('bina tax') ||
        l.contains('without tax') || l.contains('0%') ||
        l.contains('zero tax') || l.contains('0 percent') ||
        l.contains('tax nhi') || l.contains('tax mat')) {
      return {'type': 'exclusive', 'rate': 0.0};
    }

    final isInclusive = l.contains('inclusive') || l.contains('andar') ||
        l.contains('shamil') || l.contains('included') || l.contains('sath');
    final taxType = isInclusive ? 'inclusive' : 'exclusive';

    final rateMatch =
    RegExp(r'(\d+(?:\.\d+)?)\s*(?:%|percent|gst)').firstMatch(l);
    if (rateMatch != null) {
      final rate = double.parse(rateMatch.group(1)!);
      return {'type': taxType, 'rate': rate};
    }

    return null;
  }

  // ─────────────────────────────────────────────────────────────────
  //  PAYMENT
  // ─────────────────────────────────────────────────────────────────
  static Map<String, String>? parsePayment(String msg) {
    final l = _clean(msg);

    if (l.contains('udhaar') || l.contains('udhar') ||
        l.contains('baad mein') || l.contains('badme') ||
        l.contains('later') || l.contains('credit')) {
      return {'mode': 'udhar', 'status': 'unpaid'};
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
      final status = l.contains('unpaid') || l.contains('pending') ? 'unpaid' : 'paid';
      return {'mode': 'upi', 'status': status};
    }
    if (l.contains('cash') || l.contains('nakit') || l.contains('nakad') ||
        l.contains('note') || l.contains('haath mein')) {
      final status = l.contains('unpaid') || l.contains('pending') ? 'unpaid' : 'paid';
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

  // ─────────────────────────────────────────────────────────────────
  //  NEXT QUESTION for current step
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
        return _taxQuestion();
      case BillStep.askingPayment:
        return _paymentQuestion();
      case BillStep.askingBranding:
        return _brandingQuestion();
      case BillStep.collectingLogo:
        return '📎 Company logo ki photo bhejein (gallery se select karein):';
      case BillStep.collectingSignature:
        return '📎 Signature ki photo bhejein:\n(Skip karna ho to "nahi" bolein)';
      case BillStep.idle:
      case BillStep.ready:
        return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  MAIN: process reply for current step
  //  Returns (newState, questionToAsk)
  // ─────────────────────────────────────────────────────────────────
  static (BillCreationState, String?) processReply({
    required String userMessage,
    required BillCreationState state,
  }) {
    switch (state.step) {

    // ── Collecting items ────────────────────────────────────────────
      case BillStep.collectingItems:
        final parsed = _parseItems(userMessage);
        if (parsed.isEmpty) {
          return (state, 'Kaunsa item aur kitni quantity?\nExample: "apple 5, mango 10"');
        }
        final next = state.copyWith(items: parsed, step: BillStep.askingDiscount);
        return (next, 'Koi discount dena hai? (haan / nahi)');

    // ── Asking discount yes/no ──────────────────────────────────────
      case BillStep.askingDiscount:
        final disc = parseDiscount(userMessage);
        if (disc != null) {
          // User gave discount value directly OR said no discount
          final next = state.copyWith(
            discountType: disc['type'] as String,
            discountValue: disc['value'] as double,
            step: BillStep.askingTax,
          );
          return (next, _taxQuestion());
        }
        if (isYes(userMessage)) {
          final next = state.copyWith(step: BillStep.collectingDiscount);
          return (next, 'Kitna discount?\nExample: "10%" ya "₹50 off"');
        }
        return (state, 'Discount dena hai? "haan" ya "nahi" bolein.');

    // ── Collecting discount value ───────────────────────────────────
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

    // ── Asking tax ──────────────────────────────────────────────────
      case BillStep.askingTax:
        final tax = parseTax(userMessage);
        if (tax == null) {
          return (state, 'Tax samajh nahi aaya.\nBolein: "exclusive 18%" ya "inclusive 5%" ya "no tax"');
        }
        final next = state.copyWith(
          taxType: tax['type'] as String,
          taxRate: tax['rate'] as double,
          step: BillStep.askingPayment,
        );
        return (next, _paymentQuestion());

    // ── Asking payment ──────────────────────────────────────────────
      case BillStep.askingPayment:
        final payment = parsePayment(userMessage);
        if (payment == null) {
          return (state, 'Payment samajh nahi aaya.\nBolein: Cash / UPI / GPay / Udhaar / Cheque');
        }
        final next = state.copyWith(
          paymentMode: payment['mode'],
          paymentStatus: payment['status'],
          step: BillStep.askingBranding,
        );
        return (next, null); // null = ChatBloc handles Firebase Storage check

    // ── Asking branding ─────────────────────────────────────────────
      case BillStep.askingBranding:
        if (isNo(userMessage)) {
          return (
          state.copyWith(brandingSkipped: true, step: BillStep.ready),
          null,
          );
        }
        if (isYes(userMessage)) {
          return (
          state.copyWith(step: BillStep.collectingLogo),
          '📎 Company logo ki photo bhejein (gallery se select karein):',
          );
        }
        return (state, _brandingQuestion());

    // ── Logo / Signature — text reply = skip ───────────────────────
      case BillStep.collectingLogo:
      case BillStep.collectingSignature:
        final shouldSkip = isNo(userMessage) ||
            userMessage.toLowerCase().contains('skip') ||
            userMessage.toLowerCase().contains('nahi') ||
            userMessage.toLowerCase().contains('nai');

        if (shouldSkip) {
          if (state.step == BillStep.collectingLogo) {
            return (
            state.copyWith(companyLogoUrl: '', step: BillStep.collectingSignature),
            '📎 Signature ki photo bhejein:\n(Skip karna ho to "nahi" bolein)',
            );
          } else {
            return (
            state.copyWith(signatureUrl: '', step: BillStep.ready),
            null,
            );
          }
        }
        final prompt = state.step == BillStep.collectingLogo
            ? '📎 Logo ki photo bhejein, ya "nahi" bolein skip ke liye.'
            : '📎 Signature ki photo bhejein, ya "nahi" bolein skip ke liye.';
        return (state, prompt);

      case BillStep.idle:
      case BillStep.ready:
        return (state, null);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  ITEM PARSING from free text
  // ─────────────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> _parseItems(String msg) {
    final items = <Map<String, dynamic>>[];

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
      // "5 apple" format
      final qtyFirst = RegExp(r'^(\d+)\s+(.+)$').firstMatch(part);
      if (qtyFirst != null) {
        final qty = int.tryParse(qtyFirst.group(1)!);
        final name = qtyFirst.group(2)!.trim();
        if (qty != null && name.isNotEmpty) {
          items.add(_item(name, qty));
          continue;
        }
      }
      // "apple 5" format
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
          '• Udhaar (baad mein payment)\n'
          '• Cheque';

  static String _brandingQuestion() =>
      '🏢 Kya aap bill mein company logo aur signature add karna chahte hain?\n'
          '(Ek baar upload karo, hamesha automatically lagega)\n\n'
          '• "Haan" — logo/signature add karein\n'
          '• "Nahi" — skip karein';

  static String _clean(String msg) => msg.toLowerCase().trim();
}