import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../database/app_database.dart';
import '../../model/item_model.dart';
import '../pages/item_edit_screen.dart';

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

  Future<void> _deleteItem(BuildContext context) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
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

    if (confirm == true) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Deleting item...'),
            ],
          ),
        ),
      );

      try {
        // Delete from database
        await AppDatabase.instance.deleteItem(item.id!);

        // Close loading dialog
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.name} deleted successfully')),
        );

        // Refresh the list
        if (onItemDeleted != null) {
          onItemDeleted!();
        }
      } catch (e) {
        // Close loading dialog
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
            // Icon container
            Container(
              width: 38.w,
              height: 38.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(Icons.inventory, size: 20, color: app_colors.black),
            ),
            SizedBox(width: 12.w),

            // Item name & stock
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.black,
                      fontFamily: app_fonts.Medium,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    "Stock: ${item.qty ?? 0}",
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.black,
                      fontFamily: app_fonts.Regular,
                    ),
                  ),
                ],
              ),
            ),

            // Price
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "₹${item.price?.toStringAsFixed(2) ?? "0.00"}",
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: app_colors.black,
                  ),
                ),
                if (item.hsnCode != null)
                  Text(
                    "HSN: ${item.hsnCode}",
                    style: TextStyle(fontSize: 9.sp, color: Colors.grey),
                  ),
              ],
            ),

            // 3-dot menu
            PopupMenuButton<String>(
              color: app_colors.white,
              onSelected: (value) async {
                if (value == 'edit') {
                  final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => ItemEditScreen(item: item)));
                  if (res == true && onItemUpdated != null) onItemUpdated!();
                } else if (value == 'delete') {
                  _deleteItem(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 10),
                      Text("Edit"),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: app_colors.c_danger),
                      SizedBox(width: 10.w),
                      Text(
                        "Delete",
                        style: TextStyle(color: app_colors.c_danger),
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
  String? Function(String?)? validator,
}) {
  return TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    validator: validator,
    style: TextStyle(
      color: app_colors.black,
      fontSize: 14.sp,
    ),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14.w,
        vertical: 14.h,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(
          color: app_colors.Dborder_color,
        ),
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

