// lib/features/purchase/presentation/widgets/app_purchase_bill_item.dart
// UPDATED: Permission guards on edit/delete

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/permission_service.dart'; // ← NEW
import '../../../../database/app_database.dart';
import '../../../ai_chat/service/bill_pdf_service.dart';

class AppPurchaseBillItem extends StatelessWidget {

  final int billId;
  final String billNumber;
  final String supplierName;
  final String billDate;
  final String totalAmount;
  final String paymentStatus;
  final VoidCallback? onBillUpdated;

  const AppPurchaseBillItem({
    super.key,
    required this.billId,
    required this.billNumber,
    required this.supplierName,
    required this.billDate,
    required this.totalAmount,
    required this.paymentStatus,
    this.onBillUpdated,
  });

  // ── VIEW ─────────────────────────────────────────────────────
  Future<void> _viewBill(BuildContext context) async {
    final db = AppDatabase.instance;
    final billDetailMap = await db.getPurchaseBillByNumber(billNumber);
    if (billDetailMap == null) return;

    final lineItemsMap = await db.getPurchaseBillItems(billId);

    final billDetail = {
      'Bill No':  billDetailMap['bill_number'],
      'Supplier': supplierName,
      'Date':     billDate,
      'Payment':  billDetailMap['payment_mode'] ?? 'cash',
      'Status':   paymentStatus,
      'Subtotal': '₹${(billDetailMap['subtotal'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
      'GST':      '₹${(billDetailMap['tax_amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
      'Total':    '₹${(billDetailMap['total_amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
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

  // ── DELETE ───────────────────────────────────────────────────
  Future<void> _deleteBill(BuildContext context) async {
    // ← Permission check
    if (!PermissionService.instance.canDeletePurchaseBills) {
      showPermissionDeniedSnackBar(context, 'Purchase Bill Delete');
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:   const Text('Delete Bill'),
        content: Text('Delete purchase bill $billNumber?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      final db = AppDatabase.instance;
      await db.deletePurchaseBillWithStockDeduct(billId);

      if (context.mounted) {
        onBillUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bill $billNumber deleted successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── EDIT ─────────────────────────────────────────────────────
  Future<void> _editBill(BuildContext context) async {
    // ← Permission check
    if (!PermissionService.instance.canEditPurchaseBills) {
      showPermissionDeniedSnackBar(context, 'Purchase Bill Edit');
      return;
    }

    final db   = AppDatabase.instance;
    final bill = await db.getPurchaseBillByNumber(billNumber);
    if (bill == null) return;

    final totalController = TextEditingController(
        text: (bill['total_amount'] as num?)?.toStringAsFixed(2) ?? '0.00');
    final noteController = TextEditingController(text: bill['notes'] ?? '');

    const _validStatuses = ['paid', 'unpaid', 'partial'];
    const _validModes    = ['cash', 'upi', 'bank', 'card', 'credit', 'udhar'];

    final rawStatus = (bill['payment_status'] ?? 'unpaid').toString().toLowerCase().trim();
    final rawMode   = (bill['payment_mode']   ?? 'cash').toString().toLowerCase().trim();

    String paymentStatusValue = _validStatuses.contains(rawStatus) ? rawStatus : 'unpaid';
    String paymentModeValue   = _validModes.contains(rawMode)      ? rawMode   : 'cash';

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: EdgeInsets.all(18.w),
                decoration: BoxDecoration(
                  color:        app_colors.Dbackgroun_color,
                  borderRadius: BorderRadius.circular(18.r),
                  border:       Border.all(color: app_colors.Dborder_color),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // HEADER
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10.w),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Icon(Icons.shopping_bag_outlined, color: app_colors.black),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text("Update Purchase Bill",
                                style: TextStyle(fontSize: 18.sp, fontFamily: app_fonts.Medium)),
                          ),
                          InkWell(onTap: () => Navigator.pop(dialogCtx), child: const Icon(Icons.close)),
                        ],
                      ),
                      SizedBox(height: 16.h),

                      // Bill number (read-only)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: app_colors.Dborder_color),
                        ),
                        child: Text("Bill No : $billNumber",
                            style: TextStyle(fontSize: 14.sp, fontFamily: app_fonts.Medium)),
                      ),
                      SizedBox(height: 14.h),

                      _buildField(
                        controller: totalController, label: "Total Amount", icon: Icons.currency_rupee,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      SizedBox(height: 14.h),

                      DropdownButtonFormField<String>(
                        value: paymentStatusValue,
                        decoration: InputDecoration(
                          labelText: "Payment Status", filled: true, fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                        ),
                        items: _validStatuses.map((e) =>
                            DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
                        onChanged: (v) => setState(() => paymentStatusValue = v!),
                      ),
                      SizedBox(height: 14.h),

                      DropdownButtonFormField<String>(
                        value: paymentModeValue,
                        decoration: InputDecoration(
                          labelText: "Payment Mode", filled: true, fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                        ),
                        items: _validModes.map((e) =>
                            DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
                        onChanged: (v) => setState(() => paymentModeValue = v!),
                      ),
                      SizedBox(height: 14.h),

                      _buildField(controller: noteController, label: "Notes", icon: Icons.notes, maxLines: 3),
                      SizedBox(height: 20.h),

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
                                try {
                                  final dbRaw = await db.database;
                                  await dbRaw.update(
                                    'purchase_bills',
                                    {
                                      'payment_status': paymentStatusValue,
                                      'payment_mode':   paymentModeValue,
                                      'total_amount':   double.tryParse(totalController.text) ?? 0,
                                      'notes':          noteController.text.trim(),
                                    },
                                    where: 'id = ?', whereArgs: [billId],
                                  );
                                  Navigator.pop(dialogCtx);
                                  if (context.mounted) {
                                    onBillUpdated?.call();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Bill updated successfully")),
                                    );
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red),
                                  );
                                }
                              },
                              child: Text("Update",
                                  style: TextStyle(color: app_colors.black, fontFamily: app_fonts.Medium)),
                            ),
                          ),
                        ],
                      ),
                    ],
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
          children: [
            Container(
              width: 44.w, height: 44.h,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: app_colors.Dborder_color),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Center(
                child: Text(
                  textAlign: TextAlign.center,
                  "PB\n${billNumber.contains('-') ? billNumber.split('-').last : billNumber}",
                  style: TextStyle(fontSize: 12.sp, fontFamily: app_fonts.Bold),
                ),
              ),
            ),
            SizedBox(width: 12.w),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(supplierName, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16.sp, fontFamily: app_fonts.Medium)),
                  SizedBox(height: 4.h),
                  Text(billDate, style: TextStyle(fontSize: 11.sp, fontFamily: app_fonts.Regular)),
                ],
              ),
            ),

            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
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
                SizedBox(height: 4.h),
                Text('${app_strings.Rs}$totalAmount',
                    style: TextStyle(fontSize: 11.sp, fontFamily: app_fonts.Regular)),
              ],
            ),

            // ── 3-dot menu with PERMISSION GUARDS ────────────
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
                if (perm.canEditPurchaseBills)
                  PopupMenuItem<String>(
                    height: 32, value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit, size: 18, color: app_colors.black),
                      SizedBox(width: 10.w),
                      Text("Edit Bill", style: TextStyle(fontSize: 12.sp)),
                    ]),
                  ),
                // Delete — only if allowed
                if (perm.canDeletePurchaseBills)
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
