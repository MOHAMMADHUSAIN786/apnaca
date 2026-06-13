import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_status_bar.dart';
import '../../../../database/app_database.dart';
import '../widgets/app_purchase_bill_item.dart';
import 'purchase_quick_screen.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => PurchaseScreenState();
}

class PurchaseScreenState extends State<PurchaseScreen> {

  List<Map<String, dynamic>> _bills = [];
  bool _isLoading = true;
  String? _error;

  // Callback — NavBar inhe set karega taaki dashboard bhi refresh ho
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

  // ── Called by NavBar (AI chat return) + internal bill edit/delete ──
  void refreshPurchaseBills() => _fetchBills();

  // ── Called after edit/delete to also refresh dashboard ────────────
  void _onBillChanged() {
    _fetchBills();
    onRefreshParent?.call(); // ← dashboard ko bhi batao
  }

  @override
  Widget build(BuildContext context) {
    return AppStatusBarUtils(
      color: app_colors.table_header_bg,
      child: Scaffold(
        backgroundColor: app_colors.white,
        appBar: AppBar(
          backgroundColor: app_colors.table_header_bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
            onPressed: () => Navigator.pop(context, true),
          ),
          title: Text(
            'Purchases',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: Colors.black),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black),
              onPressed: _fetchBills,
            ),
          ],
        ),
        floatingActionButton: Padding(
          padding: EdgeInsets.only(bottom: 18.h, right: 18.w),
          child: FloatingActionButton(
            child: const Icon(Icons.add_shopping_cart),
            onPressed: () async {
              final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseQuickScreen()));
              if (res == true) _onBillChanged();
            },
          ),
        ),
        body: _buildBody(),
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
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            SizedBox(height: 16.h),
            Text("Error: $_error"),
            SizedBox(height: 16.h),
            ElevatedButton(onPressed: _fetchBills, child: const Text("Retry")),
          ],
        ),
      );
    }

    if (_bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16.h),
            Text(
              'No purchase bills found',
              style: TextStyle(fontSize: 16.sp, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.only(top: 18, left: 8, right: 8, bottom: 80.h),
            itemCount: _bills.length,
            itemBuilder: (context, index) {
              final bill = _bills[index];
              return AppPurchaseBillItem(
                billId: bill['id'],
                billNumber: bill['bill_number'] ?? '',
                supplierName: bill['supplier_name'] ?? 'Unknown Supplier',
                billDate: bill['bill_date'] ?? '',
                totalAmount: (bill['total_amount'] ?? 0).toString(),
                paymentStatus: bill['payment_status'] ?? 'unpaid',
                onBillUpdated: _onBillChanged,
              );
            },
          ),
        ],
      ),
    );
  }
}