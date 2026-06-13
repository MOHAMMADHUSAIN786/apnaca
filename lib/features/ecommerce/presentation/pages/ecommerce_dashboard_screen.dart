import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_status_bar.dart';
import '../../../../core/constants/app_colors.dart';

class EcommerceDashboardScreen extends StatefulWidget {
  const EcommerceDashboardScreen({super.key});

  @override
  State<EcommerceDashboardScreen> createState() => _EcommerceDashboardScreenState();
}

class _EcommerceDashboardScreenState extends State<EcommerceDashboardScreen> {
  bool _isSyncing = false;

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    
    // Simulate API call to Shopify/WooCommerce
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inventory & Orders synced successfully!')),
      );
    }
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
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(Icons.storefront, size: 48, color: Colors.blue),
                        const SizedBox(height: 16),
                        const Text('Shopify / WooCommerce', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Sync your inventory and auto-generate sale bills for online orders.', textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: _isSyncing 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.sync),
                          label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                          onPressed: _isSyncing ? null : _syncNow,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 18, left: 8, right: 8, bottom: 80.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recent Sync Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: const [
                        ListTile(
                          leading: Icon(Icons.check_circle, color: Colors.green),
                          title: Text('Synced 5 orders from Shopify'),
                          subtitle: Text('Today, 10:30 AM'),
                        ),
                        ListTile(
                          leading: Icon(Icons.check_circle, color: Colors.green),
                          title: Text('Inventory updated (WooCommerce)'),
                          subtitle: Text('Yesterday, 04:15 PM'),
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
