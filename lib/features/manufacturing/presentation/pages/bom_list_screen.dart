import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../database/app_database.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import 'create_bom_screen.dart';
import 'production_order_screen.dart';

class BomListScreen extends StatefulWidget {
  const BomListScreen({super.key});

  @override
  State<BomListScreen> createState() => _BomListScreenState();
}

class _BomListScreenState extends State<BomListScreen> {
  List<Map<String, dynamic>> _boms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await AppDatabase.instance.getAllBoms();
    setState(() {
      _boms = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: app_colors.backgroun_color,
      appBar: AppBar(
        backgroundColor: app_colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: app_colors.black),
        title: Text(
          'Bill of Materials (BOM)',
          style: TextStyle(
            color: app_colors.title,
            fontFamily: app_fonts.Bold,
            fontSize: 18.sp,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.precision_manufacturing, color: app_colors.c_primary, size: 24.sp),
            tooltip: 'Production Orders',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductionOrderScreen()));
            },
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: app_colors.c_primary))
          : _boms.isEmpty
              ? Center(
                  child: Text(
                    'No BOMs found.',
                    style: TextStyle(
                      fontFamily: app_fonts.Medium,
                      fontSize: 16.sp,
                      color: Colors.grey,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  itemCount: _boms.length,
                  itemBuilder: (context, i) {
                    final b = _boms[i];
                    return Container(
                      margin: EdgeInsets.only(bottom: 12.h),
                      decoration: BoxDecoration(
                        color: app_colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: app_colors.border_color),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        leading: Container(
                          padding: EdgeInsets.all(10.w),
                          decoration: BoxDecoration(
                            color: app_colors.LightBlue,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(Icons.account_tree, color: app_colors.c_primary, size: 20.sp),
                        ),
                        title: Text(
                          b['name'] ?? '',
                          style: TextStyle(
                            fontFamily: app_fonts.Bold,
                            fontSize: 15.sp,
                            color: app_colors.title,
                          ),
                        ),
                        subtitle: Padding(
                          padding: EdgeInsets.only(top: 4.h),
                          child: Text(
                            'Finished Item: ${b['finished_item_name']}',
                            style: TextStyle(
                              fontFamily: app_fonts.Regular,
                              fontSize: 12.sp,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        trailing: Icon(Icons.chevron_right, color: Colors.grey, size: 24.sp),
                        onTap: () {
                          // View details logic
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: app_colors.button_bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
        onPressed: () async {
          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateBomScreen()));
          if (res == true) _load();
        },
        child: Icon(Icons.add, color: app_colors.white, size: 28.sp),
      ),
    );
  }
}
