// lib/features/customer/presentation/widgets/app_customer_design.dart
// UPDATED: Permission guards on edit/delete popup items

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/services/permission_service.dart'; // ← NEW
import '../../../../database/app_database.dart';
import '../../model/customer_model.dart';

class AppCustomerDesign extends StatelessWidget {
  final CustomerModel customer;
  final VoidCallback? onCustomerDeleted;
  final VoidCallback? onCustomerUpdated;

  const AppCustomerDesign({
    super.key,
    required this.customer,
    this.onCustomerDeleted,
    this.onCustomerUpdated,
  });

  // ── DELETE ───────────────────────────────────────────────────
  Future<void> _deleteCustomer(BuildContext context) async {
    // ← Permission check
    if (!PermissionService.instance.canManageCustomers) {
      showPermissionDeniedSnackBar(context, 'Customer Delete');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete "${customer.name}"?'),
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
            CircularProgressIndicator(), SizedBox(width: 20), Text('Deleting customer...'),
          ]),
        ),
      );

      try {
        await AppDatabase.instance.deleteCustomer(customer.id!);
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${customer.name} deleted successfully')),
        );
        if (onCustomerDeleted != null) onCustomerDeleted!();
      } catch (e) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── EDIT ─────────────────────────────────────────────────────
  Future<void> _editCustomer(BuildContext context) async {
    // ← Permission check
    if (!PermissionService.instance.canManageCustomers) {
      showPermissionDeniedSnackBar(context, 'Customer Edit');
      return;
    }

    final nameController    = TextEditingController(text: customer.name);
    final phoneController   = TextEditingController(text: customer.phone ?? "");
    final emailController   = TextEditingController(text: customer.email ?? "");
    final gstController     = TextEditingController(text: customer.gstNumber ?? "");
    final stateController   = TextEditingController(text: customer.state ?? "");
    final addressController = TextEditingController(text: customer.address ?? "");
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
                          child: Icon(Icons.person_outline, color: app_colors.black),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text("Update Customer",
                              style: TextStyle(fontSize: 18.sp, fontFamily: app_fonts.Medium, color: app_colors.black)),
                        ),
                        InkWell(onTap: () => Navigator.pop(context), child: const Icon(Icons.close)),
                      ],
                    ),
                    SizedBox(height: 22.h),

                    _buildCustField(controller: nameController, label: "Customer Name", icon: Icons.person,
                        validator: (v) => (v == null || v.trim().isEmpty) ? "Enter customer name" : null),
                    SizedBox(height: 14.h),
                    _buildCustField(controller: phoneController, label: "Mobile Number",
                        icon: Icons.phone, keyboardType: TextInputType.phone),
                    SizedBox(height: 14.h),
                    _buildCustField(controller: emailController, label: "Email",
                        icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                    SizedBox(height: 14.h),
                    _buildCustField(controller: gstController, label: "GST Number", icon: Icons.receipt_long),
                    SizedBox(height: 14.h),
                    _buildCustField(controller: stateController, label: "State", icon: Icons.location_city),
                    SizedBox(height: 14.h),
                    _buildCustField(controller: addressController, label: "Address",
                        icon: Icons.location_on_outlined, maxLines: 3),
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
                                final updatedCustomer = CustomerModel(
                                  id: customer.id,
                                  name: nameController.text.trim(),
                                  phone: phoneController.text.trim(),
                                  email: emailController.text.trim(),
                                  gstNumber: gstController.text.trim(),
                                  state: stateController.text.trim(),
                                  address: addressController.text.trim(),
                                );
                                await AppDatabase.instance.updateCustomer(updatedCustomer);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Customer updated successfully")),
                                );
                                if (onCustomerUpdated != null) onCustomerUpdated!();
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
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8.r)),
              child: Icon(Icons.person, size: 20, color: app_colors.black),
            ),
            SizedBox(width: 12.w),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(customer.name, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16.sp, color: Colors.black, fontFamily: app_fonts.Medium)),
                  SizedBox(height: 4.h),
                  Text(
                    customer.phone != null ? "📞 ${customer.phone}" : (customer.email ?? "No contact"),
                    style: TextStyle(fontSize: 11.sp, color: Colors.black54, fontFamily: app_fonts.Regular),
                  ),
                ],
              ),
            ),

            if (customer.gstNumber != null && customer.gstNumber!.isNotEmpty)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("GST", style: TextStyle(fontSize: 9.sp, color: Colors.grey)),
                  Text(customer.gstNumber!,
                      style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: app_colors.black)),
                ],
              ),

            // ── 3-dot menu with PERMISSION GUARDS ────────────
            PopupMenuButton<String>(
              color: app_colors.white,
              onSelected: (value) {
                if (value == 'edit') _editCustomer(context);
                else if (value == 'delete') _deleteCustomer(context);
              },
              itemBuilder: (context) => [
                if (perm.canManageCustomers)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 10), Text("Edit")]),
                  ),
                if (perm.canManageCustomers)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete, size: 18, color: app_colors.c_danger),
                      SizedBox(width: 10.w),
                      Text("Delete", style: TextStyle(color: app_colors.c_danger)),
                    ]),
                  ),
                if (!perm.canManageCustomers)
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
Widget _buildCustField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
  int maxLines = 1,
}) {
  return TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    validator: validator,
    maxLines: maxLines,
    style: TextStyle(color: app_colors.black, fontSize: 14.sp),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
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
