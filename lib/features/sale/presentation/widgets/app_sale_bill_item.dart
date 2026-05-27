// lib/widgets/sale_widgets/app_sale_bill_item.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/app_strings.dart';
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

  Future<void> _deleteBill(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bill'),
        content: Text('Are you sure you want to delete bill $billNumber?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      final db = AppDatabase.instance;

      // Delete all items first (due to cascade, but we'll explicitly delete)
      final items = await db.getSaleBillItems(billId);
      for (final item in items) {
        // Restore stock if needed (optional)
         await db.restoreItemStock(item['item_id'], item['qty']);
      }

      // Delete the bill (cascade will delete sale_bill_items automatically)
      final dbInstance = await db.database;
      await dbInstance.delete('sale_bills', where: 'id = ?', whereArgs: [billId]);

      // Refresh the list
      if (context.mounted) {
        context.read<SaleBloc>().add(FetchSaleBills());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bill $billNumber deleted successfully')),
        );
      }
    }
  }

  Future<void> _viewBill(BuildContext context) async {
    final db = AppDatabase.instance;

    // Fetch bill details
    final billDetailMap = await db.getSaleBillById(billId);
    if (billDetailMap == null) return;

    // Fetch line items
    final lineItemsMap = await db.getSaleBillItems(billId);

    // Format for PDF service
    final billDetail = {
      'Bill No': billDetailMap['bill_number'],
      'Customer': partyName,
      'Date': billDate,
      'Payment': billDetailMap['payment_mode'] ?? 'cash',
      'Status': paymentStatus,
      'Subtotal': '₹${billDetailMap['subtotal']?.toStringAsFixed(2) ?? '0.00'}',
      'GST': '₹${billDetailMap['gst_amount']?.toStringAsFixed(2) ?? '0.00'}',
      'Total': '₹${billDetailMap['total_amount']?.toStringAsFixed(2) ?? '0.00'}',
      'Notes': billDetailMap['notes'] ?? '',
    };

    final lineItems = lineItemsMap.map((item) {
      final taxAmount = item['tax_amount'] as num? ?? 0;
      final lineTotal = item['line_total'] as num? ?? 0;
      return {
        'item': item['item_name'],
        'qty': item['qty'],
        'price': '₹${(item['unit_price'] as num).toStringAsFixed(2)}',
        'tax': '₹${taxAmount.toStringAsFixed(2)}',
        'total': '₹${lineTotal.toStringAsFixed(2)}',
      };
    }).toList();

    // Generate and share PDF
    await BillPdfService.generateAndShare(
      billDetail: billDetail,
      lineItems: lineItems,
    );
  }

  Future<void> _editBill(BuildContext context) async {
    final saleBloc = context.read<SaleBloc>();

    final db = AppDatabase.instance;

    final billData = await db.getSaleBillById(billId);

    if (billData == null) return;

    final customerController = TextEditingController(
      text: billData['customer_name'] ?? '',
    );

    final totalController = TextEditingController(
      text: billData['total_amount'].toString(),
    );

    final noteController = TextEditingController(
      text: billData['notes'] ?? '',
    );

    String paymentStatusValue =
        billData['payment_status'] ?? 'unpaid';

    String paymentModeValue =
        billData['payment_mode'] ?? 'cash';

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {

        return StatefulBuilder(
          builder: (context, setState) {

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: EdgeInsets.all(18.w),
                decoration: BoxDecoration(
                  color: app_colors.Dbackgroun_color,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(
                    color: app_colors.Dborder_color,
                  ),
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
                                borderRadius:
                                BorderRadius.circular(12.r),
                              ),
                              child: Icon(
                                Icons.receipt_long,
                                color: app_colors.black,
                              ),
                            ),

                            SizedBox(width: 12.w),

                            Expanded(
                              child: Text(
                                "Update Sale Bill",
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontFamily: app_fonts.Medium,
                                  color: app_colors.black,
                                ),
                              ),
                            ),

                            InkWell(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(Icons.close),
                            ),
                          ],
                        ),

                        SizedBox(height: 22.h),

                        // BILL NUMBER
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                            BorderRadius.circular(12.r),
                            border: Border.all(
                              color: app_colors.Dborder_color,
                            ),
                          ),
                          child: Text(
                            "Bill No : $billNumber",
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontFamily: app_fonts.Medium,
                            ),
                          ),
                        ),

                        SizedBox(height: 14.h),

                        // CUSTOMER
                        _buildField(
                          controller: customerController,
                          label: "Customer Name",
                          icon: Icons.person,
                        ),

                        SizedBox(height: 14.h),

                        // TOTAL
                        _buildField(
                          controller: totalController,
                          label: "Total Amount",
                          icon: Icons.currency_rupee,
                          keyboardType:
                          const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),

                        SizedBox(height: 14.h),

                        // PAYMENT STATUS
                        DropdownButtonFormField<String>(
                          value: paymentStatusValue,
                          decoration: InputDecoration(
                            labelText: "Payment Status",
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          items: ['paid', 'unpaid', 'partial']
                              .map(
                                (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.toUpperCase()),
                            ),
                          )
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              paymentStatusValue = v!;
                            });
                          },
                        ),

                        SizedBox(height: 14.h),

                        // PAYMENT MODE
                        DropdownButtonFormField<String>(
                          value: paymentModeValue,
                          decoration: InputDecoration(
                            labelText: "Payment Mode",
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(12.r),
                            ),
                          ),
                          items: ['cash', 'upi', 'bank', 'card', 'credit']
                              .map(
                                (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.toUpperCase()),
                            ),
                          )
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              paymentModeValue = v!;
                            });
                          },
                        ),

                        SizedBox(height: 14.h),

                        // NOTES
                        _buildField(
                          controller: noteController,
                          label: "Notes",
                          icon: Icons.notes,
                          maxLines: 3,
                        ),

                        SizedBox(height: 24.h),

                        Row(
                          children: [

                            // CANCEL
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 14.h,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(12.r),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  "Cancel",
                                  style: TextStyle(
                                    color: app_colors.black,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(width: 12.w),

                            // UPDATE
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor:
                                  app_colors.table_header_bg,
                                  padding: EdgeInsets.symmetric(
                                    vertical: 14.h,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(12.r),
                                  ),
                                ),
                                onPressed: () async {

                                  try {

                                    final dbInstance =
                                    await db.database;

                                    await dbInstance.update(
                                      'sale_bills',
                                      {
                                        'payment_status':
                                        paymentStatusValue,
                                        'payment_mode':
                                        paymentModeValue,
                                        'total_amount':
                                        double.tryParse(
                                          totalController.text,
                                        ) ??
                                            0,
                                        'notes':
                                        noteController.text.trim(),
                                      },
                                      where: 'id = ?',
                                      whereArgs: [billId],
                                    );

                                    Navigator.pop(context);

                                    if (context.mounted) {

                                      saleBloc.add(FetchSaleBills());

                                      if (onBillUpdated != null) {
                                        onBillUpdated!();
                                      }

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Bill updated successfully",
                                          ),
                                        ),
                                      );
                                    }

                                  } catch (e) {

                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content:
                                        Text("Failed: $e"),
                                        backgroundColor:
                                        Colors.red,
                                      ),
                                    );
                                  }
                                },
                                child: Text(
                                  "Update",
                                  style: TextStyle(
                                    color: app_colors.black,
                                    fontFamily: app_fonts.Medium,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, left: 12, right: 12),
      child: Container(
        padding: const EdgeInsets.all(8),
        width: double.infinity,
        height: 64.h,
        decoration: BoxDecoration(
          color: app_colors.Dbackgroun_color,
          border: Border.all(color: app_colors.Dborder_color),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Bill Code Box
            Container(
              width: 38.w,
              height: 38.h,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: app_colors.Dborder_color),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Center(
                child: Text(
                  billNumber.length > 4 ? billNumber.substring(0, 4) : billNumber,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: app_colors.black,
                    fontFamily: app_fonts.Bold,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),

            // Party Name and Date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    partyName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.black,
                      fontFamily: app_fonts.Medium,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    billDate,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.black,
                      fontFamily: app_fonts.Regular,
                    ),
                  ),
                ],
              ),
            ),

            // Payment Status and Amount
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 6.h),
                  child: Container(
                    width: 56.w,
                    height: 18.h,
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
                          fontSize: 11.sp,
                          color: paymentStatus.toLowerCase() == 'paid'
                              ? app_colors.GreenColor
                              : app_colors.c_danger,
                          fontFamily: app_fonts.Medium,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                Padding(
                  padding: EdgeInsets.all(0),
                  child: Text(
                    '${app_strings.Rs}$totalAmount',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.black,
                      fontFamily: app_fonts.Regular,
                    ),
                  ),
                ),
              ],
            ),

            // 3-dot menu (View + Delete only - NO EDIT)
            PopupMenuButton<String>(
              color: app_colors.white,
                onSelected: (value) {
                  if (value == 'view') {
                    _viewBill(context);
                  } else if (value == 'edit') {
                    _editBill(context);
                  } else if (value == 'delete') {
                    _deleteBill(context);
                  }
                },

              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  height: 32,
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.remove_red_eye, size: 18, color: app_colors.black),
                      SizedBox(width: 10.w),
                      Text("View Bill", style: TextStyle(fontSize: 12.sp)),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  height: 32,
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18, color: app_colors.black),
                      SizedBox(width: 10.w),
                      Text(
                        "Edit Bill",
                        style: TextStyle(fontSize: 12.sp),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  height: 32,
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: app_colors.c_danger),
                      SizedBox(width: 10.w),
                      Text(
                        "Delete Bill",
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: app_colors.c_danger,
                        ),
                      ),
                    ],
                  ),
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

Widget _buildField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  TextInputType? keyboardType,
  int maxLines = 1,
}) {
  return TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(
          color: app_colors.Dborder_color,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(
          color: app_colors.table_header_bg,
          width: 1.4,
        ),
      ),
    ),
  );
}