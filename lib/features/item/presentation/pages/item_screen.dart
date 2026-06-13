import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/app_status_bar.dart';
import '../../../../database/app_database.dart';
import '../../model/item_model.dart';
import '../bloc/item_bloc.dart';
import '../widgets/app_item_design.dart';

class ItemScreen extends StatefulWidget {
  const ItemScreen({super.key});

  @override
  State<ItemScreen> createState() => ItemScreenState();
}

class ItemScreenState extends State<ItemScreen> {
  late ItemBloc _itemBloc;

  @override
  void initState() {
    super.initState();
    _itemBloc = ItemBloc()..add(FetchItems());
  }

  @override
  void dispose() {
    _itemBloc.close();
    super.dispose();
  }

  // Method to refresh items
  void refreshItems() {
    if (!mounted) return;

    _itemBloc.add(FetchItems());
  }
  Future<void> _showAddItemDialog(BuildContext context) async {

    final nameController = TextEditingController();
    final qtyController = TextEditingController();
    final priceController = TextEditingController();
    final hsnController = TextEditingController();

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
                            Icons.add_box_rounded,
                            color: app_colors.black,
                          ),
                        ),

                        SizedBox(width: 12.w),

                        Expanded(
                          child: Text(
                            "Add Item",
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

                    // ITEM NAME
                    _buildAddField(
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

                    // QTY
                    _buildAddField(
                      controller: qtyController,
                      label: "Quantity",
                      icon: Icons.numbers,
                      keyboardType: TextInputType.number,
                    ),

                    SizedBox(height: 14.h),

                    // PRICE
                    _buildAddField(
                      controller: priceController,
                      label: "Price",
                      icon: Icons.currency_rupee,
                      keyboardType:
                      const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),

                    SizedBox(height: 14.h),

                    // HSN
                    _buildAddField(
                      controller: hsnController,
                      label: "HSN Code",
                      icon: Icons.qr_code,
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

                                final item = ItemModel(
                                  name: nameController.text.trim(),
                                  qty: int.tryParse(
                                    qtyController.text.trim(),
                                  ) ??
                                      0,
                                  price: double.tryParse(
                                    priceController.text.trim(),
                                  ) ??
                                      0,
                                  hsnCode:
                                  hsnController.text.trim().isEmpty
                                      ? null
                                      : hsnController.text.trim(),
                                );

                                await AppDatabase.instance
                                    .insertItem(item);

                                Navigator.pop(context);

                                refreshItems();

                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Item added successfully",
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

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _itemBloc,
      child: AppStatusBarUtils(
        color: app_colors.table_header_bg,
        child: Scaffold(
          backgroundColor: app_colors.white,
          floatingActionButton: Padding(
            padding: EdgeInsets.only(bottom: 18.h, right: 18.w),
            child: FloatingActionButton(
              heroTag: 'fab_item',
              onPressed: () async {
                _showAddItemDialog(context);
              },
              backgroundColor: app_colors.table_header_bg,
              child: Icon(Icons.add, color: app_colors.black),
            ),
          ),
          body: BlocBuilder<ItemBloc, ItemState>(
            builder: (context, state) {
              if (state is ItemLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is ItemError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'Error: ${state.message}',
                        style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 16.sp, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24.h),
                      ElevatedButton(
                        onPressed: refreshItems,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              } else if (state is ItemLoaded) {
                final items = state.items;
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Lottie.asset(
                          "assets/lottie/no_item.json",
                          width: 200,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          "No Items Found",
                          style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 16.sp, color: Colors.grey),
                        ),
                        SizedBox(height: 24.h),
                        ElevatedButton.icon(
                          onPressed: () => _showAddItemDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Item'),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 18, left: 8, right: 8, bottom: 80.h),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return AppItemDesign(
                              item: item,
                              onItemDeleted: refreshItems,
                              onItemUpdated: refreshItems,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}

Widget _buildAddField({
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