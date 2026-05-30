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
  final List<ChatMessage> _history = [];

  String _sessionId = _generateSessionId();
  static String _generateSessionId() =>
      'session_${DateTime.now().millisecondsSinceEpoch}';

  BillCreationState _billState = BillCreationState.empty;

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

    final validationError = InputValidator.validate(userMsg);
    if (validationError != null) {
      _addMsg(role: 'user', content: userMsg);
      _addMsg(role: 'assistant', content: '🚫 $validationError');
      emit(ChatError(messages: List.from(_history), error: validationError));
      return;
    }

    _addMsg(role: 'user', content: userMsg);
    emit(ChatLoading(messages: List.from(_history)));

    try {
      // ── STANDALONE BRANDING INTENT ─────────────────────────────────
      if (_isBrandingIntent(userMsg) && !_billState.isActive) {
        await _handleStandaloneBrandingIntent(emit);
        return;
      }

      // ── BILL FLOW ACTIVE ────────────────────────────────────────────
      if (_billState.isActive && !_billState.isReady) {

        // Special: payment step → after parsing, check branding
        if (_billState.step == BillStep.askingPayment) {
          final (newState, question) = BillFlowManager.processReply(
            userMessage: userMsg,
            state: _billState,
          );
          _billState = newState;

          if (question != null) {
            _addMsg(role: 'assistant', content: question);
            emit(ChatSuccess(
              messages: List.from(_history),
              lastResult: ActionResult.needsInput(question: question, field: 'payment'),
            ));
            return;
          }

          // Payment parsed → check branding
          await _handleBrandingCheck(emit);
          return;
        }

        // All other bill steps
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
            messages: List.from(_history),
            lastResult: ActionResult.needsInput(question: question, field: field),
          ));
          return;
        }

        if (_billState.isReady) {
          await _createBillAndEmit(emit);
          return;
        }

        // askingBranding with null question → ChatBloc checks Storage
        if (_billState.step == BillStep.askingBranding) {
          await _handleBrandingCheck(emit);
          return;
        }
      }

      // ── SEND TO LLM ────────────────────────────────────────────────
      final result = await _repository.sendMessage(
        userMessage: userMsg,
        history: _history,
        sessionId: _sessionId,
      );

      if (result.type == ActionResultType.startBillFlow) {
        _billState = result.initialBillState!;

        // ✅ KEY FIX: If bill state is already READY (all info provided),
        // skip all questions and go straight to branding check → bill creation
        if (_billState.isReady) {
          await _handleBrandingCheck(emit);
          return;
        }

        // Some info still missing — ask only for what's needed
        final question = BillFlowManager.nextQuestion(_billState);
        final q = question ?? 'Koi discount dena hai? (haan / nahi)';

        _addMsg(role: 'assistant', content: q);

        final field = _billState.step == BillStep.collectingItems ? 'items'
            : _billState.step == BillStep.askingDiscount ? 'discount'
            : _billState.step == BillStep.askingTax ? 'tax'
            : _billState.step == BillStep.askingPayment ? 'payment'
            : 'bill_flow';

        emit(ChatSuccess(
          messages: List.from(_history),
          lastResult: ActionResult.needsInput(question: q, field: field),
        ));
        return;
      }

      _addMsg(
        role: 'assistant',
        content: result.reply,
        tableData: result.tableData,
        detailCard: result.detailCard,
        isCustomerNotFound: result.isCustomerNotFound,
        isSubscriptionRequired: result.isSubscriptionRequired,
      );
      emit(ChatSuccess(messages: List.from(_history), lastResult: result));

    } catch (e) {
      const friendlyMsg = '⚠️ Kuch gadbad ho gayi. Thodi der baad try karein.';
      _addMsg(role: 'assistant', content: friendlyMsg);
      emit(ChatError(messages: List.from(_history), error: friendlyMsg));
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  BRANDING IMAGE UPLOADED
  // ══════════════════════════════════════════════════════════════════
  Future<void> _onBrandingImageUploaded(
      BrandingImageUploadedEvent event,
      Emitter<ChatState> emit,
      ) async {
    emit(ChatLoading(messages: List.from(_history)));

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
          messages: List.from(_history),
          lastResult: ActionResult.needsInput(question: q, field: 'signature'),
        ));

      } else if (event.imageType == 'signature') {
        final url = await BrandingStorageService.uploadSignature(event.imageFile);
        _billState = _billState.copyWith(
          signatureUrl: url,
          step: BillStep.ready,
        );
        _addMsg(role: 'assistant', content: '✅ Signature save ho gaya! Bill bana raha hoon...');
        emit(ChatLoading(messages: List.from(_history)));
        await _createBillAndEmit(emit);
      }
    } catch (e) {
      const errMsg = '⚠️ Image upload nahi ho payi. Dobara try karein.';
      _addMsg(role: 'assistant', content: errMsg);
      emit(ChatError(messages: List.from(_history), error: errMsg));
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  BRANDING CHECK — after payment step
  // ══════════════════════════════════════════════════════════════════
  Future<void> _handleBrandingCheck(Emitter<ChatState> emit) async {
    try {
      final urls = await BrandingStorageService.checkBothUrls();
      final logoUrl = urls['logo']!;
      final sigUrl  = urls['signature']!;

      if (logoUrl.isNotEmpty && sigUrl.isNotEmpty) {
        // Both exist → skip question, create bill immediately
        _billState = _billState.copyWith(
          companyLogoUrl: logoUrl,
          signatureUrl:   sigUrl,
          step:           BillStep.ready,
        );
        _addMsg(role: 'assistant', content: '✅ Bill bana raha hoon...');
        emit(ChatLoading(messages: List.from(_history)));
        await _createBillAndEmit(emit);
        return;
      }

      // At least one missing → ask user
      _billState = _billState.copyWith(
        companyLogoUrl: logoUrl.isEmpty ? null : logoUrl,
        signatureUrl:   sigUrl.isEmpty ? null : sigUrl,
        step:           BillStep.askingBranding,
      );

      const q = '🏢 Kya aap bill mein company logo aur signature add karna chahte hain?\n'
          '(Ek baar upload karo, hamesha automatically lagega)\n\n'
          '• "Haan" — logo/signature add karein\n'
          '• "Nahi" — skip karein';

      _addMsg(role: 'assistant', content: q);
      emit(ChatSuccess(
        messages: List.from(_history),
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
      emit(ChatSuccess(messages: List.from(_history),
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
      emit(ChatSuccess(messages: List.from(_history), lastResult: result));
      return;
    }
    _addMsg(
      role: 'assistant',
      content: result.reply,
      tableData: result.tableData,
      detailCard: result.detailCard,
    );
    emit(ChatSuccess(messages: List.from(_history), lastResult: result));
  }

  // ══════════════════════════════════════════════════════════════════
  //  CLEAR CHAT
  // ══════════════════════════════════════════════════════════════════
  void _onClearChat(ClearChatEvent event, Emitter<ChatState> emit) {
    _history.clear();
    _billState = BillCreationState.empty;
    _sessionId = _generateSessionId();
    emit(ChatInitial());
  }

  // ══════════════════════════════════════════════════════════════════
  //  BRANDING INTENT (outside bill flow)
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
        emit(ChatSuccess(messages: List.from(_history),
            lastResult: ActionResult.success(reply: msg)));
        return;
      }

      _billState = const BillCreationState(
        step: BillStep.askingBranding,
        brandingSkipped: false,
      );

      const q = '🏢 Theek hai! Logo aur signature dono add karein?\n\n'
          '• "Haan" — logo phir signature upload karein\n'
          '• "Sirf logo" — sirf logo add karein\n'
          '• "Sirf signature" — sirf signature add karein';
      _addMsg(role: 'assistant', content: q);
      emit(ChatSuccess(
        messages: List.from(_history),
        lastResult: ActionResult.needsInput(question: q, field: 'branding'),
      ));
    } catch (_) {
      const msg = '⚠️ Branding check nahi ho payi. Thodi der baad try karein.';
      _addMsg(role: 'assistant', content: msg);
      emit(ChatError(messages: List.from(_history), error: msg));
    }
  }

  void _addMsg({
    required String role,
    required String content,
    List<Map<String, dynamic>>? tableData,
    Map<String, dynamic>? detailCard,
    bool isCustomerNotFound = false,
    bool isSubscriptionRequired = false,
  }) {
    _history.add(ChatMessage(
      role: role,
      content: content,
      tableData: tableData,
      detailCard: detailCard,
      isCustomerNotFound: isCustomerNotFound,
      isSubscriptionRequired: isSubscriptionRequired,
    ));
  }
}