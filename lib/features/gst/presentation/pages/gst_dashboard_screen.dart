import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_status_bar.dart';
import '../../../../core/constants/app_colors.dart';

class GstDashboardScreen extends StatefulWidget {
  const GstDashboardScreen({super.key});

  @override
  State<GstDashboardScreen> createState() => _GstDashboardScreenState();
}

class _GstDashboardScreenState extends State<GstDashboardScreen> {
  final _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  String _selectedMonth = 'June';
  bool _isLoading = false;

  void _calculateGst() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);
  }

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
                padding: const EdgeInsets.only(top: 18, left: 8, right: 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('Generate GST Returns', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedMonth,
                          decoration: const InputDecoration(labelText: 'Select Period'),
                          items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _selectedMonth = v);
                              _calculateGst();
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        _isLoading 
                          ? const CircularProgressIndicator()
                          : Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.receipt_long, color: Colors.blue),
                                  title: const Text('GSTR-1 (Outward Supplies)'),
                                  subtitle: const Text('Total B2B & B2C sales'),
                                  trailing: ElevatedButton(onPressed: () {}, child: const Text('View')),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.request_quote, color: Colors.orange),
                                  title: const Text('GSTR-2B (Inward Supplies)'),
                                  subtitle: const Text('ITC available from purchases'),
                                  trailing: ElevatedButton(onPressed: () {}, child: const Text('View')),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.account_balance, color: Colors.green),
                                  title: const Text('GSTR-3B (Summary)'),
                                  subtitle: const Text('Net tax liability'),
                                  trailing: ElevatedButton(onPressed: () {}, child: const Text('File')),
                                ),
                              ],
                            )
                       ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 18, left: 8, right: 8, bottom: 80.h),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.qr_code, size: 40, color: Colors.purple),
                    title: const Text('E-Invoicing & E-Way Bill'),
                    subtitle: const Text('Generate IRN and Part-A/Part-B slips'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // Navigate to E-Invoice screen
                    },
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
