import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_status_bar.dart';
import '../../../../core/constants/app_colors.dart';

class CrmDashboardScreen extends StatefulWidget {
  const CrmDashboardScreen({super.key});

  @override
  State<CrmDashboardScreen> createState() => _CrmDashboardScreenState();
}

class _CrmDashboardScreenState extends State<CrmDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return AppStatusBarUtils(
      color: app_colors.table_header_bg,
      child: Scaffold(
        backgroundColor: app_colors.white,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 18.h, left: 8.w, right: 8.w),
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: Colors.orange.shade50,
                        child: const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text('Open Leads', style: TextStyle(color: Colors.orange)),
                              SizedBox(height: 8),
                              Text('12', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        color: Colors.red.shade50,
                        child: const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text('Pending Follow-ups', style: TextStyle(color: Colors.red)),
                              SizedBox(height: 8),
                              Text('5', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 18.h, left: 8.w, right: 8.w),
                child: const Text('Today\'s Follow-ups', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: EdgeInsets.only(top: 18.h, left: 8.w, right: 8.w, bottom: 80.h),
                child: ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: const Text('Rahul Sharma (Lead)'),
                        subtitle: const Text('Call regarding bulk AC order\nDue Today at 4:00 PM'),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.phone, color: Colors.green), onPressed: () {}),
                            IconButton(icon: const Icon(Icons.check_circle_outline), onPressed: () {}),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: const Text('Neha Gupta'),
                        subtitle: const Text('Send quotation for laptops\nDue Today at 5:30 PM'),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.mail, color: Colors.blue), onPressed: () {}),
                            IconButton(icon: const Icon(Icons.check_circle_outline), onPressed: () {}),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('New Lead'),
        ),
      ),
    );
  }
}
