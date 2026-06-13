import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../database/app_database.dart';
import '../../model/ledger_entry_model.dart';

class PartyDetailScreen extends StatefulWidget {
  final int partyId;
  final String partyType;
  final String partyName;

  const PartyDetailScreen({
    super.key,
    required this.partyId,
    required this.partyType,
    required this.partyName,
  });

  @override
  State<PartyDetailScreen> createState() => _PartyDetailScreenState();
}

class _PartyDetailScreenState extends State<PartyDetailScreen> {
  List<Map<String, dynamic>> _entries = [];
  double _balance = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final entries = await AppDatabase.instance
        .getLedgerByParty(widget.partyType, widget.partyId);
    final balance = await AppDatabase.instance
        .getPartyBalance(widget.partyType, widget.partyId);
    setState(() {
      _entries  = entries;
      _balance  = balance;
      _isLoading = false;
    });
  }

  String _formatDate(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _addTransaction(String type) async {
    final amountCtrl = TextEditingController();
    final notesCtrl  = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final confirm = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  type == 'debit' ? '➕ Debit (Amount to Receive)' : '➖ Credit (Amount to Pay)',
                  style: TextStyle(
                    fontFamily: app_fonts.Bold,
                    fontSize: 16.sp,
                    color: type == 'debit' ? app_colors.GreenColor : app_colors.c_danger,
                  ),
                ),
                SizedBox(height: 16.h),
                TextField(
                  controller: amountCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: InputDecoration(
                    labelText: 'Amount (₹)',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: const BorderSide(color: app_colors.c_primary),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: const BorderSide(color: app_colors.c_primary),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setBS(() => selectedDate = picked);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: app_colors.c_primary),
                        SizedBox(width: 8.w),
                        Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          style: TextStyle(fontFamily: app_fonts.Regular, fontSize: 13.sp),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                SizedBox(
                  width: double.infinity,
                  height: 46.h,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: type == 'debit' ? app_colors.GreenColor : app_colors.c_danger,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                    child: Text(
                      'Save Entry',
                      style: TextStyle(
                        fontFamily: app_fonts.Medium,
                        fontSize: 15.sp,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirm == true) {
      final amount = double.tryParse(amountCtrl.text.trim());
      if (amount == null || amount <= 0) return;
      await AppDatabase.instance.insertLedgerEntry({
        'party_type': widget.partyType,
        'party_id':   widget.partyId,
        'party_name': widget.partyName,
        'date':       selectedDate.toIso8601String().split('T')[0],
        'amount':     amount,
        'type':       type,
        'notes':      notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
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
              widget.partyName,
              style: TextStyle(fontFamily: app_fonts.Bold, fontSize: 15.sp, color: Colors.black),
            ),
            Text(
              widget.partyType == 'customer' ? 'Customer Ledger' : 'Supplier Ledger',
              style: TextStyle(fontFamily: app_fonts.Regular, fontSize: 11.sp, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.black), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildBalanceBanner(),
                _buildActionButtons(),
                Expanded(child: _buildEntryList()),
              ],
            ),
    );
  }

  Widget _buildBalanceBanner() {
    final isPositive = _balance >= 0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      color: isPositive
          ? app_colors.GreenColor.withOpacity(0.1)
          : app_colors.c_danger.withOpacity(0.1),
      child: Column(
        children: [
          Text(
            isPositive ? 'You Will Receive' : 'You Will Pay',
            style: TextStyle(
              fontFamily: app_fonts.Regular,
              fontSize: 12.sp,
              color: isPositive ? app_colors.GreenColor : app_colors.c_danger,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '₹${_balance.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontFamily: app_fonts.Bold,
              fontSize: 28.sp,
              color: isPositive ? app_colors.GreenColor : app_colors.c_danger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: EdgeInsets.all(12.w),
      child: Row(
        children: [
          Expanded(
            child: _actionButton(
              label: '+ Debit',
              subtitle: 'Will Receive',
              color: app_colors.GreenColor,
              icon: Icons.arrow_upward,
              onTap: () => _addTransaction('debit'),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _actionButton(
              label: '- Credit',
              subtitle: 'Will Pay',
              color: app_colors.c_danger,
              icon: Icons.arrow_downward,
              onTap: () => _addTransaction('credit'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required String subtitle,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            SizedBox(width: 6.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      fontFamily: app_fonts.Bold,
                      fontSize: 13.sp,
                      color: Colors.white,
                    )),
                Text(subtitle,
                    style: TextStyle(
                      fontFamily: app_fonts.Regular,
                      fontSize: 10.sp,
                      color: Colors.white70,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryList() {
    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey.shade300),
            SizedBox(height: 12.h),
            Text('No transactions yet',
                style: TextStyle(fontFamily: app_fonts.Regular, fontSize: 14.sp, color: Colors.grey)),
            SizedBox(height: 8.h),
            Text('Tap + Debit or - Credit to add entries',
                style: TextStyle(fontFamily: app_fonts.Regular, fontSize: 11.sp, color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    // Calculate running balance
    double running = 0;
    final List<Map<String, dynamic>> enriched = [];
    for (final e in _entries.reversed) {
      final amt  = (e['amount'] as num).toDouble();
      final type = e['type'] as String;
      running += type == 'debit' ? amt : -amt;
      enriched.add({...e, 'running_balance': running});
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      itemCount: enriched.length,
      itemBuilder: (ctx, i) {
        final entry    = enriched[enriched.length - 1 - i];
        final isDebit  = entry['type'] == 'debit';
        final amount   = (entry['amount'] as num).toDouble();
        final running  = (entry['running_balance'] as double);
        final date     = _formatDate(entry['date'] as String? ?? '');
        final notes    = entry['notes'] as String?;
        final billRef  = entry['ref_bill_number'] as String?;
        final id       = entry['id'] as int;

        return Dismissible(
          key: Key('ledger_$id'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 16.w),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) async {
            await AppDatabase.instance.deleteLedgerEntry(id);
            _loadData();
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 8.h),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
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
            child: Row(
              children: [
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: isDebit
                        ? app_colors.GreenColor.withOpacity(0.1)
                        : app_colors.c_danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    isDebit ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isDebit ? app_colors.GreenColor : app_colors.c_danger,
                    size: 16,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDebit ? 'Debit' : 'Credit',
                        style: TextStyle(
                          fontFamily: app_fonts.Medium,
                          fontSize: 13.sp,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        notes != null && notes.isNotEmpty
                            ? '$date • $notes'
                            : billRef != null
                                ? '$date • Ref: $billRef'
                                : date,
                        style: TextStyle(
                          fontFamily: app_fonts.Regular,
                          fontSize: 10.sp,
                          color: Colors.black45,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isDebit ? '+' : '-'} ₹${amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontFamily: app_fonts.Bold,
                        fontSize: 13.sp,
                        color: isDebit ? app_colors.GreenColor : app_colors.c_danger,
                      ),
                    ),
                    Text(
                      'Bal: ₹${running.abs().toStringAsFixed(0)}',
                      style: TextStyle(
                        fontFamily: app_fonts.Regular,
                        fontSize: 10.sp,
                        color: running >= 0 ? app_colors.GreenColor : app_colors.c_danger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
