import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../database/app_database.dart';
import '../../../item/model/item_model.dart';
import '../../model/customer_model.dart';
import '../widgets/app_customer_design.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  List<CustomerModel> _customers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final customers = await AppDatabase.instance.getAllCustomers();
      setState(() {
        _customers = customers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Public method to refresh from outside (e.g., from NavBar after chat)
  void refreshCustomers() {
    _fetchCustomers();
  }
  Future<void> _showAddCustomerDialog(BuildContext context) async {

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final gstController = TextEditingController();
    final stateController = TextEditingController();
    final addressController = TextEditingController();

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
                            Icons.person_add_alt_1,
                            color: app_colors.black,
                          ),
                        ),

                        SizedBox(width: 12.w),

                        Expanded(
                          child: Text(
                            "Add Customer",
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
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

                    // NAME
                    _buildAddCustomerField(
                      controller: nameController,
                      label: "Customer Name",
                      icon: Icons.person_outline,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return "Enter customer name";
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 14.h),

                    // PHONE
                    _buildAddCustomerField(
                      controller: phoneController,
                      label: "Mobile Number",
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),

                    SizedBox(height: 14.h),

                    // EMAIL
                    _buildAddCustomerField(
                      controller: emailController,
                      label: "Email",
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),

                    SizedBox(height: 14.h),

                    // GST
                    _buildAddCustomerField(
                      controller: gstController,
                      label: "GST Number",
                      icon: Icons.receipt_long,
                    ),

                    SizedBox(height: 14.h),

                    // STATE
                    _buildAddCustomerField(
                      controller: stateController,
                      label: "State",
                      icon: Icons.location_city,
                    ),

                    SizedBox(height: 14.h),

                    // ADDRESS
                    _buildAddCustomerField(
                      controller: addressController,
                      label: "Address",
                      icon: Icons.location_on_outlined,
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

                        // SAVE
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

                              if (!formKey.currentState!.validate()) {
                                return;
                              }

                              try {

                                final customer = CustomerModel(
                                  name: nameController.text.trim(),
                                  phone: phoneController.text.trim(),
                                  email: emailController.text.trim(),
                                  gstNumber: gstController.text.trim(),
                                  state: stateController.text.trim(),
                                  address: addressController.text.trim(),
                                );

                                await AppDatabase.instance
                                    .insertCustomer(customer);

                                Navigator.pop(context);

                                refreshCustomers();

                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Customer added successfully",
                                    ),
                                  ),
                                );

                              } catch (e) {

                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text("Failed: $e"),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },

                            child: Text(
                              "Save",
                              style: TextStyle(
                                color: app_colors.black,
                                fontWeight: FontWeight.w600,
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

  Widget _buildAddCustomerField({
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
        prefixIcon: Icon(icon),

        filled: true,
        fillColor: Colors.white,

        contentPadding: EdgeInsets.symmetric(
          horizontal: 14.w,
          vertical: 14.h,
        ),

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: app_colors.table_header_bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: app_colors.title),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(
          'Customers',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: app_colors.title),
        ),
      ),
      floatingActionButton: PermissionService.instance.canManageCustomers
          ? Padding(
        padding: EdgeInsets.only(bottom: 18.h, right: 18.w),
        child: FloatingActionButton(
          heroTag: 'fab_customer',
          onPressed: () async {
            _showAddCustomerDialog(context);
          },
          backgroundColor: app_colors.table_header_bg,
          child: Icon(Icons.add, color: app_colors.black),
        ),
      )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            SizedBox(height: 16.h),
            ElevatedButton(onPressed: _fetchCustomers, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            SizedBox(height: 16.h),
            Text('No customers found', style: TextStyle(fontSize: 16.sp, color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 80.h),
      itemCount: _customers.length,
      itemBuilder: (context, index) {
        final customer = _customers[index];
        return AppCustomerDesign(
          customer: customer,
          onCustomerDeleted: _fetchCustomers,
          onCustomerUpdated: _fetchCustomers,
        );
      },
    );
  }
}
