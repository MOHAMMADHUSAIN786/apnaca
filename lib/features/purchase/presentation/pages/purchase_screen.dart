// lib/features/purchase/presentation/pages/purchase_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../database/app_database.dart';
import '../widgets/app_purchase_bill_item.dart';
import 'create_purchase_bill_screen.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => PurchaseScreenState();
}

class PurchaseScreenState extends State<PurchaseScreen> {

  List<Map<String, dynamic>> _bills = [];
  bool _isLoading = true;
  String? _error;

  // Callback — NavBar inhe set karega
  VoidCallback? onRefreshParent;

  @override
  void initState() {
    super.initState();
    _fetchBills();
  }

  Future<void> _fetchBills() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      final bills = await AppDatabase.instance.getAllPurchaseBills();
      if (!mounted) return;
      setState(() { _bills = bills; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void refreshPurchaseBills() => _fetchBills();

  void _onBillChanged() {
    _fetchBills();
    onRefreshParent?.call();
  }

  // ── Open Create Purchase Bill screen ─────────────────────────────
  void _openCreateBill() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePurchaseBillScreen(
          onBillCreated: _onBillChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // ── FAB — hidden for viewers ────────────────────────────────
      floatingActionButton: PermissionService.instance.canCreatePurchaseBills
          ? Padding(
        padding: EdgeInsets.only(bottom: 18.h, right: 4.w),
        child: FloatingActionButton(
          heroTag: 'fab_purchase_bill',
          onPressed: _openCreateBill,
          backgroundColor: app_colors.table_header_bg,
          elevation: 2,
          child: Icon(Icons.add, color: Colors.black),
        ),
      )
          : null,

      body: Column(
        children: [
          const ViewOnlyBanner(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: app_colors.c_danger),
            SizedBox(height: 12.h),
            Text("Error: $_error", style: TextStyle(fontSize: 13.sp)),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _fetchBills,
              style: ElevatedButton.styleFrom(
                  backgroundColor: app_colors.table_header_bg, elevation: 0),
              child: const Text('Retry', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
    }

    if (_bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey.shade300),
            SizedBox(height: 16.h),
            Text(
              'Koi purchase bill nahi mila',
              style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade500,
                  fontFamily: app_fonts.Medium),
            ),
            SizedBox(height: 8.h),
            Text(
              'Naya bill banane ke liye + button dabayein',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade400),
            ),
            SizedBox(height: 24.h),
            // Hide create button for viewers
            if (PermissionService.instance.canCreatePurchaseBills)
              ElevatedButton.icon(
                onPressed: _openCreateBill,
                icon: const Icon(Icons.add, color: Colors.black),
                label: Text('Create Purchase Bill',
                    style: TextStyle(color: Colors.black, fontFamily: app_fonts.Medium)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: app_colors.table_header_bg,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchBills,
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: 100.h),
        itemCount: _bills.length,
        itemBuilder: (context, index) {
          final bill = _bills[index];
          return AppPurchaseBillItem(
            billId:        bill['id'],
            billNumber:    bill['bill_number'] ?? '',
            supplierName:  bill['supplier_name'] ?? 'Unknown Supplier',
            billDate:      bill['bill_date'] ?? '',
            totalAmount:   (bill['total_amount'] ?? 0).toString(),
            paymentStatus: bill['payment_status'] ?? 'unpaid',
            onBillUpdated: _onBillChanged,
          );
        },
      ),
    );
  }
}