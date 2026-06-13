import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../database/app_database.dart';

class QuotationDetailScreen extends StatefulWidget {
  final int quotationId;
  const QuotationDetailScreen({super.key, required this.quotationId});

  @override
  State<QuotationDetailScreen> createState() => _QuotationDetailScreenState();
}

class _QuotationDetailScreenState extends State<QuotationDetailScreen> {
  Map<String, dynamic>? _quotation;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _isConverting = false;

  static const Map<String, Color> _statusColors = {
    'draft':     Color(0xFF9E9E9E),
    'sent':      Color(0xFF2196F3),
    'accepted':  Color(0xFF4CAF50),
    'rejected':  Color(0xFFF44336),
    'converted': Color(0xFF9C27B0),
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final q = await AppDatabase.instance.getQuotationById(widget.quotationId);
    final items = await AppDatabase.instance.getQuotationItems(widget.quotationId);
    setState(() {
      _quotation = q;
      _items     = items;
      _isLoading = false;
    });
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _convertToBill() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Row(
          children: [
            const Icon(Icons.transform, color: Color(0xFF9C27B0)),
            SizedBox(width: 8.w),
            const Text('Convert to Bill'),
          ],
        ),
        content: const Text(
            'This will create a Sale Bill from this quotation and mark it as converted. Stock will be deducted. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: app_colors.c_primary),
            child: const Text('Convert', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isConverting = true);
    try {
      final billId = await AppDatabase.instance
          .convertQuotationToSaleBill(widget.quotationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Sale Bill created! (Bill ID: $billId)'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isConverting = false);
  }

  Future<void> _updateStatus(String status) async {
    await AppDatabase.instance.updateQuotationStatus(widget.quotationId, status);
    _loadData();
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quotation'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AppDatabase.instance.deleteQuotation(widget.quotationId);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_quotation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quotation')),
        body: const Center(child: Text('Quotation not found')),
      );
    }

    final q          = _quotation!;
    final status     = q['status'] as String? ?? 'draft';
    final statusColor = _statusColors[status] ?? Colors.grey;
    final isConverted = status == 'converted';
    final customer   = q['cust_name'] as String? ?? q['customer_name'] as String? ?? 'Walk-in';
    final total      = (q['total_amount'] as num?)?.toDouble() ?? 0;
    final subtotal   = (q['subtotal'] as num?)?.toDouble() ?? 0;
    final gst        = (q['gst_amount'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: app_colors.table_header_bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              q['quotation_number'] as String? ?? '',
              style: TextStyle(fontFamily: app_fonts.Bold, fontSize: 15.sp, color: Colors.black),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontFamily: app_fonts.Medium,
                  fontSize: 9.sp,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _delete();
              else _updateStatus(value);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'sent',     child: Text('Mark as Sent')),
              const PopupMenuItem(value: 'accepted', child: Text('Mark as Accepted')),
              const PopupMenuItem(value: 'rejected', child: Text('Mark as Rejected')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'delete',   child: Text('Delete', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(14.w),
        children: [
          // Header info
          _infoCard(customer, q),
          SizedBox(height: 12.h),
          // Items
          _itemsCard(),
          SizedBox(height: 12.h),
          // Totals
          _totalsCard(subtotal, gst, total),
          if (q['notes'] != null && (q['notes'] as String).isNotEmpty) ...[
            SizedBox(height: 12.h),
            _notesCard(q['notes'] as String),
          ],
          SizedBox(height: 80.h),
        ],
      ),
      bottomNavigationBar: isConverted
          ? Container(
              padding: EdgeInsets.all(16.w),
              color: Colors.white,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE7F6),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF9C27B0), size: 18),
                    SizedBox(width: 8.w),
                    Text(
                      'Converted to Sale Bill',
                      style: TextStyle(
                        fontFamily: app_fonts.Medium,
                        fontSize: 14.sp,
                        color: const Color(0xFF9C27B0),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Container(
              padding: EdgeInsets.all(16.w),
              color: Colors.white,
              child: SizedBox(
                height: 48.h,
                child: ElevatedButton.icon(
                  onPressed: _isConverting ? null : _convertToBill,
                  icon: _isConverting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.transform, color: Colors.white),
                  label: Text(
                    _isConverting ? 'Converting...' : '🧾 Convert to Sale Bill',
                    style: TextStyle(
                      fontFamily: app_fonts.Medium,
                      fontSize: 15.sp,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: app_colors.c_primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    elevation: 2,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _infoCard(String customer, Map<String, dynamic> q) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          _infoRow('Customer',       customer),
          _infoRow('Quote Date',     _formatDate(q['quotation_date'] as String?)),
          _infoRow('Expiry Date',    _formatDate(q['expiry_date'] as String?)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(fontFamily: app_fonts.Regular, fontSize: 12.sp, color: Colors.black45)),
          const Spacer(),
          Text(value,
              style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 13.sp, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _itemsCard() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ITEMS',
              style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 11.sp, color: Colors.black45)),
          SizedBox(height: 10.h),
          ..._items.map((item) {
            final name  = item['item_name'] as String? ?? '';
            final qty   = (item['qty'] as num?)?.toDouble() ?? 0;
            final price = (item['unit_price'] as num?)?.toDouble() ?? 0;
            final total = (item['line_total'] as num?)?.toDouble() ?? 0;
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 6.h),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 13.sp)),
                        Text(
                          '₹${price.toStringAsFixed(0)} × ${qty.toStringAsFixed(0)}',
                          style: TextStyle(fontFamily: app_fonts.Regular, fontSize: 11.sp, color: Colors.black45),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${total.toStringAsFixed(2)}',
                    style: TextStyle(fontFamily: app_fonts.Bold, fontSize: 13.sp, color: app_colors.c_primary),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _totalsCard(double subtotal, double gst, double total) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2490EF), Color(0xFF1A6BB5)]),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          _totalRow('Subtotal',     '₹${subtotal.toStringAsFixed(2)}', false),
          SizedBox(height: 4.h),
          _totalRow('GST',         '₹${gst.toStringAsFixed(2)}',     false),
          const Divider(color: Colors.white30, height: 16),
          _totalRow('Total',       '₹${total.toStringAsFixed(2)}',   true),
        ],
      ),
    );
  }

  Widget _totalRow(String l, String v, bool bold) {
    final style = TextStyle(
      fontFamily: bold ? app_fonts.Bold : app_fonts.Regular,
      fontSize: bold ? 16.sp : 13.sp,
      color: Colors.white,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(l, style: style), Text(v, style: style)],
    );
  }

  Widget _notesCard(String notes) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NOTES', style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 11.sp, color: Colors.black45)),
          SizedBox(height: 8.h),
          Text(notes, style: TextStyle(fontFamily: app_fonts.Regular, fontSize: 13.sp, color: Colors.black87)),
        ],
      ),
    );
  }
}
