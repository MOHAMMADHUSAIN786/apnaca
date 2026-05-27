import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../database/app_database.dart';
import '../../model/item_model.dart';

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

  Future<void> _editItem(BuildContext context) async {
    final nameController = TextEditingController(text: item.name);
    final qtyController =
    TextEditingController(text: item.qty?.toString() ?? "");
    final priceController =
    TextEditingController(text: item.price?.toString() ?? "");
    final hsnController =
    TextEditingController(text: item.hsnCode ?? "");

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

                    // Header
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10.w),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            Icons.edit_note_rounded,
                            color: app_colors.black,
                          ),
                        ),

                        SizedBox(width: 12.w),

                        Expanded(
                          child: Text(
                            "Update Item",
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontFamily: app_fonts.Medium,
                              color: app_colors.black,
                            ),
                          ),
                        ),

                        InkWell(
                          onTap: () => Navigator.pop(context),
                          child: Icon(Icons.close),
                        )
                      ],
                    ),

                    SizedBox(height: 22.h),

                    // Name
                    _buildField(
                      controller: nameController,
                      label: "Item Name",
                      icon: Icons.inventory_2_outlined,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return "Enter item name";
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 14.h),

                    // Qty
                    _buildField(
                      controller: qtyController,
                      label: "Quantity",
                      icon: Icons.numbers,
                      keyboardType: TextInputType.number,
                    ),

                    SizedBox(height: 14.h),

                    // Price
                    _buildField(
                      controller: priceController,
                      label: "Price",
                      icon: Icons.currency_rupee,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                    ),

                    SizedBox(height: 14.h),

                    // HSN
                    _buildField(
                      controller: hsnController,
                      label: "HSN Code",
                      icon: Icons.qr_code,
                    ),

                    SizedBox(height: 24.h),

                    Row(
                      children: [

                        // Cancel
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              side: BorderSide(
                                color: app_colors.Dborder_color,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text(
                              "Cancel",
                              style: TextStyle(
                                color: app_colors.black,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(width: 12.w),

                        // Update
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: app_colors.table_header_bg,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            onPressed: () async {

                              if (!formKey.currentState!.validate()) return;

                              try {

                                final updatedItem = ItemModel(
                                  id: item.id,
                                  name: nameController.text.trim(),
                                  qty: int.tryParse(qtyController.text.trim()) ?? 0,
                                  price: double.tryParse(
                                      priceController.text.trim()) ??
                                      0,
                                  hsnCode: hsnController.text.trim().isEmpty
                                      ? null
                                      : hsnController.text.trim(),
                                );

                                await AppDatabase.instance
                                    .updateItem(updatedItem);

                                Navigator.pop(context);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Item updated successfully",
                                    ),
                                  ),
                                );

                                if (onItemUpdated != null) {
                                  onItemUpdated!();
                                }

                              } catch (e) {

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Failed: $e"),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            child: Text(
                              "Update",
                              style: TextStyle(
                                color: app_colors.black,
                                fontSize: 14.sp,
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
              onSelected: (value) {
                if (value == 'edit') {
                  _editItem(context);
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

