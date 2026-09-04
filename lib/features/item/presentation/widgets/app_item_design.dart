// lib/features/item/presentation/widgets/app_item_design.dart
// UPDATED: Permission guards on edit/delete popup items

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/services/permission_service.dart'; // ← NEW
import '../../../../database/app_database.dart';
import '../../model/item_model.dart';
import '../pages/stock_history_screen.dart';
import 'stock_action_dialog.dart';

class AppItemDesign extends StatelessWidget {
  final ItemModel item;
  final VoidCallback? onItemDeleted;
  final VoidCallback? onItemUpdated;

  const AppItemDesign({
    super.key,
    required this.item,
    this.onItemDeleted,
    this.onItemUpdated,
  });

  // ── DELETE ───────────────────────────────────────────────────
  Future<void> _deleteItem(BuildContext context) async {
    // ← Permission check
    if (!PermissionService.instance.canManageItems) {
      showPermissionDeniedSnackBar(context, 'Item Delete');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(children: [
            CircularProgressIndicator(), SizedBox(width: 20), Text('Deleting item...'),
          ]),
        ),
      );

      try {
        await AppDatabase.instance.deleteItem(item.id!);
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.name} deleted successfully')),
        );
        if (onItemDeleted != null) onItemDeleted!();
      } catch (e) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── EDIT ─────────────────────────────────────────────────────
  Future<void> _editItem(BuildContext context) async {
    // ← Permission check
    if (!PermissionService.instance.canManageItems) {
      showPermissionDeniedSnackBar(context, 'Item Edit');
      return;
    }

    final nameController  = TextEditingController(text: item.name);
    final qtyController   = TextEditingController(text: item.qty?.toString() ?? "");
    final priceController = TextEditingController(text: item.price?.toString() ?? "");
    final hsnController   = TextEditingController(text: item.hsnCode ?? "");
    final skuController            = TextEditingController(text: item.sku ?? "");
    final purchasePriceController  = TextEditingController(text: item.purchasePrice?.toString() ?? "");
    final minStockController       = TextEditingController(text: item.minStockAlert?.toString() ?? "");
    final formKey = GlobalKey<FormState>();

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
                    // Header
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
                          child: Text("Update Item",
                              style: TextStyle(fontSize: 18.sp, fontFamily: app_fonts.Medium, color: app_colors.black)),
                        ),
                        InkWell(onTap: () => Navigator.pop(context), child: const Icon(Icons.close)),
                      ],
                    ),
                    SizedBox(height: 22.h),

                    _buildItemField(controller: nameController, label: "Item Name",
                        icon: Icons.inventory_2_outlined,
                        validator: (v) => (v == null || v.trim().isEmpty) ? "Enter item name" : null),
                    SizedBox(height: 14.h),
                    _buildItemField(controller: qtyController, label: "Quantity",
                        icon: Icons.numbers, keyboardType: TextInputType.number),
                    SizedBox(height: 14.h),
                    _buildItemField(controller: priceController, label: "Price",
                        icon: Icons.currency_rupee,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    SizedBox(height: 14.h),
                    _buildItemField(controller: hsnController, label: "HSN Code", icon: Icons.qr_code),
                    SizedBox(height: 14.h),

                    // ── INVENTORY MANAGEMENT FIELDS ─────────────────
                    _buildItemField(controller: skuController, label: "SKU",
                        icon: Icons.qr_code_2_outlined),
                    SizedBox(height: 14.h),
                    _buildItemField(controller: purchasePriceController, label: "Purchase Price",
                        icon: Icons.shopping_bag_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    SizedBox(height: 14.h),
                    _buildItemField(controller: minStockController, label: "Min Stock Alert",
                        icon: Icons.warning_amber_outlined, keyboardType: TextInputType.number),
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
                              try {
                                final updatedItem = ItemModel(
                                  id: item.id,
                                  name: nameController.text.trim(),
                                  qty: int.tryParse(qtyController.text.trim()) ?? 0,
                                  price: double.tryParse(priceController.text.trim()) ?? 0,
                                  hsnCode: hsnController.text.trim().isEmpty
                                      ? null : hsnController.text.trim(),
                                  sku: skuController.text.trim().isEmpty
                                      ? null : skuController.text.trim(),
                                  purchasePrice: double.tryParse(purchasePriceController.text.trim()),
                                  minStockAlert: int.tryParse(minStockController.text.trim()),
                                );
                                await AppDatabase.instance.updateItem(updatedItem);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Item updated successfully")),
                                );
                                if (onItemUpdated != null) onItemUpdated!();
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red),
                                );
                              }
                            },
                            child: Text("Update",
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

  // ── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final perm = PermissionService.instance; // ← NEW

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
            Container(
              width: 38.w, height: 38.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(Icons.inventory, size: 20, color: app_colors.black),
            ),
            SizedBox(width: 12.w),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(item.name, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 16.sp, color: Colors.black, fontFamily: app_fonts.Medium)),
                      ),
                      if (item.isLowStock) ...[
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                          decoration: BoxDecoration(
                            color: app_colors.RedColor,
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text("Low Stock",
                              style: TextStyle(fontSize: 9.sp, color: app_colors.c_danger, fontFamily: app_fonts.Medium)),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text("Stock: ${item.qty ?? 0}",
                      style: TextStyle(fontSize: 11.sp, color: Colors.black, fontFamily: app_fonts.Regular)),
                ],
              ),
            ),

            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("₹${item.price?.toStringAsFixed(2) ?? "0.00"}",
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: app_colors.black)),
                if (item.hsnCode != null)
                  Text("HSN: ${item.hsnCode}", style: TextStyle(fontSize: 9.sp, color: Colors.grey))
                else if (item.purchasePrice != null)
                  Text("Value: ₹${item.inventoryValue.toStringAsFixed(2)}",
                      style: TextStyle(fontSize: 9.sp, color: Colors.grey)),
              ],
            ),

            // ── 3-dot menu with PERMISSION GUARDS ────────────
            PopupMenuButton<String>(
              color: app_colors.white,
              onSelected: (value) {
                if (value == 'edit') _editItem(context);
                else if (value == 'delete') _deleteItem(context);
                else if (value == 'stock_in') {
                  showStockActionDialog(
                    context: context, item: item,
                    actionType: StockActionType.stockIn,
                    onUpdated: onItemUpdated,
                  );
                } else if (value == 'stock_out') {
                  showStockActionDialog(
                    context: context, item: item,
                    actionType: StockActionType.stockOut,
                    onUpdated: onItemUpdated,
                  );
                } else if (value == 'adjust_stock') {
                  showStockActionDialog(
                    context: context, item: item,
                    actionType: StockActionType.adjustment,
                    onUpdated: onItemUpdated,
                  );
                } else if (value == 'stock_history') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => StockHistoryScreen(item: item)),
                  );
                }
              },
              itemBuilder: (context) => [
                // Edit — only if allowed
                if (perm.canManageItems)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 10), Text("Edit")]),
                  ),
                // ── INVENTORY ACTIONS — only if allowed ──────────
                if (perm.canManageItems)
                  PopupMenuItem(
                    value: 'stock_in',
                    child: Row(children: [
                      Icon(Icons.add_box_outlined, size: 18, color: app_colors.GreenColor),
                      SizedBox(width: 10.w), const Text("Stock In"),
                    ]),
                  ),
                if (perm.canManageItems)
                  PopupMenuItem(
                    value: 'stock_out',
                    child: Row(children: [
                      Icon(Icons.remove_circle_outline, size: 18, color: app_colors.c_danger),
                      SizedBox(width: 10.w), const Text("Stock Out"),
                    ]),
                  ),
                if (perm.canManageItems)
                  PopupMenuItem(
                    value: 'adjust_stock',
                    child: Row(children: [
                      Icon(Icons.tune, size: 18, color: app_colors.OrangeColor),
                      SizedBox(width: 10.w), const Text("Adjust Stock"),
                    ]),
                  ),
                // Stock History — visible to everyone
                PopupMenuItem(
                  value: 'stock_history',
                  child: Row(children: [
                    Icon(Icons.history, size: 18, color: app_colors.black),
                    SizedBox(width: 10.w), const Text("Stock History"),
                  ]),
                ),
                // Delete — only if allowed
                if (perm.canManageItems)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete, size: 18, color: app_colors.c_danger),
                      SizedBox(width: 10.w),
                      Text("Delete", style: TextStyle(color: app_colors.c_danger)),
                    ]),
                  ),
                // View-only fallback — agar koi permission nahi
                if (!perm.canManageItems)
                  PopupMenuItem(
                    enabled: false,
                    child: Row(children: [
                      Icon(Icons.lock, size: 18, color: Colors.grey),
                      SizedBox(width: 10.w),
                      Text("View Only", style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
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
Widget _buildItemField({
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
