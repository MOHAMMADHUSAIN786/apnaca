import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../database/app_database.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/app_status_bar.dart';
import 'transfer_screen.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  List<Map<String, dynamic>> _warehouses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await AppDatabase.instance.getAllWarehouses();
    setState(() {
      _warehouses = list;
      _loading = false;
    });
  }

  Future<void> _openTransfer() async {
    final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferScreen()));
    if (res == true) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppStatusBarUtils(
      color: app_colors.table_header_bg,
      child: Scaffold(
        backgroundColor: app_colors.white,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _warehouses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.warehouse_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'No warehouses found.',
                          style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 16.sp, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 18, left: 8, right: 8, bottom: 80.h),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _warehouses.length,
                            itemBuilder: (context, i) {
                              final w = _warehouses[i];
                              return Container(
                                margin: EdgeInsets.only(bottom: 12.h),
                                decoration: BoxDecoration(
                                  color: app_colors.white,
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(color: app_colors.border_color),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                  leading: CircleAvatar(
                                    backgroundColor: app_colors.LightBlue,
                                    child: Icon(Icons.warehouse, color: app_colors.c_primary, size: 24.sp),
                                  ),
                                  title: Text(
                                    w['name'] ?? '',
                                    style: TextStyle(fontFamily: app_fonts.Bold, fontSize: 16.sp, color: app_colors.title),
                                  ),
                                  subtitle: Padding(
                                    padding: EdgeInsets.only(top: 4.h),
                                    child: Text(
                                      w['location'] ?? '',
                                      style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 12.sp, color: Colors.grey.shade600),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: app_colors.button_bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
          onPressed: _openTransfer,
          label: Text('Transfer Stock', style: TextStyle(color: app_colors.white, fontFamily: app_fonts.Bold, fontSize: 14.sp)),
          icon: Icon(Icons.swap_horiz, color: app_colors.white, size: 24.sp),
        ),
      ),
    );
  }
}
