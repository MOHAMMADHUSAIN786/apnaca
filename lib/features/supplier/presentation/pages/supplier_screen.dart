import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../database/app_database.dart';
import '../../model/supplier_model.dart';
import '../widgets/app_supplier_design.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => SupplierScreenState();
}

class SupplierScreenState extends State<SupplierScreen> {

  List<SupplierModel> _suppliers = [];

  bool _isLoading = true;

  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
  }

  Future<void> _fetchSuppliers() async {

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {

      final suppliers =
      await AppDatabase.instance.getAllSuppliers();

      setState(() {
        _suppliers = suppliers;
        _isLoading = false;
      });

    } catch (e) {

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void refreshSuppliers() {
    _fetchSuppliers();
  }

  Future<void> _showAddSupplierDialog(
      BuildContext context) async {

    final nameController =
    TextEditingController();

    final phoneController =
    TextEditingController();

    final emailController =
    TextEditingController();

    final gstController =
    TextEditingController();

    final stateController =
    TextEditingController();

    final addressController =
    TextEditingController();

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

                    // HEADER
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
                            "Add Supplier",

                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight:
                              FontWeight.w600,
                              color: app_colors.black,
                            ),
                          ),
                        ),

                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: const Icon(Icons.close),
                        ),
                      ],
                    ),

                    SizedBox(height: 22.h),

                    _buildSupplierField(
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

                    _buildSupplierField(
                      controller: phoneController,
                      label: "Phone",
                      icon: Icons.phone,
                    ),

                    SizedBox(height: 14.h),

                    _buildSupplierField(
                      controller: emailController,
                      label: "Email",
                      icon: Icons.email,
                    ),

                    SizedBox(height: 14.h),

                    _buildSupplierField(
                      controller: gstController,
                      label: "GST Number",
                      icon: Icons.receipt_long,
                    ),

                    SizedBox(height: 14.h),

                    _buildSupplierField(
                      controller: stateController,
                      label: "State",
                      icon: Icons.location_city,
                    ),

                    SizedBox(height: 14.h),

                    _buildSupplierField(
                      controller: addressController,
                      label: "Address",
                      icon: Icons.location_on,
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
                            child: const Text("Cancel"),
                          ),
                        ),

                        SizedBox(width: 12.w),

                        Expanded(
                          child: ElevatedButton(

                            style:
                            ElevatedButton.styleFrom(
                              backgroundColor:
                              app_colors
                                  .table_header_bg,
                            ),

                            onPressed: () async {

                              if (!formKey.currentState!
                                  .validate()) {
                                return;
                              }

                              try {

                                final supplier =
                                SupplierModel(
                                  name: nameController
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
                                    .insertSupplier(
                                    supplier);

                                Navigator.pop(context);

                                refreshSuppliers();

                                ScaffoldMessenger.of(
                                    context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Supplier added successfully",
                                    ),
                                  ),
                                );

                              } catch (e) {

                                ScaffoldMessenger.of(
                                    context)
                                    .showSnackBar(
                                  SnackBar(
                                    content:
                                    Text("$e"),
                                  ),
                                );
                              }
                            },

                            child: Text(
                              "Save",
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

  Widget _buildSupplierField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,

      decoration: InputDecoration(
        labelText: label,

        prefixIcon: Icon(icon),

        filled: true,
        fillColor: Colors.white,

        border: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: app_colors.table_header_bg,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: app_colors.title,
          ),
          onPressed: () => Navigator.pop(context, true),
        ),

        title: Text(
          'Suppliers',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: app_colors.title,
          ),
        ),
      ),

      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: 18.h,
          right: 18.w,
        ),

        child: FloatingActionButton(
          heroTag: 'fab_supplier',

          onPressed: () async {
            _showAddSupplierDialog(context);
          },

          backgroundColor:
          app_colors.table_header_bg,

          child: Icon(
            Icons.add,
            color: app_colors.black,
          ),
        ),
      ),

      body: _buildBody(),
    );
  }

  Widget _buildBody() {

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            Text('Error: $_error'),

            SizedBox(height: 16.h),

            ElevatedButton(
              onPressed: _fetchSuppliers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_suppliers.isEmpty) {

      return Center(
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,

          children: [

            Icon(
              Icons.local_shipping_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),

            SizedBox(height: 16.h),

            Text(
              'No suppliers found',
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: 80.h),

      itemCount: _suppliers.length,

      itemBuilder: (context, index) {

        final supplier = _suppliers[index];

        return AppSupplierDesign(
          supplier: supplier,
          onSupplierDeleted: _fetchSuppliers,
          onSupplierUpdated: _fetchSuppliers,
        );
      },
    );
  }
}