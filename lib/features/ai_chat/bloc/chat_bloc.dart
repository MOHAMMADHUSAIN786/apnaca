

import 'package:flutter_bloc/flutter_bloc.dart';

import '../model/bill_creation_state.dart';
import '../model/chat_models.dart';
import '../repository/ai_chat_repository.dart';
import '../service/bill_flow_manager.dart';
import '../service/branding_storage_service.dart';
import '../service/input_validator.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final AiChatRepository _repository;

  List<ChatMessage> _history = [];
  String _sessionId = _generateSessionId();
  static String _generateSessionId() =>
      'session_${DateTime.now().millisecondsSinceEpoch}';

  BillCreationState _billState = BillCreationState.empty;
  OptionalStep _optionalStep = OptionalStep.none;
  String _pendingEntityName = '';
  String _detectedLanguage = 'hinglish';
  ParsedAction? _pendingDeleteAction;

  // Track consecutive "don't understand" to avoid loops
  int _ambiguousCount = 0;

  ChatBloc({required AiChatRepository repository})
      : _repository = repository,
        super(ChatInitial()) {
    on<SendMessageEvent>(_onSendMessage);
    on<ClearChatEvent>(_onClearChat);
    on<BrandingImageUploadedEvent>(_onBrandingImageUploaded);
  }

  // ══════════════════════════════════════════════════════════════════
  //  SEND MESSAGE
  // ══════════════════════════════════════════════════════════════════
  Future<void> _onSendMessage(
      SendMessageEvent event,
      Emitter<ChatState> emit,
      ) async {
    final userMsg = event.message.trim();
    if (userMsg.isEmpty) return;

    _detectedLanguage = _detectLanguage(userMsg);

    final validationError = InputValidator.validate(userMsg);
    if (validationError != null) {
      _addMsg(role: 'user', content: userMsg);
      _addMsg(role: 'assistant', content: '🚫 $validationError');
      emit(ChatError(messages: List.unmodifiable(_history), error: validationError));
      return;
    }

    _addMsg(role: 'user', content: userMsg);
    emit(ChatLoading(messages: List.unmodifiable(_history)));

    try {
      // ── BUG D FIX: Ambiguous short message guard ─────────────────────
      // "kitna", "kya", "haan" alone = too vague → ask for clarification
      if (_isAmbiguousMessage(userMsg) && !_billState.isActive && _optionalStep == OptionalStep.none) {
        _ambiguousCount++;
        String clarify;
        if (_ambiguousCount >= 2) {
          // After 2 tries, give examples
          clarify = 'Kuch aur clearly batao.\n\nExamples:\n• "Aaj ki sale dikhao"\n• "Apple item add karo 10 qty 50 price"\n• "Raj ko 5 mango ka bill banao"';
          _ambiguousCount = 0;
        } else {
          clarify = 'Kya karna hai? Thoda aur batao.\nExample: "bill banao", "item add karo", "analytics dikhao"';
        }
        _addMsg(role: 'assistant', content: clarify);
        emit(ChatSuccess(
          messages: List.unmodifiable(_history),
          lastResult: ActionResult.success(reply: clarify),
        ));
        return;
      }
      _ambiguousCount = 0;

      // ── Delete confirmation check ─────────────────────────────────────
      if (_pendingDeleteAction != null) {
        await _handleDeleteConfirmation(userMsg, emit);
        return;
      }

      // ── Optional details step ─────────────────────────────────────────
      if (_optionalStep != OptionalStep.none) {
        await _handleOptionalDetailsReply(userMsg, emit);
        return;
      }

      // ── Standalone branding ───────────────────────────────────────────
      if (_isBrandingIntent(userMsg) && !_billState.isActive) {
        await _handleStandaloneBrandingIntent(emit);
        return;
      }

      // ── BUG A FIX: Bill edit intent OVERRIDES active bill flow ────────
      // If user is in bill flow but asks to edit an existing bill,
      // exit flow and process as edit command.
      if (_billState.isActive && _isEditIntent(userMsg)) {
        // Abandon current bill flow
        _billState = BillCreationState.empty;
        // Fall through to LLM handling below
      }

      // ── BILL FLOW ACTIVE ──────────────────────────────────────────────
      if (_billState.isActive && !_billState.isReady) {
        if (_billState.step == BillStep.askingPayment) {
          final (newState, question) = BillFlowManager.processReply(
            userMessage: userMsg,
            state: _billState,
          );
          _billState = newState;

          if (question != null) {
            _addMsg(role: 'assistant', content: question);
            emit(ChatSuccess(
              messages: List.unmodifiable(_history),
              lastResult: ActionResult.needsInput(question: question, field: 'payment'),
            ));
            return;
          }
          await _handleBrandingCheck(emit);
          return;
        }

        final (newState, question) = BillFlowManager.processReply(
          userMessage: userMsg,
          state: _billState,
        );
        _billState = newState;

        if (question != null) {
          _addMsg(role: 'assistant', content: question);
          final field = _billState.step == BillStep.collectingLogo
              ? 'logo'
              : _billState.step == BillStep.collectingSignature
              ? 'signature'
              : 'bill_flow';
          emit(ChatSuccess(
            messages: List.unmodifiable(_history),
            lastResult: ActionResult.needsInput(question: question, field: field),
          ));
          return;
        }

        if (_billState.isReady) {
          await _createBillAndEmit(emit);
          return;
        }

        if (_billState.step == BillStep.askingBranding) {
          await _handleBrandingCheck(emit);
          return;
        }
      }

      // ── BUG B FIX: Pre-process purchase bill intent ───────────────────
      // "ek purchase bill Raj kaa" → LLM confuses Raj as supplier
      // Fix: detect this pattern and inject clarifying context in message
      final enrichedMsg = _enrichPurchaseBillMessage(userMsg);

      // ── SEND TO LLM ───────────────────────────────────────────────────
      final result = await _repository.sendMessage(
        userMessage: enrichedMsg,
        history: _history,
        sessionId: _sessionId,
        detectedLanguage: _detectedLanguage,
        contextDepth: _billState.isActive ? 15 : 10,
      );

      // Optional-details clarify path
      if (result.type == ActionResultType.success &&
          result.reply.contains('Optional details') &&
          result.pendingEntityName != null) {
        _optionalStep = result.pendingEntityType ?? OptionalStep.none;
        _pendingEntityName = result.pendingEntityName ?? '';
      }

      // Bill flow path
      if (result.type == ActionResultType.startBillFlow) {
        _billState = result.initialBillState!;
        if (_billState.isReady) {
          await _handleBrandingCheck(emit);
          return;
        }
        final question = BillFlowManager.nextQuestion(_billState);
        final q = question ?? 'Koi discount dena hai? (haan / nahi)';
        _addMsg(role: 'assistant', content: q);
        final field = _billState.step == BillStep.collectingItems
            ? 'items'
            : _billState.step == BillStep.askingDiscount
            ? 'discount'
            : _billState.step == BillStep.askingTax
            ? 'tax'
            : _billState.step == BillStep.askingPayment
            ? 'payment'
            : 'bill_flow';
        emit(ChatSuccess(
          messages: List.unmodifiable(_history),
          lastResult: ActionResult.needsInput(question: q, field: field),
        ));
        return;
      }

      // BUG E FIX: Ensure result always emits, even for empty tableData
      _addMsg(
        role: 'assistant',
        content: result.reply,
        tableData: result.tableData,
        detailCard: result.detailCard,
        isCustomerNotFound: result.isCustomerNotFound,
        isSubscriptionRequired: result.isSubscriptionRequired,
      );
      emit(ChatSuccess(messages: List.unmodifiable(_history), lastResult: result));

    } catch (e) {
      const friendlyMsg = '⚠️ Kuch gadbad ho gayi. Thodi der baad try karein.';
      _addMsg(role: 'assistant', content: friendlyMsg);
      emit(ChatError(messages: List.unmodifiable(_history), error: friendlyMsg));
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  BUG A FIX: Edit intent detection
  //  Returns true if user is trying to edit an existing bill
  // ══════════════════════════════════════════════════════════════════
  static bool _isEditIntent(String msg) {
    final l = msg.toLowerCase();
    // Explicit edit words
    if (l.contains('edit') || l.contains('badlo') || l.contains('change')) {
      if (l.contains('bill') || l.contains('qty') || l.contains('price') ||
          l.contains('item') || l.contains('last')) {
        return true;
      }
    }
    // "last bill me qty X kardo"
    if ((l.contains('last bill') || l.contains('pichle bill') || l.contains('purana bill')) &&
        (l.contains('qty') || l.contains('price') || l.contains('status'))) {
      return true;
    }
    // Bill number mentioned with edit context
    if (RegExp(r'[SP]B-\d{4}-\d{4}').hasMatch(l) &&
        (l.contains('qty') || l.contains('price') || l.contains('paid') || l.contains('edit'))) {
      return true;
    }
    return false;
  }

  // ══════════════════════════════════════════════════════════════════
  //  BUG B FIX: Purchase bill message enrichment
  //  "ek purchase bill Raj kaa" → proper context for LLM
  // ══════════════════════════════════════════════════════════════════
  static String _enrichPurchaseBillMessage(String msg) {
    final l = msg.toLowerCase();

    // Pattern: "(ek) purchase bill [Name] kaa/ka/ke liye"
    // LLM confuses Name as supplier and tries to create supplier
    // Fix: rewrite to make intent clear
    if (l.contains('purchase bill') || l.contains('kharida') || l.contains('kharidi')) {
      // Already has supplier_name mention? Don't touch
      if (l.contains('supplier') || l.contains('se ')) return msg;

      // Pattern: "purchase bill Raj kaa" → "Raj supplier se purchase bill banana hai"
      final nameMatch = RegExp(
          r'purchase bill\s+([A-Za-z]+(?:\s+[A-Za-z]+)?)\s+(?:kaa|ka|ke|ke liye|ki|kaa)')
          .firstMatch(l);
      if (nameMatch != null) {
        final name = nameMatch.group(1)!.trim();
        // Capitalize properly
        final properName = name.split(' ').map((w) =>
        w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
        return '$properName se purchase bill banana hai. Items aur price bhi batao.';
      }
    }

    return msg;
  }

  // ══════════════════════════════════════════════════════════════════
  //  BUG D FIX: Ambiguous message detection
  //  "kitna", "kya", short words with no action context
  // ══════════════════════════════════════════════════════════════════
  static bool _isAmbiguousMessage(String msg) {
    final l = msg.toLowerCase().trim();

    // Very short (≤5 chars) and no recognized action keyword
    if (l.length <= 5) {
      const actionKeywords = [
        'list', 'show', 'add', 'ok', 'yes', 'no', 'haan', 'nahi',
        'nai', 'na', 'ha', 'paid', 'done', 'sale', 'bill',
      ];
      return !actionKeywords.any((k) => l == k || l.contains(k));
    }

    // Standalone vague words
    const vagueWords = [
      'kitna', 'kya hai', 'batao', 'kuch', 'thik', 'sahi',
      'achha', 'acha', 'okay', 'hmm', 'hm', 'ahan', 'acha theek',
      'wapis', 'vapis', 'phir se',
    ];
    // Only ambiguous if ONLY these words, no other context
    if (vagueWords.any((w) => l == w)) return true;

    return false;
  }

  // ══════════════════════════════════════════════════════════════════
  //  DELETE CONFIRMATION HANDLER
  // ══════════════════════════════════════════════════════════════════
  Future<void> _handleDeleteConfirmation(
      String userMsg,
      Emitter<ChatState> emit,
      ) async {
    final isConfirm = _isConfirmYes(userMsg);
    final isCancel  = _isSkipOrNo(userMsg);
    final pending   = _pendingDeleteAction!;

    if (isCancel) {
      _pendingDeleteAction = null;
      const msg = '❌ Delete cancel ho gaya.';
      _addMsg(role: 'assistant', content: msg);
      emit(ChatSuccess(
        messages: List.unmodifiable(_history),
        lastResult: ActionResult.success(reply: msg),
      ));
      return;
    }

    if (isConfirm) {
      _pendingDeleteAction = null;
      final result = await _repository.executeDirectAction(
        action: pending,
        sessionId: _sessionId,
      );
      _addMsg(role: 'assistant', content: result.reply,
          tableData: result.tableData, detailCard: result.detailCard);
      emit(ChatSuccess(messages: List.unmodifiable(_history), lastResult: result));
      return;
    }

    const reAsk = '⚠️ "Haan" bolein confirm karne ke liye, ya "Nahi" bolein cancel karne ke liye.';
    _addMsg(role: 'assistant', content: reAsk);
    emit(ChatSuccess(
      messages: List.unmodifiable(_history),
      lastResult: ActionResult.needsInput(question: reAsk, field: 'confirm_delete'),
    ));
  }

  static bool _isConfirmYes(String msg) {
    final l = msg.toLowerCase().trim();
    const yesWords = ['haan', 'han', 'yes', 'confirm', 'ok', 'okay', 'bilkul',
      'kar do', 'karo', 'delete karo', 'haa', 'ji haan', 'ji'];
    return yesWords.any((w) => l == w || l.contains(w));
  }

  // ══════════════════════════════════════════════════════════════════
  //  OPTIONAL DETAILS HANDLER
  // ══════════════════════════════════════════════════════════════════
  Future<void> _handleOptionalDetailsReply(
      String userMsg,
      Emitter<ChatState> emit,
      ) async {
    final isSkip = _isSkipOrNo(userMsg);

    if (isSkip) {
      final entityName = _pendingEntityName;
      final step = _optionalStep;
      _optionalStep = OptionalStep.none;
      _pendingEntityName = '';

      final result = await _repository.createEntityByName(
        name: entityName,
        entityType: step,
        sessionId: _sessionId,
      );
      _addMsg(role: 'assistant', content: result.reply);
      emit(ChatSuccess(messages: List.unmodifiable(_history), lastResult: result));
      return;
    }

    final pendingName = _pendingEntityName;
    final pendingStep = _optionalStep;
    _optionalStep = OptionalStep.none;
    _pendingEntityName = '';

    final entityType = switch (pendingStep) {
      OptionalStep.customer => 'customer',
      OptionalStep.supplier => 'supplier',
      OptionalStep.item     => 'item',
      OptionalStep.none     => 'entity',
    };
    final enrichedMsg = '$pendingName $entityType update karo: $userMsg';

    final result = await _repository.sendMessage(
      userMessage: enrichedMsg,
      history: _history,
      sessionId: _sessionId,
      detectedLanguage: _detectedLanguage,
    );

    _addMsg(role: 'assistant', content: result.reply,
        tableData: result.tableData, detailCard: result.detailCard);
    emit(ChatSuccess(messages: List.unmodifiable(_history), lastResult: result));
  }

  // ══════════════════════════════════════════════════════════════════
  //  BRANDING IMAGE UPLOADED
  // ══════════════════════════════════════════════════════════════════
  Future<void> _onBrandingImageUploaded(
      BrandingImageUploadedEvent event,
      Emitter<ChatState> emit,
      ) async {
    emit(ChatLoading(messages: List.unmodifiable(_history)));
    try {
      if (event.imageType == 'logo') {
        final url = await BrandingStorageService.uploadLogo(event.imageFile);
        _billState = _billState.copyWith(
          companyLogoUrl: url,
          step: BillStep.collectingSignature,
        );
        const q = '✅ Logo save ho gaya!\n\n📎 Ab signature ki photo bhejein:\n(Skip karna ho to "nahi" bolein)';
        _addMsg(role: 'assistant', content: q);
        emit(ChatSuccess(
          messages: List.unmodifiable(_history),
          lastResult: ActionResult.needsInput(question: q, field: 'signature'),
        ));
      } else if (event.imageType == 'signature') {
        final url = await BrandingStorageService.uploadSignature(event.imageFile);
        _billState = _billState.copyWith(signatureUrl: url, step: BillStep.ready);
        _addMsg(role: 'assistant', content: '✅ Signature save ho gaya! Bill bana raha hoon...');
        emit(ChatLoading(messages: List.unmodifiable(_history)));
        await _createBillAndEmit(emit);
      }
    } catch (e) {
      const errMsg = '⚠️ Image upload nahi ho payi. Dobara try karein.';
      _addMsg(role: 'assistant', content: errMsg);
      emit(ChatError(messages: List.unmodifiable(_history), error: errMsg));
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  BRANDING CHECK
  // ══════════════════════════════════════════════════════════════════
  Future<void> _handleBrandingCheck(Emitter<ChatState> emit) async {
    try {
      final urls = await BrandingStorageService.checkBothUrls();
      final logoUrl = urls['logo']!;
      final sigUrl  = urls['signature']!;

      if (logoUrl.isNotEmpty && sigUrl.isNotEmpty) {
        _billState = _billState.copyWith(
            companyLogoUrl: logoUrl, signatureUrl: sigUrl, step: BillStep.ready);
        _addMsg(role: 'assistant', content: '✅ Bill bana raha hoon...');
        emit(ChatLoading(messages: List.unmodifiable(_history)));
        await _createBillAndEmit(emit);
        return;
      }

      _billState = _billState.copyWith(
        companyLogoUrl: logoUrl.isEmpty ? null : logoUrl,
        signatureUrl:   sigUrl.isEmpty  ? null : sigUrl,
        step: BillStep.askingBranding,
      );

      const q = '🏢 Kya aap bill mein company logo aur signature add karna chahte hain?\n'
          '(Ek baar upload karo, hamesha automatically lagega)\n\n'
          '• "Haan" — logo/signature add karein\n'
          '• "Nahi" — skip karein';
      _addMsg(role: 'assistant', content: q);
      emit(ChatSuccess(
        messages: List.unmodifiable(_history),
        lastResult: ActionResult.needsInput(question: q, field: 'branding'),
      ));
    } catch (_) {
      _billState = _billState.copyWith(brandingSkipped: true, step: BillStep.ready);
      await _createBillAndEmit(emit);
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  CREATE BILL
  // ══════════════════════════════════════════════════════════════════
  Future<void> _createBillAndEmit(Emitter<ChatState> emit) async {
    if (_billState.items.isEmpty) {
      _billState = BillCreationState.empty;
      const msg = '✅ Branding save ho gayi! Agli baar bill banane pe logo aur signature automatically PDF mein aa jayega. 🎉';
      _addMsg(role: 'assistant', content: msg);
      emit(ChatSuccess(
          messages: List.unmodifiable(_history),
          lastResult: ActionResult.success(reply: msg)));
      return;
    }

    final result = await _repository.createBillFromState(
      state: _billState,
      sessionId: _sessionId,
    );
    _billState = BillCreationState.empty;

    if (result.isSubscriptionRequired) {
      _addMsg(role: 'assistant', content: result.reply, isSubscriptionRequired: true);
      emit(ChatSuccess(messages: List.unmodifiable(_history), lastResult: result));
      return;
    }
    _addMsg(role: 'assistant', content: result.reply,
        tableData: result.tableData, detailCard: result.detailCard);
    emit(ChatSuccess(messages: List.unmodifiable(_history), lastResult: result));
  }

  // ══════════════════════════════════════════════════════════════════
  //  CLEAR CHAT
  // ══════════════════════════════════════════════════════════════════
  void _onClearChat(ClearChatEvent event, Emitter<ChatState> emit) {
    _history = [];
    _billState           = BillCreationState.empty;
    _optionalStep        = OptionalStep.none;
    _pendingEntityName   = '';
    _pendingDeleteAction = null;
    _ambiguousCount      = 0;
    _sessionId = _generateSessionId();
    emit(ChatInitial());
  }

  // ══════════════════════════════════════════════════════════════════
  //  BRANDING INTENT
  // ══════════════════════════════════════════════════════════════════
  static bool _isBrandingIntent(String msg) {
    final l = msg.toLowerCase();
    return (l.contains('logo') || l.contains('signature') || l.contains('sign')) &&
        (l.contains('add') || l.contains('lagao') || l.contains('karna') ||
            l.contains('upload') || l.contains('bill') || l.contains('pdf') ||
            l.contains('laga') || l.contains('dalna'));
  }

  Future<void> _handleStandaloneBrandingIntent(Emitter<ChatState> emit) async {
    try {
      final urls = await BrandingStorageService.checkBothUrls();
      final logoUrl = urls['logo']!;
      final sigUrl  = urls['signature']!;

      if (logoUrl.isNotEmpty && sigUrl.isNotEmpty) {
        const msg = '✅ Aapka company logo aur signature already save hai!\n'
            'Agli baar bill banane pe automatically PDF mein aa jaayega.\n\n'
            'Update karna ho to "logo update karo" ya "signature update karo" bolein.';
        _addMsg(role: 'assistant', content: msg);
        emit(ChatSuccess(messages: List.unmodifiable(_history),
            lastResult: ActionResult.success(reply: msg)));
        return;
      }

      _billState = const BillCreationState(step: BillStep.askingBranding, brandingSkipped: false);

      const q = '🏢 Theek hai! Logo aur signature dono add karein?\n\n'
          '• "Haan" — logo phir signature upload karein\n'
          '• "Nahi" — skip karein';
      _addMsg(role: 'assistant', content: q);
      emit(ChatSuccess(
        messages: List.unmodifiable(_history),
        lastResult: ActionResult.needsInput(question: q, field: 'branding'),
      ));
    } catch (_) {
      const msg = '⚠️ Branding check nahi ho payi. Thodi der baad try karein.';
      _addMsg(role: 'assistant', content: msg);
      emit(ChatError(messages: List.unmodifiable(_history), error: msg));
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════════════════
  static bool _isSkipOrNo(String msg) {
    final l = msg.toLowerCase().trim();
    const skipWords = ['skip', 'nahi', 'nai', 'na', 'no', 'nope', 'mat',
      'rehne do', 'chhoddo', 'chhodo', 'nhi', 'not now', 'cancel',
      'sirf naam', 'naam hi kaafi', 'without', 'band karo', 'bas'];
    return skipWords.any((w) => l == w || l.contains(w));
  }

  static String _detectLanguage(String msg) {
    if (RegExp(r'[\u0A80-\u0AFF]').hasMatch(msg)) return 'gu';
    if (RegExp(r'[\u0900-\u097F]').hasMatch(msg)) return 'hi';
    final l = msg.toLowerCase();
    const hinglishWords = ['karo', 'karna', 'hai', 'hain', 'ka', 'ki', 'ke',
      'mein', 'aur', 'ya', 'bhi', 'nahi', 'kya', 'kitna', 'batao',
      'dikhao', 'chahiye', 'banao', 'list', 'sab', 'wala'];
    if (hinglishWords.any((w) => l.contains(w))) return 'hinglish';
    return 'en';
  }

  void _addMsg({
    required String role,
    required String content,
    List<Map<String, dynamic>>? tableData,
    Map<String, dynamic>? detailCard,
    bool isCustomerNotFound = false,
    bool isSubscriptionRequired = false,
  }) {
    _history = [
      ..._history,
      ChatMessage(
        role: role,
        content: content,
        tableData: tableData,
        detailCard: detailCard,
        isCustomerNotFound: isCustomerNotFound,
        isSubscriptionRequired: isSubscriptionRequired,
      ),
    ];
  }

  String get currentSessionId => _sessionId;
}