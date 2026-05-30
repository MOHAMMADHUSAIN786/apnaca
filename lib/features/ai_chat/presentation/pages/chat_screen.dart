import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../../core/constants/app_colors.dart';
import '../../bloc/chat_bloc.dart';
import '../../bloc/chat_event.dart';
import '../../bloc/chat_state.dart';
import '../../model/chat_models.dart';
import '../../service/bill_pdf_service.dart';
import '../../../subscription/presentation/pages/subscription_screen.dart';
import 'branding_upload_widget.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _hasDatabaseChanges = false;

  // ── Voice (WhatsApp style: hold = record, release = send) ─────
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _capturedText = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) {
        debugPrint('Speech error: $e');
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
    );
    if (mounted) setState(() {});
  }

  /// Called when user presses & holds the mic button
  Future<void> _startListening() async {
    if (!_speechAvailable || _isListening) return;
    _capturedText = '';
    _controller.clear();
    setState(() => _isListening = true);
    await _speech.listen(
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      cancelOnError: true,
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _capturedText = result.recognizedWords;
          _controller.text = _capturedText;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
      },
    );
  }

  /// Called when user releases the mic button → stop + send
  Future<void> _stopAndSend() async {
    if (!_isListening) return;
    await _speech.stop();
    setState(() => _isListening = false);
    if (_capturedText.trim().isNotEmpty) {
      _controller.text = _capturedText.trim();
      _send();
    }
  }

  /// Called when user swipes/cancels (future: swipe left to cancel)
  Future<void> _cancelListening() async {
    await _speech.cancel();
    setState(() {
      _isListening = false;
      _capturedText = '';
      _controller.clear();
    });
  }

  void _send() {
    final text = _controller.text.trim();

    if (text.isEmpty) return;

    // detect possible db changes
    final lower = text.toLowerCase();

    if (lower.contains('add') ||
        lower.contains('create') ||
        lower.contains('delete') ||
        lower.contains('update') ||
        lower.contains('item') ||
        lower.contains('customer') ||
        lower.contains('bill')) {
      _hasDatabaseChanges = true;
    }

    context.read<ChatBloc>().add(SendMessageEvent(text));

    _controller.clear();

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }
  void _navigateBack() {
    Navigator.pop(context, _hasDatabaseChanges);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Add this method in _ChatScreenState class


// Update the AppBar's back button
      appBar: AppBar(
        backgroundColor: app_colors.table_header_bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: app_colors.title),
          onPressed: _navigateBack, // Use this instead of Navigator.pop directly
        ),
        title: Text('ApnaCA AI',
            style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: app_colors.title)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: app_colors.title),
            onPressed: () => context.read<ChatBloc>().add(ClearChatEvent()),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildList()),
          // ── Branding upload widget: shown only during logo/signature steps ──
          BlocBuilder<ChatBloc, ChatState>(
            builder: (_, state) {
              if (state is! ChatSuccess) return const SizedBox.shrink();
              final field = state.lastResult.askField ?? '';
              if (field == 'logo' || state.lastResult.type == ActionResultType.needsInput && field.contains('logo')) {
                return BrandingUploadWidget(imageType: 'logo');
              }
              if (field == 'signature' || state.lastResult.type == ActionResultType.needsInput && field.contains('signature')) {
                return BrandingUploadWidget(imageType: 'signature');
              }
              return const SizedBox.shrink();
            },
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildList() {
    return BlocConsumer<ChatBloc, ChatState>(
      listener: (_, __) => _scrollToBottom(),
      builder: (_, state) {
        List<ChatMessage> msgs = [];
        if (state is ChatLoading) msgs = state.messages;
        if (state is ChatSuccess) msgs = state.messages;
        if (state is ChatError) msgs = state.messages;

        if (msgs.isEmpty) return _emptyState();

        return ListView.builder(
          controller: _scroll,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          itemCount: msgs.length + (state is ChatLoading ? 1 : 0),
          itemBuilder: (_, i) {
            if (state is ChatLoading && i == msgs.length) {
              return const _TypingIndicator();
            }
            final msg = msgs[i];
            return msg.role == 'user'
                ? _UserBubble(text: msg.content)
                : _AiBubble(
              text: msg.content,
              tableData: msg.tableData,
              detailCard: msg.detailCard,
              isCustomerNotFound: msg.isCustomerNotFound,
              isSubscriptionRequired: msg.isSubscriptionRequired,
            );
          },
        );
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded,
                size: 48.sp,
                color: app_colors.c_primary.withOpacity(0.4)),
            SizedBox(height: 12.h),
            Text('Kuch bhi poochhein...',
                style: TextStyle(fontSize: 15.sp, color: Colors.grey[600])),
            SizedBox(height: 20.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              alignment: WrapAlignment.center,
              children: [
                _Chip(
                    label: '🧾 Raj ko Apple ka bill',
                    onTap: () => _go('Raj ko 10 apple ka sale bill banao')),
                _Chip(
                    label: '📋 Sab bills dikhao',
                    onTap: () => _go('Sab sale bills dikhao')),
                _Chip(
                    label: '📦 Item transactions',
                    onTap: () => _go('Apple ka transaction dikhao')),
                _Chip(
                    label: '🍎 Item add karo',
                    onTap: () => _go('Apple item add karo')),
                _Chip(
                    label: '👤 Customer add karo',
                    onTap: () => _go('Raj customer add karo')),
                _Chip(
                    label: '💰 Unpaid bills',
                    onTap: () => _go('Sab unpaid bills dikhao')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _go(String text) =>
      context.read<ChatBloc>().add(SendMessageEvent(text));

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Tap to start/stop recording
            GestureDetector(
              onTap: _speechAvailable
                  ? () {
                      if (_isListening) {
                        _stopAndSend();
                      } else {
                        _startListening();
                      }
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: _isListening
                      ? app_colors.c_primary
                      : app_colors.backgroun_color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isListening
                        ? app_colors.c_primary
                        : app_colors.border_color,
                  ),
                  boxShadow: _isListening
                      ? [
                    BoxShadow(
                      color: app_colors.c_primary.withOpacity(0.35),
                      blurRadius: 12,
                      spreadRadius: 4,
                    )
                  ]
                      : [],
                ),
                child: _isListening
                    ? Icon(
                        Icons.stop_rounded,
                        size: 20.sp,
                        color: Colors.white,
                      )
                    : Icon(
                  Icons.mic_none_rounded,
                  size: 20.sp,
                  color: _speechAvailable
                      ? app_colors.c_primary
                      : Colors.grey,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: app_colors.backgroun_color,
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(
                    color: _isListening ? app_colors.c_primary : app_colors.border_color,
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _send(),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  style: TextStyle(fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: _isListening
                        ? 'Sun raha hoon... rok ne ke liye mic dabao 🎤'
                        : 'Bill banao, items, customers...',
                    hintStyle: TextStyle(
                        fontSize: 13.sp,
                        color: _isListening ? app_colors.c_primary : Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w, vertical: 10.h),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            // While recording: show animated stop icon; else show send
            _isListening
                ? GestureDetector(
              onTap: _stopAndSend,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: app_colors.c_primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: app_colors.c_primary.withOpacity(0.35),
                      blurRadius: 12,
                      spreadRadius: 4,
                    )
                  ],
                ),
                child: Icon(Icons.send_rounded,
                    color: Colors.white, size: 20.sp),
              ),
            )
                : GestureDetector(
              onTap: _send,
              child: Container(
                width: 44.w,
                height: 44.w,
                decoration: const BoxDecoration(
                    color: app_colors.c_primary, shape: BoxShape.circle),
                child: Icon(Icons.send_rounded,
                    color: Colors.white, size: 20.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Pulsing mic animation shown while recording
class _PulsingMic extends StatefulWidget {
  final double size;
  const _PulsingMic({required this.size});
  @override
  State<_PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<_PulsingMic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.15).animate(
        CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Icon(Icons.mic_rounded, size: widget.size, color: Colors.white),
    );
  }
}

// ─── User bubble ──────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h, left: 60.w),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: app_colors.c_primary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.r),
            topRight: Radius.circular(16.r),
            bottomLeft: Radius.circular(16.r),
            bottomRight: Radius.circular(4.r),
          ),
        ),
        child: Text(text,
            style: TextStyle(color: Colors.white, fontSize: 14.sp)),
      ),
    );
  }
}

// ─── AI bubble ────────────────────────────────────────────────────

class _AiBubble extends StatelessWidget {
  final String text;
  final List<Map<String, dynamic>>? tableData;
  final Map<String, dynamic>? detailCard;
  final bool isCustomerNotFound;
  final bool isSubscriptionRequired;

  const _AiBubble({
    required this.text,
    this.tableData,
    this.detailCard,
    this.isCustomerNotFound = false,
    this.isSubscriptionRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final isBill = detailCard?['type'] == 'sale_bill' || detailCard?['type'] == 'purchase_bill';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h, right: 16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text reply bubble
            Container(
              padding:
              EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isSubscriptionRequired
                    ? const Color(0xFFFFF8E1)
                    : isCustomerNotFound
                    ? const Color(0xFFFFF1F1)
                    : app_colors.table_header_bg,
                border: isSubscriptionRequired
                    ? Border.all(color: const Color(0xFFD97706))
                    : isCustomerNotFound
                    ? Border.all(color: const Color(0xFFFFCDD2))
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4.r),
                  topRight: Radius.circular(16.r),
                  bottomLeft: Radius.circular(16.r),
                  bottomRight: Radius.circular(16.r),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSubscriptionRequired) ...[
                    Icon(Icons.lock_rounded, size: 16.sp, color: const Color(0xFFD97706)),
                    SizedBox(width: 6.w),
                  ] else if (isCustomerNotFound) ...[
                    Icon(Icons.person_off_rounded,
                        size: 16.sp, color: Colors.red[600]),
                    SizedBox(width: 6.w),
                  ],
                  Flexible(
                    child: Text(text,
                        style: TextStyle(
                            fontSize: 14.sp,
                            color: isSubscriptionRequired
                                ? const Color(0xFF92400E)
                                : isCustomerNotFound
                                ? Colors.red[700]
                                : app_colors.title)),
                  ),
                ],
              ),
            ),

            // Subscription required → upgrade card
            if (isSubscriptionRequired) ...[
              SizedBox(height: 8.h),
              _SubscriptionUpgradeCard(),
            ],

            // Customer not found → customer list table
            if (isCustomerNotFound && tableData != null && tableData!.isNotEmpty) ...[
              SizedBox(height: 8.h),
              _CustomerNotFoundTable(customers: tableData!),
            ],

            // Sale bill card with PDF button
            if (isBill && detailCard != null) ...[
              SizedBox(height: 8.h),
              _SaleBillCard(
                  detail: detailCard!, lineItems: tableData),
            ] else if (!isCustomerNotFound && !isSubscriptionRequired) ...[
              // Generic detail card (item/customer)
              if (detailCard != null && detailCard!.isNotEmpty) ...[
                SizedBox(height: 8.h),
                _DetailCard(data: detailCard!),
              ],
              // Generic table (list views / transactions)
              if (tableData != null && tableData!.isNotEmpty) ...[
                SizedBox(height: 8.h),
                _DynamicTable(data: tableData!),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Customer Not Found — special table ───────────────────────────

// ─── Subscription Required — Upgrade Card ─────────────────────────

class _SubscriptionUpgradeCard extends StatelessWidget {
  const _SubscriptionUpgradeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFF3CD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFD97706), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.workspace_premium_rounded,
                    color: const Color(0xFFD97706), size: 22.sp),
              ),
              SizedBox(width: 10.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Free Limit Khatam!',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.sp,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                  Text(
                    'Upgrade karo — unlimited bills banao',
                    style: TextStyle(fontSize: 11.sp, color: const Color(0xFF92400E)),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: _PlanChip(
                  title: 'Silver',
                  price: '₹99',
                  sub: '6 Mahine',
                  color: const Color(0xFF64748B),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _PlanChip(
                  title: 'Gold',
                  price: '₹199',
                  sub: '1 Saal',
                  color: const Color(0xFFD97706),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            height: 44.h,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SubscriptionScreen(limitReached: true),
                  ),
                );
              },
              icon: Icon(Icons.rocket_launch_rounded, size: 18.sp),
              label: Text(
                'Upgrade Karo',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.sp),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  final String title;
  final String price;
  final String sub;
  final Color color;
  const _PlanChip({required this.title, required this.price, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 10.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.sp, color: color)),
          Text(price, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp, color: color)),
          Text(sub, style: TextStyle(fontSize: 10.sp, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }
}

// ─── Customer Not Found — special table ───────────────────────────

class _CustomerNotFoundTable extends StatelessWidget {
  final List<Map<String, dynamic>> customers;
  const _CustomerNotFoundTable({required this.customers});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFFFCDD2)),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10.r),
                topRight: Radius.circular(10.r),
              ),
            ),
            child: Row(children: [
              Icon(Icons.group_rounded, size: 14.sp, color: Colors.red[600]),
              SizedBox(width: 6.w),
              Text('Aapke Customers',
                  style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[700])),
            ]),
          ),
          // Column headers
          Container(
            padding:
            EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: app_colors.table_header_bg,
              border: const Border(
                  top: BorderSide(color: Color(0xFFFFCDD2))),
            ),
            child: Row(children: [
              Expanded(
                  flex: 3,
                  child: Text('Name',
                      style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: app_colors.title))),
              Expanded(
                  flex: 2,
                  child: Text('Phone',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: app_colors.title))),
              Expanded(
                  flex: 2,
                  child: Text('State',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: app_colors.title))),
            ]),
          ),
          // Data rows
          ...customers.asMap().entries.map((e) => Container(
            padding: EdgeInsets.symmetric(
                horizontal: 12.w, vertical: 9.h),
            decoration: BoxDecoration(
              color: e.key.isEven
                  ? Colors.white
                  : const Color(0xFFFFF8F8),
              border: const Border(
                  top: BorderSide(color: Color(0xFFFFCDD2))),
            ),
            child: Row(children: [
              Expanded(
                  flex: 3,
                  child: Text(
                      e.value['name']?.toString() ?? '-',
                      style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: app_colors.title))),
              Expanded(
                  flex: 2,
                  child: Text(
                      e.value['phone']?.toString() ?? '-',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.grey[600]))),
              Expanded(
                  flex: 2,
                  child: Text(
                      e.value['state']?.toString() ?? '-',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.grey[600]))),
            ]),
          )),
        ],
      ),
    );
  }
}

// ─── Sale Bill Card with PDF button ───────────────────────────────

class _SaleBillCard extends StatefulWidget {
  final Map<String, dynamic> detail;
  final List<Map<String, dynamic>>? lineItems;
  const _SaleBillCard({required this.detail, this.lineItems});

  @override
  State<_SaleBillCard> createState() => _SaleBillCardState();
}

class _SaleBillCardState extends State<_SaleBillCard> {
  bool _pdfLoading = false;

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'paid':    return Colors.green.shade600;
      case 'unpaid':  return Colors.red.shade600;
      case 'partial': return Colors.orange.shade600;
      default:        return Colors.grey.shade600;
    }
  }

  // ── PDF template chooser bottom sheet ────────────────────────────
  Future<void> _downloadPdf() async {
    final chosen = await showModalBottomSheet<BillTemplate>(
      context: context,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (_) => _PdfTemplateSheet(),
    );
    if (chosen == null) return; // user dismissed

    setState(() => _pdfLoading = true);
    try {
      await BillPdfService.generateAndShare(
        billDetail: widget.detail,
        lineItems: widget.lineItems ?? [],
        template: chosen,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF error: $e')));
      }
    } finally {
      if (mounted) setState(() => _pdfLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final status = d['Status'] ?? '';
    final items = widget.lineItems ?? [];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: app_colors.border_color),
        borderRadius: BorderRadius.circular(12.r),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding:
            EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: app_colors.c_primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12.r),
                topRight: Radius.circular(12.r),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(d['Bill No'] ?? '',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700)),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                      color: _statusColor(status),
                      borderRadius: BorderRadius.circular(20.r)),
                  child: Text(status.toUpperCase(),
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          // Meta info
          Padding(
            padding:
            EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            child: Column(children: [
              _row(d['type'] == 'purchase_bill' ? 'Supplier' : 'Customer', d['Customer'] ?? d['Supplier'] ?? '-'),
              _row('Date', d['Date'] ?? '-'),
              _row('Payment', d['Payment'] ?? '-'),
              if ((d['Notes'] ?? '-') != '-')
                _row('Notes', d['Notes']!),
            ]),
          ),

          // Line items
          if (items.isNotEmpty) ...[
            Divider(height: 1, color: app_colors.border_color),
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 6.h),
              child: Text('Items',
                  style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: app_colors.title)),
            ),
            // items header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: Row(children: [
                _th('Item', flex: 4, align: TextAlign.left),
                _th('Qty', flex: 1),
                _th('Price', flex: 2),
                _th('Tax', flex: 1),
                _th('Total', flex: 2),
              ]),
            ),
            ...items.asMap().entries.map((e) => Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 14.w, vertical: 7.h),
              color: e.key.isEven
                  ? Colors.white
                  : const Color(0xFFF8FAFF),
              child: Row(children: [
                _td(e.value['Item'] ?? e.value['item'], flex: 4, align: TextAlign.left),
                _td(e.value['Qty'] ?? e.value['qty'], flex: 1),
                _td(e.value['Price'] ?? e.value['price'], flex: 2),
                _td(e.value['Tax'] ?? e.value['tax'], flex: 1),
                _td(e.value['Total'] ?? e.value['total'], flex: 2, bold: true),
              ]),
            )),
            SizedBox(height: 4.h),
          ],

          // Totals
          Divider(height: 1, color: app_colors.border_color),
          Padding(
            padding:
            EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            child: Column(children: [
              _totalRow('Subtotal', d['Subtotal'] ?? '-', bold: false),
              SizedBox(height: 4.h),
              _totalRow('GST', d['GST'] ?? '-', bold: false),
              Divider(height: 12, color: app_colors.border_color),
              _totalRow('Total', d['Total'] ?? '-', bold: true),
            ]),
          ),

          // ✅ PDF Download button
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              border:
              Border(top: BorderSide(color: app_colors.border_color)),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12.r),
                bottomRight: Radius.circular(12.r),
              ),
            ),
            child: TextButton.icon(
              onPressed: _pdfLoading ? null : _downloadPdf,
              icon: _pdfLoading
                  ? SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: app_colors.c_primary))
                  : Icon(Icons.picture_as_pdf_rounded,
                  size: 18.sp, color: app_colors.c_primary),
              label: Text(
                _pdfLoading ? 'PDF bana raha hai...' : 'PDF Download karo',
                style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: app_colors.c_primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 72.w,
            child: Text(label,
                style:
                TextStyle(fontSize: 11.sp, color: Colors.grey[500]))),
        SizedBox(width: 6.w),
        Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _th(String t, {required int flex, TextAlign align = TextAlign.right}) =>
      Expanded(
          flex: flex,
          child: Text(t,
              textAlign: align,
              style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500])));

  Widget _td(dynamic v, {required int flex, TextAlign align = TextAlign.right, bool bold = false}) =>
      Expanded(
          flex: flex,
          child: Text(v?.toString() ?? '-',
              textAlign: align,
              style: TextStyle(
                  fontSize: 11.sp,
                  color: bold ? app_colors.c_primary : Colors.black87,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.normal)));

  Widget _totalRow(String label, String value, {required bool bold}) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(
                fontSize: 12.sp,
                color: bold ? Colors.black : Colors.grey[600],
                fontWeight:
                bold ? FontWeight.w700 : FontWeight.normal)),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 14.sp : 12.sp,
                color: bold ? app_colors.c_primary : Colors.black87,
                fontWeight:
                bold ? FontWeight.w700 : FontWeight.normal)),
      ]);
}

// ─── PDF Template Chooser Sheet ──────────────────────────────────

class _PdfTemplateSheet extends StatelessWidget {
  const _PdfTemplateSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r)),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'PDF Template Chuniye',
            style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: app_colors.title),
          ),
          SizedBox(height: 4.h),
          Text('Aapki bill PDF ka design select karein',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[500])),
          SizedBox(height: 16.h),
          _TemplateOption(
            template: BillTemplate.modern,
            icon: Icons.credit_card_rounded,
            color: const Color(0xFF2563EB),
            title: 'Modern',
            subtitle: 'Blue header • Professional look • Best for business',
          ),
          SizedBox(height: 10.h),
          _TemplateOption(
            template: BillTemplate.classic,
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF15803D),
            title: 'Classic',
            subtitle: 'Green theme • Traditional style • Tax Invoice format',
          ),
          SizedBox(height: 10.h),
          _TemplateOption(
            template: BillTemplate.minimal,
            icon: Icons.article_outlined,
            color: const Color(0xFF374151),
            title: 'Minimal',
            subtitle: 'Black & White • Print-friendly • Clean & simple',
          ),
        ],
      ),
    );
  }
}

class _TemplateOption extends StatelessWidget {
  final BillTemplate template;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _TemplateOption({
    required this.template,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12.r),
      onTap: () => Navigator.pop(context, template),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12.r),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10.r)),
              child: Icon(icon, color: color, size: 20.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: color)),
                  SizedBox(height: 2.h),
                  Text(subtitle,
                      style:
                      TextStyle(fontSize: 11.sp, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20.sp),
          ],
        ),
      ),
    );
  }
}

// ─── Generic detail card ──────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DetailCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final entries =
    data.entries.where((e) => e.key != 'type').toList();
    final isCustomer = data['type'] == 'customer';
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: app_colors.border_color),
        borderRadius: BorderRadius.circular(10.r),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: app_colors.c_primary.withOpacity(0.08),
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10.r),
                  topRight: Radius.circular(10.r)),
            ),
            child: Text(
                isCustomer ? '👤 Customer Detail' : '📦 Item Detail',
                style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: app_colors.c_primary)),
          ),
          ...entries.map((e) => Container(
            padding: EdgeInsets.symmetric(
                horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: app_colors.border_color))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                    width: 80.w,
                    child: Text(e.key,
                        style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500))),
                SizedBox(width: 8.w),
                Expanded(
                    child: Text(e.value?.toString() ?? '-',
                        style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.black87))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ─── Dynamic table ────────────────────────────────────────────────

class _DynamicTable extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _DynamicTable({required this.data});

  static const _labelMap = {
    'name': 'Name', 'qty': 'Qty', 'price': 'Price',
    'hsn_code': 'HSN', 'phone': 'Phone', 'email': 'Email',
    'gst_number': 'GST', 'state': 'State', 'bill_number': 'Bill No',
    'bill': 'Bill', 'customer': 'Customer', 'date': 'Date',
    'total': 'Total', 'status': 'Status', 'item': 'Item', 'tax': 'Tax',
  };

  @override
  Widget build(BuildContext context) {
    final cols = data.first.keys.toList();
    final headers = cols.map((k) => _labelMap[k] ?? k).toList();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: app_colors.border_color),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: 8.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: app_colors.table_header_bg,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10.r),
                  topRight: Radius.circular(10.r)),
            ),
            child: Row(
              children: headers
                  .asMap()
                  .entries
                  .map((e) => Expanded(
                child: Text(e.value,
                    style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: app_colors.title),
                    textAlign: e.key == 0
                        ? TextAlign.left
                        : TextAlign.center),
              ))
                  .toList(),
            ),
          ),
          // Data rows
          ...data.asMap().entries.map((e) => Container(
            padding: EdgeInsets.symmetric(
                horizontal: 8.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: e.key.isEven
                  ? Colors.white
                  : const Color(0xFFF7F8FA),
              border: Border(
                  top: BorderSide(
                      color: app_colors.border_color)),
            ),
            child: Row(
              children: cols
                  .asMap()
                  .entries
                  .map((c) => Expanded(
                child: Text(
                    e.value[c.value]?.toString() ?? '-',
                    style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.black87),
                    textAlign: c.key == 0
                        ? TextAlign.left
                        : TextAlign.center,
                    overflow: TextOverflow.ellipsis),
              ))
                  .toList(),
            ),
          )),
          // CSV download
          Container(
            decoration: BoxDecoration(
              color: app_colors.backgroun_color,
              border: Border(
                  top:
                  BorderSide(color: app_colors.border_color)),
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(10.r),
                  bottomRight: Radius.circular(10.r)),
            ),
            child: TextButton.icon(
              onPressed: () => _exportCsv(context, cols, headers),
              icon: Icon(Icons.download_rounded,
                  size: 16.sp, color: app_colors.c_primary),
              label: Text('CSV download karo',
                  style: TextStyle(
                      fontSize: 12.sp,
                      color: app_colors.c_primary)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext ctx, List<String> cols,
      List<String> headers) async {
    try {
      final rows = data
          .map((r) => cols
          .map((c) =>
      '"${r[c]?.toString().replaceAll('"', '""') ?? ''}"')
          .join(','))
          .join('\n');
      final file = File(
          '${(await getTemporaryDirectory()).path}/apnaca_export.csv');
      await file.writeAsString('${headers.join(',')}\n$rows');
      await Share.shareXFiles(
          [XFile(file.path, mimeType: 'text/csv')],
          subject: 'ApnaCA Export');
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text('Export failed: $e')));
      }
    }
  }
}

// ─── Typing indicator ─────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding:
        EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
            color: app_colors.table_header_bg,
            borderRadius: BorderRadius.circular(16.r)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _Dot(_ctrl, 0.0),
          SizedBox(width: 4.w),
          _Dot(_ctrl, 0.25),
          SizedBox(width: 4.w),
          _Dot(_ctrl, 0.5),
        ]),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final AnimationController c;
  final double d;
  const _Dot(this.c, this.d);
  @override
  Widget build(BuildContext context) {
    final a = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.3), weight: 1),
    ]).animate(CurvedAnimation(
        parent: c,
        curve: Interval(d, (d + 0.5).clamp(0.0, 1.0),
            curve: Curves.easeInOut)));
    return AnimatedBuilder(
        animation: a,
        builder: (_, __) => Opacity(
            opacity: a.value,
            child: Container(
                width: 7.w,
                height: 7.w,
                decoration: const BoxDecoration(
                    color: app_colors.c_primary,
                    shape: BoxShape.circle))));
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: app_colors.LightBlue,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
              color: app_colors.c_primary.withOpacity(0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.sp, color: app_colors.c_primary)),
      ),
    );
  }
}