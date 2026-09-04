// lib/features/sale/presentation/widgets/app_sale_bill_item.dart
// UPDATED: Permission guards on edit/delete popup items

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/permission_service.dart'; // ← NEW
import '../../../../database/app_database.dart';
import '../../../../features/sale/presentation/bloc/sale_bloc.dart';
import '../../../../features/sale/presentation/bloc/sale_event.dart';
import '../../../ai_chat/service/bill_pdf_service.dart';

class AppSaleBillItem extends StatelessWidget {
  final int billId;
  final String billNumber;
  final String partyName;
  final String billDate;
  final String totalAmount;
  final String paymentStatus;
  final VoidCallback? onBillUpdated;

  const AppSaleBillItem({
    super.key,
    required this.billId,
    required this.billNumber,
    required this.partyName,
    required this.billDate,
    required this.totalAmount,
    required this.paymentStatus,
    this.onBillUpdated,
  });

  // ── DELETE ───────────────────────────────────────────────────
  Future<void> _deleteBill(BuildContext context) async {
    // ← Permission check
    if (!PermissionService.instance.canDeleteSaleBills) {
      showPermissionDeniedSnackBar(context, 'Sale Bill Delete');
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Bill'),
        content: Text('Are you sure you want to delete bill $billNumber?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    final db = AppDatabase.instance;
    await db.deleteSaleBillWithStockRestore(billId);

    if (context.mounted) {
      context.read<SaleBloc>().add(FetchSaleBills());
      onBillUpdated?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bill $billNumber deleted successfully')),
      );
    }
  }

  // ── VIEW ─────────────────────────────────────────────────────
  Future<void> _viewBill(BuildContext context) async {
    final db = AppDatabase.instance;
    final billDetailMap = await db.getSaleBillById(billId);
    if (billDetailMap == null) return;

    final lineItemsMap = await db.getSaleBillItems(billId);

    final billDetail = {
      'Bill No':  billDetailMap['bill_number'],
      'Customer': partyName,
      'Date':     billDate,
      'Payment':  billDetailMap['payment_mode'] ?? 'cash',
      'Status':   paymentStatus,
      'Subtotal': '₹${billDetailMap['subtotal']?.toStringAsFixed(2) ?? '0.00'}',
      'GST':      '₹${billDetailMap['gst_amount']?.toStringAsFixed(2) ?? '0.00'}',
      'Total':    '₹${billDetailMap['total_amount']?.toStringAsFixed(2) ?? '0.00'}',
      'Notes':    billDetailMap['notes'] ?? '',
    };

    final lineItems = lineItemsMap.map((item) {
      final taxAmount = item['tax_amount'] as num? ?? 0;
      final lineTotal = item['line_total'] as num? ?? 0;
      return {
        'item':  item['item_name'],
        'qty':   item['qty'],
        'price': '₹${(item['unit_price'] as num).toStringAsFixed(2)}',
        'tax':   '₹${taxAmount.toStringAsFixed(2)}',
        'total': '₹${lineTotal.toStringAsFixed(2)}',
      };
    }).toList();

    await BillPdfService.generateAndShare(
      billDetail: billDetail,
      lineItems:  lineItems,
    );
  }

  // ── EDIT ─────────────────────────────────────────────────────
  Future<void> _editBill(BuildContext context) async {
    // ← Permission check
    if (!PermissionService.instance.canEditSaleBills) {
      showPermissionDeniedSnackBar(context, 'Sale Bill Edit');
      return;
    }

    final saleBloc = context.read<SaleBloc>();
    final db       = AppDatabase.instance;

    final billData = await db.getSaleBillById(billId);
    if (billData == null) return;

    final customerController = TextEditingController(text: billData['customer_name'] ?? '');
    final totalController = TextEditingController(
        text: (billData['total_amount'] as num?)?.toStringAsFixed(2) ?? '0.00');
    final noteController = TextEditingController(text: billData['notes'] ?? '');

    const _validStatuses = ['paid', 'unpaid', 'partial'];
    const _validModes    = ['cash', 'upi', 'bank', 'card', 'credit', 'udhar'];

    final rawStatus = (billData['payment_status'] ?? 'unpaid').toString().toLowerCase().trim();
    final rawMode   = (billData['payment_mode']   ?? 'cash').toString().toLowerCase().trim();

    String paymentStatusValue = _validStatuses.contains(rawStatus) ? rawStatus : 'unpaid';
    String paymentModeValue   = _validModes.contains(rawMode) ? rawMode : 'cash';

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: EdgeInsets.all(18.w),
                decoration: BoxDecoration(
                  color: app_colors.Dbackgroun_color,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(color: app_colors.Dborder_color),
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // HEADER
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(10.w),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Icon(Icons.edit_note_rounded, color: app_colors.black),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text("Edit Bill",
                                  style: TextStyle(
                                      fontSize: 18.sp, fontWeight: FontWeight.w600,
                                      color: app_colors.black)),
                            ),
                            InkWell(
                              onTap: () => Navigator.pop(dialogCtx),
                              child: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        SizedBox(height: 20.h),
                        // Customer
                        _buildField(controller: customerController, label: "Customer", icon: Icons.person),
                        SizedBox(height: 14.h),
                        // Total
                        _buildField(
                          controller: totalController, label: "Total Amount", icon: Icons.currency_rupee,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        SizedBox(height: 14.h),
                        // Payment Status dropdown
                        DropdownButtonFormField<String>(
                          value: paymentStatusValue,
                          decoration: InputDecoration(
                            labelText: 'Payment Status',
                            prefixIcon: const Icon(Icons.payment),
                            filled: true, fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(color: app_colors.Dborder_color),
                            ),
                          ),
                          items: _validStatuses.map((s) =>
                              DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                          onChanged: (v) { if (v != null) setState(() => paymentStatusValue = v); },
                        ),
                        SizedBox(height: 14.h),
                        // Payment Mode dropdown
                        DropdownButtonFormField<String>(
                          value: paymentModeValue,
                          decoration: InputDecoration(
                            labelText: 'Payment Mode',
                            prefixIcon: const Icon(Icons.account_balance_wallet),
                            filled: true, fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(color: app_colors.Dborder_color),
                            ),
                          ),
                          items: _validModes.map((m) =>
                              DropdownMenuItem(value: m, child: Text(m.toUpperCase()))).toList(),
                          onChanged: (v) { if (v != null) setState(() => paymentModeValue = v); },
                        ),
                        SizedBox(height: 14.h),
                        // Notes
                        _buildField(
                          controller: noteController, label: "Notes", icon: Icons.note,
                          maxLines: 3,
                        ),
                        SizedBox(height: 24.h),
                        // Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 14.h),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                ),
                                onPressed: () => Navigator.pop(dialogCtx),
                                child: Text("Cancel", style: TextStyle(color: app_colors.black)),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  elevation: 0, backgroundColor: app_colors.table_header_bg,
                                  padding: EdgeInsets.symmetric(vertical: 14.h),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                ),
                                onPressed: () async {
                                  if (!formKey.currentState!.validate()) return;
                                  await db.updateSaleBillStatus(billId, paymentStatusValue);
                                  await (await AppDatabase.instance.database).update(
                                    'sale_bills',
                                    {
                                      'payment_mode': paymentModeValue,
                                      'notes': noteController.text.trim(),
                                    },
                                    where: 'id = ?', whereArgs: [billId],
                                  );
                                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                                  saleBloc.add(FetchSaleBills());
                                  onBillUpdated?.call();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Bill updated successfully')),
                                    );
                                  }
                                },
                                child: Text("Update",
                                    style: TextStyle(color: app_colors.black, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final perm = PermissionService.instance; // ← NEW

    return Padding(
      padding: const EdgeInsets.only(top: 18, left: 12, right: 12),
      child: Container(
        padding: const EdgeInsets.all(8),
        width:   double.infinity,
        height:  64.h,
        decoration: BoxDecoration(
          color:        app_colors.Dbackgroun_color,
          border:       Border.all(color: app_colors.Dborder_color),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Bill code box
            Container(
              width:  44.w,
              height: 44.h,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: app_colors.Dborder_color),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Center(
                child: Text(
                  "SB\n${billNumber.contains('-') ? billNumber.split('-').last : billNumber}",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.sp, color: app_colors.black, fontFamily: app_fonts.Bold),
                ),
              ),
            ),
            SizedBox(width: 12.w),

            // Party name + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(partyName, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16.sp, color: Colors.black, fontFamily: app_fonts.Medium)),
                  SizedBox(height: 4.h),
                  Text(billDate,
                      style: TextStyle(fontSize: 11.sp, color: Colors.black, fontFamily: app_fonts.Regular)),
                ],
              ),
            ),

            // Status + amount
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 6.h),
                  child: Container(
                    width: 56.w, height: 18.h,
                    decoration: BoxDecoration(
                      color: paymentStatus.toLowerCase() == 'paid'
                          ? app_colors.LightGreen
                          : app_colors.c_danger.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Center(
                      child: Text(
                        paymentStatus,
                        style: TextStyle(
                          fontSize: 11.sp, fontFamily: app_fonts.Medium,
                          color: paymentStatus.toLowerCase() == 'paid'
                              ? app_colors.GreenColor
                              : app_colors.c_danger,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                Text('${app_strings.Rs}$totalAmount',
                    style: TextStyle(fontSize: 11.sp, color: Colors.black, fontFamily: app_fonts.Regular)),
              ],
            ),

            // ── 3-dot menu with PERMISSION GUARDS ─────────────
            PopupMenuButton<String>(
              color: app_colors.white,
              onSelected: (value) {
                if (value == 'view')   _viewBill(context);
                if (value == 'edit')   _editBill(context);
                if (value == 'delete') _deleteBill(context);
              },
              itemBuilder: (ctx) => [
                // View — always visible
                PopupMenuItem<String>(
                  height: 32, value: 'view',
                  child: Row(children: [
                    Icon(Icons.remove_red_eye, size: 18, color: app_colors.black),
                    SizedBox(width: 10.w),
                    Text("View Bill", style: TextStyle(fontSize: 12.sp)),
                  ]),
                ),
                // Edit — only if allowed
                if (perm.canEditSaleBills)
                  PopupMenuItem<String>(
                    height: 32, value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit, size: 18, color: app_colors.black),
                      SizedBox(width: 10.w),
                      Text("Edit Bill", style: TextStyle(fontSize: 12.sp)),
                    ]),
                  ),
                // Delete — only if allowed
                if (perm.canDeleteSaleBills)
                  PopupMenuItem<String>(
                    height: 32, value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete, size: 18, color: app_colors.c_danger),
                      SizedBox(width: 10.w),
                      Text("Delete Bill",
                          style: TextStyle(fontSize: 12.sp, color: app_colors.c_danger)),
                    ]),
                  ),
              ],
              icon: Icon(Icons.more_vert, color: app_colors.black),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Field helper ─────────────────────────────────────────────────
Widget _buildField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  TextInputType? keyboardType,
  int maxLines = 1,
}) {
  return TextFormField(
    controller:   controller,
    keyboardType: keyboardType,
    maxLines:     maxLines,
    decoration: InputDecoration(
      labelText:  label,
      prefixIcon: Icon(icon),
      filled: true, fillColor: Colors.white,
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: app_colors.Dborder_color),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: app_colors.table_header_bg, width: 1.4),
      ),
    ),
  );
}
