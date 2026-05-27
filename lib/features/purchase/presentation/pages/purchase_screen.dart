import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../database/app_database.dart';
import '../widgets/app_purchase_bill_item.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() =>
      PurchaseScreenState();
}

class PurchaseScreenState
    extends State<PurchaseScreen> {

  List<Map<String, dynamic>> _bills = [];

  bool _isLoading = true;

  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchBills();
  }

  Future<void> _fetchBills() async {

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {

      final bills = await AppDatabase.instance
          .getAllPurchaseBills();

      if (!mounted) return;

      setState(() {
        _bills = bills;
        _isLoading = false;
      });

    } catch (e) {

      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // AI CHAT refresh support
  void refreshPurchaseBills() {
    _fetchBills();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,

      body: _buildBody(),
    );
  }

  Widget _buildBody() {

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {

      return Center(
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,

          children: [

            Text("Error : $_error"),

            SizedBox(height: 16.h),

            ElevatedButton(
              onPressed: _fetchBills,
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    if (_bills.isEmpty) {

      return Center(
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,

          children: [

            Icon(
              Icons.shopping_bag_outlined,
              size: 80,
              color: Colors.grey,
            ),

            SizedBox(height: 16.h),

            Text(
              'No purchase bills found',
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchBills,

      child: ListView.builder(
        padding: EdgeInsets.only(bottom: 80.h),

        itemCount: _bills.length,

        itemBuilder: (context, index) {

          final bill = _bills[index];

          return AppPurchaseBillItem(
            billId: bill['id'],

            billNumber:
            bill['bill_number'] ?? '',

            supplierName:
            bill['supplier_name'] ??
                'Unknown Supplier',

            billDate:
            bill['bill_date'] ?? '',

            totalAmount:
            (bill['total_amount'] ?? 0)
                .toString(),

            paymentStatus:
            bill['payment_status'] ??
                'unpaid',

            onBillUpdated: _fetchBills,
          );
        },
      ),
    );
  }
}