import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/app_status_bar.dart';
import '../../../../database/app_database.dart';
import 'create_quotation_screen.dart';
import 'quotation_detail_screen.dart';

class QuotationScreen extends StatefulWidget {
  const QuotationScreen({super.key});

  @override
  State<QuotationScreen> createState() => _QuotationScreenState();
}

class _QuotationScreenState extends State<QuotationScreen> {
  List<Map<String, dynamic>> _quotations = [];
  bool _isLoading = true;

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
    final list = await AppDatabase.instance.getAllQuotations();
    setState(() {
      _quotations = list;
      _isLoading  = false;
    });
  }

  String _formatDate(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  bool _isExpired(Map<String, dynamic> q) {
    final expiry = q['expiry_date'] as String?;
    if (expiry == null) return false;
    final d = DateTime.tryParse(expiry);
    return d != null && d.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return AppStatusBarUtils(
      color: app_colors.table_header_bg,
      child: Scaffold(
        backgroundColor: app_colors.white,
        appBar: AppBar(
          backgroundColor: app_colors.table_header_bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Quotation / Estimate',
            style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 16.sp, color: Colors.black),
          ),
          actions: [
            IconButton(icon: const Icon(Icons.refresh, color: Colors.black), onPressed: _loadData),
          ],
        ),
        body: _buildBody(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateQuotationScreen()),
            );
            _loadData();
          },
          backgroundColor: app_colors.c_primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text('New Quote',
              style: TextStyle(fontFamily: app_fonts.Medium, color: Colors.white, fontSize: 13.sp)),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_quotations.isEmpty) {
      return _buildEmpty();
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.only(top: 18, left: 8, right: 8, bottom: 80.h),
            itemCount: _quotations.length,
            itemBuilder: (ctx, i) => _buildQuotationCard(_quotations[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade300),
          SizedBox(height: 12.h),
          Text('No quotations yet',
              style: TextStyle(fontFamily: app_fonts.Regular, fontSize: 14.sp, color: Colors.grey)),
          SizedBox(height: 6.h),
          Text('Create a quote and convert to bill with 1 tap!',
              style: TextStyle(fontFamily: app_fonts.Regular, fontSize: 11.sp, color: Colors.grey.shade400),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildQuotationCard(Map<String, dynamic> q) {
    final status     = q['status'] as String? ?? 'draft';
    final statusColor = _statusColors[status] ?? Colors.grey;
    final number     = q['quotation_number'] as String? ?? '';
    final customer   = q['cust_name'] as String? ?? q['customer_name'] as String? ?? 'Walk-in';
    final date       = _formatDate(q['quotation_date'] as String? ?? '');
    final total      = (q['total_amount'] as num?)?.toDouble() ?? 0;
    final expiry     = q['expiry_date'] as String?;
    final expired    = _isExpired(q);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuotationDetailScreen(quotationId: q['id'] as int),
          ),
        );
        _loadData();
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        number,
                        style: TextStyle(
                          fontFamily: app_fonts.Bold,
                          fontSize: 14.sp,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 12, color: Colors.black45),
                          SizedBox(width: 4.w),
                          Text(
                            customer,
                            style: TextStyle(
                              fontFamily: app_fonts.Regular,
                              fontSize: 12.sp,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontFamily: app_fonts.Medium,
                      fontSize: 10.sp,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            SizedBox(height: 10.h),
            Row(
              children: [
                _infoChip(Icons.calendar_today, date),
                if (expiry != null) ...[
                  SizedBox(width: 8.w),
                  _infoChip(
                    Icons.timer_outlined,
                    'Exp: ${_formatDate(expiry)}',
                    color: expired ? Colors.red : Colors.black45,
                  ),
                ],
                const Spacer(),
                Text(
                  '₹${total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontFamily: app_fonts.Bold,
                    fontSize: 16.sp,
                    color: app_colors.c_primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, {Color color = Colors.black45}) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        SizedBox(width: 4.w),
        Text(
          label,
          style: TextStyle(
            fontFamily: app_fonts.Regular,
            fontSize: 11.sp,
            color: color,
          ),
        ),
      ],
    );
  }
}
