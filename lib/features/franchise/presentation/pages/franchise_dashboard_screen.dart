import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_status_bar.dart';
import '../../../../core/constants/app_colors.dart';

class FranchiseDashboardScreen extends StatefulWidget {
  const FranchiseDashboardScreen({super.key});

  @override
  State<FranchiseDashboardScreen> createState() => _FranchiseDashboardScreenState();
}

class _FranchiseDashboardScreenState extends State<FranchiseDashboardScreen> {
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
                padding: const EdgeInsets.only(top: 18, left: 8, right: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: Colors.blue.shade50,
                        child: const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text('Active Outlets', style: TextStyle(color: Colors.blue)),
                              SizedBox(height: 8),
                              Text('5', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        color: Colors.green.shade50,
                        child: const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text('Total Royalty', style: TextStyle(color: Colors.green)),
                              SizedBox(height: 8),
                              Text('₹1.2L', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 18, left: 8, right: 8),
                child: const Text('Franchise Outlets', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: EdgeInsets.only(top: 18, left: 8, right: 8, bottom: 80.h),
                child: ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: const [
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.store, color: Colors.blue),
                        title: Text('Store #1 - Mumbai South'),
                        subtitle: Text('Sales: ₹50,000 | Royalty Due: ₹2,500'),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.store, color: Colors.blue),
                        title: Text('Store #2 - Pune Central'),
                        subtitle: Text('Sales: ₹35,000 | Royalty Due: ₹1,750'),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
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
          label: const Text('Add Outlet'),
        ),
      ),
    );
  }
}
