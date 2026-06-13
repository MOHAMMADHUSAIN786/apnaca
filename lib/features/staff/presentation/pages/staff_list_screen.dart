import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../database/app_database.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/app_status_bar.dart';
import 'staff_attendance_screen.dart';

class StaffListScreen extends StatefulWidget {
  const StaffListScreen({super.key});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  List<Map<String, dynamic>> _staffList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await AppDatabase.instance.getAllStaff();
    setState(() {
      _staffList = list;
      _loading = false;
    });
  }

  Future<void> _addStaff() async {
    final nameCtrl = TextEditingController();
    final roleCtrl = TextEditingController(text: 'staff');
    final phoneCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    final salaryCtrl = TextEditingController();

    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Text('Add Staff Member', style: TextStyle(fontFamily: app_fonts.Bold, color: app_colors.title, fontSize: 18.sp)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField(nameCtrl, 'Name'),
            SizedBox(height: 12.h),
            _buildDialogField(phoneCtrl, 'Phone Number', keyboardType: TextInputType.phone),
            SizedBox(height: 12.h),
            DropdownButtonFormField<String>(
              value: roleCtrl.text,
              decoration: InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              ),
              items: [
                DropdownMenuItem(value: 'admin', child: Text('Admin', style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp))),
                DropdownMenuItem(value: 'staff', child: Text('Staff', style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp))),
              ],
              onChanged: (val) => roleCtrl.text = val ?? 'staff',
            ),
            SizedBox(height: 12.h),
            _buildDialogField(pinCtrl, 'Login PIN (Optional)', keyboardType: TextInputType.number),
            SizedBox(height: 12.h),
            _buildDialogField(salaryCtrl, 'Monthly Salary', keyboardType: TextInputType.number),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: app_fonts.Medium))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: app_colors.button_bg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r))),
          onPressed: () => Navigator.pop(ctx, true), 
          child: Text('Save', style: TextStyle(color: app_colors.white, fontFamily: app_fonts.Bold))
        ),
      ],
    ));

    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      await AppDatabase.instance.insertStaff({
        'name': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'role': roleCtrl.text,
        'pin': pinCtrl.text.trim(),
        'salary': double.tryParse(salaryCtrl.text.trim()),
      });
      _load();
    }
  }

  Widget _buildDialogField(TextEditingController ctrl, String label, {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      ),
      style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppStatusBarUtils(
      color: app_colors.table_header_bg,
      child: Scaffold(
        backgroundColor: app_colors.white,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _staffList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'No staff members found.',
                          style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 16.sp, color: Colors.grey),
                        ),
                        SizedBox(height: 24.h),
                        ElevatedButton.icon(
                          onPressed: _addStaff,
                          icon: const Icon(Icons.person_add),
                          label: const Text('Add Staff'),
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
                            itemCount: _staffList.length,
                            itemBuilder: (context, i) {
                              final s = _staffList[i];
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
                                    child: Text(
                                      s['name'][0].toUpperCase(),
                                      style: TextStyle(color: app_colors.c_primary, fontFamily: app_fonts.Bold, fontSize: 18.sp),
                                    ),
                                  ),
                                  title: Text(
                                    s['name'],
                                    style: TextStyle(fontFamily: app_fonts.Bold, fontSize: 16.sp, color: app_colors.title),
                                  ),
                                  subtitle: Padding(
                                    padding: EdgeInsets.only(top: 4.h),
                                    child: Text(
                                      '${(s['role'] as String).toUpperCase()} | Phone: ${s['phone']?.isEmpty ?? true ? 'N/A' : s['phone']}',
                                      style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 12.sp, color: Colors.grey.shade600),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(Icons.co_present, color: app_colors.c_primary, size: 28.sp),
                                    tooltip: 'Attendance',
                                    onPressed: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => StaffAttendanceScreen(staffId: s['id'], staffName: s['name'])));
                                    },
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
          onPressed: _addStaff,
          label: Text('Add Staff', style: TextStyle(color: app_colors.white, fontFamily: app_fonts.Bold, fontSize: 14.sp)),
          icon: Icon(Icons.person_add, color: app_colors.white, size: 24.sp),
        ),
      ),
    );
  }
}
