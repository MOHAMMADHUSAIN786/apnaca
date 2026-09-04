// lib/features/item/presentation/widgets/stock_action_dialog.dart
// Stock In / Stock Out / Stock Adjustment dialog — reuses exact same
// Dialog/Container/Field styling as Add/Edit Item dialogs.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../database/app_database.dart';
import '../../model/item_model.dart';

enum StockActionType { stockIn, stockOut, adjustment }

/// Shows the Stock In / Stock Out / Adjustment dialog for [item].
/// On success, calls [onUpdated] so caller can refresh the list.
Future<void> showStockActionDialog({
  required BuildContext context,
  required ItemModel item,
  required StockActionType actionType,
  VoidCallback? onUpdated,
}) async {
  final qtyController    = TextEditingController();
  final reasonController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  String title;
  IconData icon;
  String qtyLabel;
  Color iconBg;

  switch (actionType) {
    case StockActionType.stockIn:
      title = "Stock In";
      icon = Icons.add_box_outlined;
      qtyLabel = "Quantity to Add";
      iconBg = app_colors.LightGreen;
      break;
    case StockActionType.stockOut:
      title = "Stock Out";
      icon = Icons.remove_circle_outline;
      qtyLabel = "Quantity to Remove";
      iconBg = app_colors.RedColor;
      break;
    case StockActionType.adjustment:
      title = "Adjust Stock";
      icon = Icons.tune;
      qtyLabel = "New Stock Quantity";
      iconBg = app_colors.LightOrange;
      break;
  }

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
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
                          color: iconBg,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(icon, color: app_colors.black),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(title,
                            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600,
                                fontFamily: app_fonts.Medium, color: app_colors.black)),
                      ),
                      InkWell(onTap: () => Navigator.pop(context), child: const Icon(Icons.close)),
                    ],
                  ),
                  SizedBox(height: 8.h),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "${item.name}  •  Current Stock: ${item.qty ?? 0}",
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700, fontFamily: app_fonts.Regular),
                    ),
                  ),
                  SizedBox(height: 18.h),

                  _buildField(
                    controller: qtyController,
                    label: qtyLabel,
                    icon: Icons.numbers,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Quantity enter karein";
                      final n = int.tryParse(v.trim());
                      if (n == null) return "Sahi number daalein";
                      if (actionType == StockActionType.adjustment) {
                        if (n < 0) return "Stock negative nahi ho sakta";
                      } else {
                        if (n <= 0) return "0 se zyada hona chahiye";
                        if (actionType == StockActionType.stockOut && n > (item.qty ?? 0)) {
                          return "Current stock (${item.qty ?? 0}) se zyada nahi ho sakta";
                        }
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 14.h),

                  _buildField(
                    controller: reasonController,
                    label: "Reason / Note (optional)",
                    icon: Icons.edit_note,
                  ),
                  SizedBox(height: 24.h),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            side: BorderSide(color: app_colors.Dborder_color),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text("Cancel", style: TextStyle(color: app_colors.black, fontSize: 14.sp)),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: app_colors.table_header_bg, elevation: 0,
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          ),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final qty = int.parse(qtyController.text.trim());
                            final reason = reasonController.text.trim().isEmpty
                                ? null : reasonController.text.trim();
                            try {
                              switch (actionType) {
                                case StockActionType.stockIn:
                                  await AppDatabase.instance.stockIn(item.id!, qty, reason: reason);
                                  break;
                                case StockActionType.stockOut:
                                  await AppDatabase.instance.stockOut(item.id!, qty, reason: reason);
                                  break;
                                case StockActionType.adjustment:
                                  await AppDatabase.instance.adjustStock(item.id!, qty, reason: reason);
                                  break;
                              }
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("$title successful")),
                              );
                              if (onUpdated != null) onUpdated();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Failed: ${e.toString().replaceAll('Exception: ', '')}"),
                                    backgroundColor: Colors.red),
                              );
                            }
                          },
                          child: Text("Save",
                              style: TextStyle(color: app_colors.black, fontSize: 14.sp, fontFamily: app_fonts.Medium)),
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
}

// ── Field helper (matches AppItemDesign / ItemScreen field styling) ────────
Widget _buildField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
}) {
  return TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    validator: validator,
    style: TextStyle(color: app_colors.black, fontSize: 14.sp),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true, fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
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
