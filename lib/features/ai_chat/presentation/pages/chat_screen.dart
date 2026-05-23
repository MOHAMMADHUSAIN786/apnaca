import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../bloc/chat_bloc.dart';
import '../../bloc/chat_event.dart';
import '../../bloc/chat_state.dart';
import '../../model/chat_models.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<ChatBloc>().add(SendMessageEvent(text));
    _controller.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: app_colors.table_header_bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: app_colors.title),
          onPressed: () => Navigator.pop(context),
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
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return BlocConsumer<ChatBloc, ChatState>(
      listener: (_, state) => _scrollToBottom(),
      builder: (_, state) {
        List<ChatMessage> messages = [];
        if (state is ChatLoading) messages = state.messages;
        if (state is ChatSuccess) messages = state.messages;
        if (state is ChatError) messages = state.messages;

        if (messages.isEmpty) return _buildEmptyState();

        return ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          itemCount: messages.length + (state is ChatLoading ? 1 : 0),
          itemBuilder: (_, index) {
            if (state is ChatLoading && index == messages.length) {
              return const _TypingIndicator();
            }
            final msg = messages[index];
            if (msg.role == 'user') return _UserBubble(text: msg.content);
            return _AiBubble(
              text: msg.content,
              tableData: msg.tableData,
              detailCard: msg.detailCard,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
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
                _Chip(label: '🍎 Apple item add karo',
                    onTap: () => _sendText('Apple item add karo')),
                _Chip(label: '👤 Customer add karo',
                    onTap: () => _sendText('Mohammad Husain customer add karo')),
                _Chip(label: '📋 Sab items dikhao',
                    onTap: () => _sendText('Sab items dikhao')),
                _Chip(label: '👥 Sab customers dikhao',
                    onTap: () => _sendText('Sab customers dikhao')),
                _Chip(label: '🔍 Apple ki details',
                    onTap: () => _sendText('Apple ki details dikhao')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _sendText(String text) {
    context.read<ChatBloc>().add(SendMessageEvent(text));
    _scrollToBottom();
  }

  Widget _buildInputBar() {
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
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: app_colors.backgroun_color,
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(color: app_colors.border_color),
                ),
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _send(),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  style: TextStyle(fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: 'Item / Customer add, update, delete...',
                    hintStyle:
                    TextStyle(fontSize: 13.sp, color: Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w, vertical: 10.h),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            GestureDetector(
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

// ─── User bubble ─────────────────────────────────────────────────

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

// ─── AI bubble ───────────────────────────────────────────────────

class _AiBubble extends StatelessWidget {
  final String text;
  final List<Map<String, dynamic>>? tableData;
  final Map<String, dynamic>? detailCard;

  const _AiBubble({required this.text, this.tableData, this.detailCard});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h, right: 20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
              EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: app_colors.table_header_bg,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4.r),
                  topRight: Radius.circular(16.r),
                  bottomLeft: Radius.circular(16.r),
                  bottomRight: Radius.circular(16.r),
                ),
              ),
              child: Text(text,
                  style:
                  TextStyle(fontSize: 14.sp, color: app_colors.title)),
            ),
            // Table (list view)
            if (tableData != null && tableData!.isNotEmpty) ...[
              SizedBox(height: 8.h),
              _DynamicTable(data: tableData!),
            ],
            // Detail card (single item/customer)
            if (detailCard != null && detailCard!.isNotEmpty) ...[
              SizedBox(height: 8.h),
              _DetailCard(data: detailCard!),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Dynamic table (items OR customers) ──────────────────────────

class _DynamicTable extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _DynamicTable({required this.data});

  @override
  Widget build(BuildContext context) {
    // Auto-detect columns from first row keys (excluding 'id')
    final allKeys = data.first.keys.where((k) => k != 'id').toList();
    final headers = allKeys.map(_headerLabel).toList();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: app_colors.border_color),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: app_colors.table_header_bg,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10.r),
                topRight: Radius.circular(10.r),
              ),
            ),
            child: Row(
              children: headers
                  .map((h) => Expanded(
                child: Text(h,
                    style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: app_colors.title),
                    textAlign: headers.indexOf(h) == 0
                        ? TextAlign.left
                        : TextAlign.center),
              ))
                  .toList(),
            ),
          ),
          // Rows
          ...data.asMap().entries.map((e) {
            final row = e.value;
            return Container(
              padding:
              EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: e.key.isEven ? Colors.white : const Color(0xFFF7F8FA),
                border: Border(
                    top: BorderSide(color: app_colors.border_color)),
              ),
              child: Row(
                children: allKeys
                    .map((col) => Expanded(
                  child: Text(
                    row[col]?.toString() ?? '-',
                    style: TextStyle(
                        fontSize: 11.sp, color: Colors.black87),
                    textAlign: allKeys.indexOf(col) == 0
                        ? TextAlign.left
                        : TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ))
                    .toList(),
              ),
            );
          }),
          // Download bar
          Container(
            decoration: BoxDecoration(
              color: app_colors.backgroun_color,
              border:
              Border(top: BorderSide(color: app_colors.border_color)),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(10.r),
                bottomRight: Radius.circular(10.r),
              ),
            ),
            child: TextButton.icon(
              onPressed: () => _exportCsv(context, allKeys, headers),
              icon: Icon(Icons.download_rounded,
                  size: 16.sp, color: app_colors.c_primary),
              label: Text('CSV download karo',
                  style:
                  TextStyle(fontSize: 12.sp, color: app_colors.c_primary)),
            ),
          ),
        ],
      ),
    );
  }

  String _headerLabel(String key) {
    const map = {
      'name': 'Name',
      'qty': 'Qty',
      'price': 'Price',
      'hsn_code': 'HSN',
      'phone': 'Phone',
      'email': 'Email',
      'gst_number': 'GST',
      'state': 'State',
      'address': 'Address',
    };
    return map[key] ?? key;
  }

  Future<void> _exportCsv(BuildContext context, List<String> cols,
      List<String> headers) async {
    try {
      final headerRow = headers.join(',');
      final rows = data.map((row) {
        return cols
            .map((c) =>
        '"${row[c]?.toString().replaceAll('"', '""') ?? ''}"')
            .join(',');
      }).join('\n');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/apnaca_export.csv');
      await file.writeAsString('$headerRow\n$rows');

      await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')],
          subject: 'ApnaCA Export');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export failed: $e')));
      }
    }
  }
}

// ─── Detail card (single item or customer) ───────────────────────

class _DetailCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DetailCard({required this.data});

  @override
  Widget build(BuildContext context) {
    // Remove 'type' key — it's internal
    final entries = data.entries
        .where((e) => e.key != 'type')
        .toList();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: app_colors.border_color),
        borderRadius: BorderRadius.circular(10.r),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: app_colors.c_primary.withOpacity(0.08),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10.r),
                topRight: Radius.circular(10.r),
              ),
            ),
            child: Text(
              data['type'] == 'customer' ? '👤 Customer Detail' : '📦 Item Detail',
              style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: app_colors.c_primary),
            ),
          ),
          // Field rows
          ...entries.map((e) => Container(
            padding: EdgeInsets.symmetric(
                horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: app_colors.border_color)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 80.w,
                  child: Text(
                    e.key,
                    style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    e.value?.toString() ?? '-',
                    style: TextStyle(
                        fontSize: 12.sp, color: Colors.black87),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
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
        vsync: this, duration: const Duration(milliseconds: 1200))
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
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
            color: app_colors.table_header_bg,
            borderRadius: BorderRadius.circular(16.r)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(controller: _ctrl, delay: 0.0),
            SizedBox(width: 4.w),
            _Dot(controller: _ctrl, delay: 0.25),
            SizedBox(width: 4.w),
            _Dot(controller: _ctrl, delay: 0.5),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  const _Dot({required this.controller, required this.delay});

  @override
  Widget build(BuildContext context) {
    final anim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.3), weight: 1),
    ]).animate(CurvedAnimation(
        parent: controller,
        curve: Interval(delay, (delay + 0.5).clamp(0.0, 1.0),
            curve: Curves.easeInOut)));

    return AnimatedBuilder(
        animation: anim,
        builder: (_, __) => Opacity(
          opacity: anim.value,
          child: Container(
              width: 7.w,
              height: 7.w,
              decoration: const BoxDecoration(
                  color: app_colors.c_primary, shape: BoxShape.circle)),
        ));
  }
}

// ─── Suggestion chip ─────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: app_colors.LightBlue,
          borderRadius: BorderRadius.circular(20.r),
          border:
          Border.all(color: app_colors.c_primary.withOpacity(0.3)),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12.sp, color: app_colors.c_primary)),
      ),
    );
  }
}
