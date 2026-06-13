import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../database/app_database.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/app_status_bar.dart';

class StaffAttendanceScreen extends StatefulWidget {
  final int staffId;
  final String staffName;
  const StaffAttendanceScreen({super.key, required this.staffId, required this.staffName});

  @override
  State<StaffAttendanceScreen> createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends State<StaffAttendanceScreen> {
  List<Map<String, dynamic>> _attendance = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await AppDatabase.instance.getStaffAttendance(widget.staffId);
    setState(() {
      _attendance = list;
      _loading = false;
    });
  }

  Future<void> _markAttendance() async {
    final statusCtrl = TextEditingController(text: 'present');
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Text('Mark Attendance', style: TextStyle(fontFamily: app_fonts.Bold, color: app_colors.title, fontSize: 18.sp)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: statusCtrl.text,
            decoration: InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            ),
            items: [
              DropdownMenuItem(value: 'present', child: Text('Present', style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp))),
              DropdownMenuItem(value: 'half-day', child: Text('Half Day', style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp))),
              DropdownMenuItem(value: 'absent', child: Text('Absent', style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp))),
            ],
            onChanged: (val) => statusCtrl.text = val ?? 'present',
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: notesCtrl, 
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            ),
            style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp),
          ),
        ],
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

    if (ok == true) {
      await AppDatabase.instance.insertStaffAttendance({
        'staff_id': widget.staffId,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'status': statusCtrl.text,
        'notes': notesCtrl.text.trim(),
      });
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
            : _attendance.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.assignment_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'No attendance records found.',
                          style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 16.sp, color: Colors.grey),
                        ),
                        SizedBox(height: 24.h),
                        ElevatedButton.icon(
                          onPressed: _markAttendance,
                          icon: const Icon(Icons.fact_check),
                          label: const Text('Mark Attendance'),
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
                            itemCount: _attendance.length,
                            itemBuilder: (context, i) {
                              final a = _attendance[i];
                              final isPresent = a['status'] == 'present';
                              final isHalf = a['status'] == 'half-day';

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
                                    backgroundColor: isPresent ? app_colors.LightGreen : (isHalf ? app_colors.LightOrange : app_colors.RedColor),
                                    child: Icon(
                                      isPresent ? Icons.check_circle : (isHalf ? Icons.timelapse : Icons.cancel),
                                      color: isPresent ? app_colors.GreenColor : (isHalf ? app_colors.OrangeColor : app_colors.c_danger),
                                      size: 24.sp,
                                    ),
                                  ),
                                  title: Text(
                                    a['date'],
                                    style: TextStyle(fontFamily: app_fonts.Bold, fontSize: 16.sp, color: app_colors.title),
                                  ),
                                  subtitle: a['notes']?.isNotEmpty == true
                                      ? Padding(
                                          padding: EdgeInsets.only(top: 4.h),
                                          child: Text(a['notes'], style: TextStyle(fontFamily: app_fonts.Regular, fontSize: 12.sp, color: Colors.grey.shade600)),
                                        )
                                      : null,
                                  trailing: Text(
                                    (a['status'] as String).toUpperCase(),
                                    style: TextStyle(
                                      fontFamily: app_fonts.Bold,
                                      fontSize: 14.sp,
                                      color: isPresent ? app_colors.GreenColor : (isHalf ? app_colors.OrangeColor : app_colors.c_danger),
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
          onPressed: _markAttendance,
          label: Text('Mark Today', style: TextStyle(color: app_colors.white, fontFamily: app_fonts.Bold, fontSize: 14.sp)),
          icon: Icon(Icons.fact_check, color: app_colors.white, size: 24.sp),
        ),
      ),
    );
  }
}
