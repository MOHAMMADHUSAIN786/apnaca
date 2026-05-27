import 'package:apnaca/features/supplier/model/supplier_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../database/app_database.dart';

class AppSupplierDesign extends StatelessWidget {

  final SupplierModel supplier;

  final VoidCallback? onSupplierDeleted;

  final VoidCallback? onSupplierUpdated;

  const AppSupplierDesign({
    super.key,
    required this.supplier,
    this.onSupplierDeleted,
    this.onSupplierUpdated,
  });

  Future<void> _deleteSupplier(
      BuildContext context) async {

    final confirm = await showDialog<bool>(
      context: context,

      builder: (context) => AlertDialog(
        title: const Text('Delete Supplier'),

        content: Text(
          'Are you sure you want to delete "${supplier.name}"?',
        ),

        actions: [

          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),

          TextButton(
            onPressed: () =>
                Navigator.pop(context, true),

            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),

            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {

      showDialog(
        context: context,
        barrierDismissible: false,

        builder: (context) =>
        const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Deleting supplier...'),
            ],
          ),
        ),
      );

      try {

        await AppDatabase.instance
            .deleteSupplier(supplier.id!);

        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              '${supplier.name} deleted successfully',
            ),
          ),
        );

        if (onSupplierDeleted != null) {
          onSupplierDeleted!();
        }

      } catch (e) {

        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editSupplier(
      BuildContext context) async {

    final nameController =
    TextEditingController(text: supplier.name);

    final phoneController =
    TextEditingController(
      text: supplier.phone ?? "",
    );

    final emailController =
    TextEditingController(
      text: supplier.email ?? "",
    );

    final gstController =
    TextEditingController(
      text: supplier.gstNumber ?? "",
    );

    final stateController =
    TextEditingController(
      text: supplier.state ?? "",
    );

    final addressController =
    TextEditingController(
      text: supplier.address ?? "",
    );

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
              borderRadius:
              BorderRadius.circular(18.r),

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

                    Row(
                      children: [

                        Container(
                          padding: EdgeInsets.all(10.w),

                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,

                            borderRadius:
                            BorderRadius.circular(
                                12.r),
                          ),

                          child: Icon(
                            Icons.local_shipping,
                            color: app_colors.black,
                          ),
                        ),

                        SizedBox(width: 12.w),

                        Expanded(
                          child: Text(
                            "Update Supplier",

                            style: TextStyle(
                              fontSize: 18.sp,
                              fontFamily:
                              app_fonts.Medium,
                              color:
                              app_colors.black,
                            ),
                          ),
                        ),

                        InkWell(
                          onTap: () =>
                              Navigator.pop(context),
                          child:
                          const Icon(Icons.close),
                        ),
                      ],
                    ),

                    SizedBox(height: 22.h),

                    _buildField(
                      controller: nameController,
                      label: "Supplier Name",
                      icon: Icons.person,
                      validator: (v) {
                        if (v == null ||
                            v.trim().isEmpty) {
                          return "Enter supplier name";
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 14.h),

                    _buildField(
                      controller: phoneController,
                      label: "Mobile Number",
                      icon: Icons.phone,
                    ),

                    SizedBox(height: 14.h),

                    _buildField(
                      controller: emailController,
                      label: "Email",
                      icon: Icons.email_outlined,
                    ),

                    SizedBox(height: 14.h),

                    _buildField(
                      controller: gstController,
                      label: "GST Number",
                      icon: Icons.receipt_long,
                    ),

                    SizedBox(height: 14.h),

                    _buildField(
                      controller: stateController,
                      label: "State",
                      icon: Icons.location_city,
                    ),

                    SizedBox(height: 14.h),

                    _buildField(
                      controller: addressController,
                      label: "Address",
                      icon:
                      Icons.location_on_outlined,
                      maxLines: 3,
                    ),

                    SizedBox(height: 24.h),

                    Row(
                      children: [

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child:
                            const Text("Cancel"),
                          ),
                        ),

                        SizedBox(width: 12.w),

                        Expanded(
                          child: ElevatedButton(

                            style:
                            ElevatedButton
                                .styleFrom(
                              backgroundColor:
                              app_colors
                                  .table_header_bg,
                            ),

                            onPressed: () async {

                              if (!formKey
                                  .currentState!
                                  .validate()) {
                                return;
                              }

                              try {

                                final updatedSupplier =
                                SupplierModel(
                                  id: supplier.id,
                                  name:
                                  nameController
                                      .text
                                      .trim(),
                                  phone:
                                  phoneController
                                      .text
                                      .trim(),
                                  email:
                                  emailController
                                      .text
                                      .trim(),
                                  gstNumber:
                                  gstController
                                      .text
                                      .trim(),
                                  state:
                                  stateController
                                      .text
                                      .trim(),
                                  address:
                                  addressController
                                      .text
                                      .trim(),
                                );

                                await AppDatabase
                                    .instance
                                    .updateSupplier(
                                  updatedSupplier,
                                );

                                Navigator.pop(context);

                                ScaffoldMessenger.of(
                                    context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Supplier updated successfully",
                                    ),
                                  ),
                                );

                                if (onSupplierUpdated !=
                                    null) {
                                  onSupplierUpdated!();
                                }

                              } catch (e) {

                                ScaffoldMessenger.of(
                                    context)
                                    .showSnackBar(
                                  SnackBar(
                                    content:
                                    Text("$e"),
                                    backgroundColor:
                                    Colors.red,
                                  ),
                                );
                              }
                            },

                            child: Text(
                              "Update",
                              style: TextStyle(
                                color:
                                app_colors.black,
                              ),
                            ),
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

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.only(
        top: 18,
        left: 12,
        right: 12,
      ),

      child: Container(
        padding: const EdgeInsets.all(8),

        width: double.infinity,
        height: 64.h,

        decoration: BoxDecoration(
          color: app_colors.Dbackgroun_color,

          border: Border.all(
            color: app_colors.Dborder_color,
          ),

          borderRadius:
          BorderRadius.circular(10.r),
        ),

        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.center,

          children: [

            Container(
              width: 38.w,
              height: 38.h,

              decoration: BoxDecoration(
                color: Colors.grey.shade200,

                borderRadius:
                BorderRadius.circular(8.r),
              ),

              child: Icon(
                Icons.local_shipping,
                size: 20,
                color: app_colors.black,
              ),
            ),

            SizedBox(width: 12.w),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                mainAxisAlignment:
                MainAxisAlignment.center,

                children: [

                  Text(
                    supplier.name,

                    overflow:
                    TextOverflow.ellipsis,

                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.black,
                      fontFamily:
                      app_fonts.Medium,
                    ),
                  ),

                  SizedBox(height: 4.h),

                  Text(
                    supplier.phone != null
                        ? "📞 ${supplier.phone}"
                        : (supplier.email ??
                        "No contact"),

                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.black54,
                      fontFamily:
                      app_fonts.Regular,
                    ),
                  ),
                ],
              ),
            ),

            if (supplier.gstNumber != null &&
                supplier.gstNumber!
                    .isNotEmpty)

              Column(
                mainAxisAlignment:
                MainAxisAlignment.center,

                children: [

                  Text(
                    "GST",

                    style: TextStyle(
                      fontSize: 9.sp,
                      color: Colors.grey,
                    ),
                  ),

                  Text(
                    supplier.gstNumber!,

                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight:
                      FontWeight.bold,
                      color: app_colors.black,
                    ),
                  ),
                ],
              ),

            PopupMenuButton<String>(
              color: app_colors.white,

              onSelected: (value) {

                if (value == 'edit') {
                  _editSupplier(context);
                }

                else if (value == 'delete') {
                  _deleteSupplier(context);
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

                      Icon(
                        Icons.delete,
                        size: 18,
                        color:
                        app_colors.c_danger,
                      ),

                      SizedBox(width: 10.w),

                      Text(
                        "Delete",

                        style: TextStyle(
                          color:
                          app_colors.c_danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              icon: Icon(
                Icons.more_vert,
                color: app_colors.black,
              ),
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
  int maxLines = 1,
}) {

  return TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    validator: validator,
    maxLines: maxLines,

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
        borderRadius:
        BorderRadius.circular(12.r),

        borderSide: BorderSide(
          color: app_colors.Dborder_color,
        ),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12.r),

        borderSide: BorderSide(
          color: app_colors.Dborder_color,
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12.r),

        borderSide: BorderSide(
          color:
          app_colors.table_header_bg,
          width: 1.4,
        ),
      ),
    ),
  );
}