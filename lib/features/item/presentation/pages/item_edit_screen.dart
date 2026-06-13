import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../database/app_database.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/app_status_bar.dart';
import '../../../../core/services/hardware_service.dart';
import '../../../../features/item/model/item_model.dart';

class ItemEditScreen extends StatefulWidget {
  final ItemModel? item;
  const ItemEditScreen({super.key, this.item});

  @override
  State<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends State<ItemEditScreen> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _hsn = TextEditingController();
  final _barcode = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    if (it != null) {
      _name.text = it.name;
      _price.text = (it.price ?? 0).toString();
      _hsn.text = it.hsnCode ?? '';
      _barcode.text = it.barcode ?? '';
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final price = double.tryParse(_price.text) ?? 0.0;
    final model = ItemModel(
      id: widget.item?.id,
      name: name,
      qty: widget.item?.qty ?? 0,
      price: price,
      hsnCode: _hsn.text.trim(),
      barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
    );
    if (widget.item == null) {
      await AppDatabase.instance.insertItem(model);
    } else {
      await AppDatabase.instance.updateItem(model);
    }
    setState(() => _saving = false);
    if (context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AppStatusBarUtils(
      color: app_colors.table_header_bg,
      child: Scaffold(
        backgroundColor: app_colors.white,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 18, left: 8, right: 8, bottom: 20.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: EdgeInsets.only(bottom: 24.h),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              widget.item == null ? 'Add Item' : 'Edit Item',
                              style: TextStyle(
                                fontFamily: app_fonts.Bold,
                                fontSize: 20.sp,
                                color: app_colors.title,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Form Fields
                    TextField(
                      controller: _name,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      ),
                      style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp),
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: _price,
                      decoration: InputDecoration(
                        labelText: 'Price',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      ),
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp),
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: _hsn,
                      decoration: InputDecoration(
                        labelText: 'HSN Code',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      ),
                      style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp),
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _barcode,
                            decoration: InputDecoration(
                              labelText: 'Barcode / SKU',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                            ),
                            style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: app_colors.border_color),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: IconButton(
                            tooltip: 'Scan barcode',
                            onPressed: () async {
                              final code = await HardwareService.instance.scanBarcode(context: context);
                              if (code != null && code.isNotEmpty) {
                                setState(() => _barcode.text = code);
                              }
                            },
                            icon: Icon(Icons.qr_code_scanner, color: app_colors.c_primary),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 32.h),
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                            ),
                            onPressed: _saving ? null : () => Navigator.pop(context),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: app_colors.title, fontFamily: app_fonts.Medium),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: app_colors.button_bg,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                            ),
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(
                                    'Save',
                                    style: TextStyle(color: app_colors.white, fontFamily: app_fonts.Bold),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
