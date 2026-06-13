// lib/features/sale/presentation/pages/sale_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:apnaca/features/pos/presentation/pages/pos_screen.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_status_bar.dart';
import '../../../../database/app_database.dart';
import '../../../../core/widgets/sync_status_indicator.dart';
import '../bloc/sale_bloc.dart';
import '../bloc/sale_event.dart';
import '../bloc/sale_state.dart';
import '../widgets/app_sale_bill_item.dart';

class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key});

  @override
  State<SaleScreen> createState() => SaleScreenState();
}

class SaleScreenState extends State<SaleScreen> {

  late SaleBloc _saleBloc;
  int? _selectedWarehouseId;
  String? _selectedWarehouseName;

  // Callback — NavBar set karega taaki dashboard bhi refresh ho
  VoidCallback? onRefreshParent;

  @override
  void initState() {
    super.initState();
    _saleBloc = SaleBloc(AppDatabase.instance)..add(FetchSaleBills());
    _loadSelectedWarehouse();
  }

  Future<void> _loadSelectedWarehouse() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('current_warehouse_id');
    if (id != null) {
      final wh = await AppDatabase.instance.getWarehouseById(id);
      setState(() {
        _selectedWarehouseId = id;
        _selectedWarehouseName = wh?['name'] as String?;
      });
    }
  }

  Future<void> _chooseWarehouseDialog() async {
    final list = await AppDatabase.instance.getAllWarehouses();
    final chosen = await showDialog<Map<String, dynamic>?>(context: context, builder: (ctx) {
      return SimpleDialog(title: const Text('Select Warehouse'), children: [
        ...list.map((c) => SimpleDialogOption(
          onPressed: () => Navigator.of(ctx).pop(c),
          child: Text(c['name'] ?? 'Unnamed'),
        ))
      ]);
    });
    if (chosen != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('current_warehouse_id', chosen['id'] as int);
      setState(() {
        _selectedWarehouseId = chosen['id'] as int;
        _selectedWarehouseName = chosen['name'] as String?;
      });
    }
  }

  void refreshSales() {
    _saleBloc.add(FetchSaleBills());
  }

  // ── Called after bill edit/delete — sale list + dashboard refresh ──
  void _onBillChanged() {
    refreshSales();
    onRefreshParent?.call(); // ← dashboard ko bhi batao
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _saleBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return BlocProvider.value(
      value: _saleBloc,

          child: AppStatusBarUtils(
        color: app_colors.table_header_bg,

        child: Scaffold(
          appBar: AppBar(
            title: const Text('Sales'),
            actions: [
                // sync status indicator
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: SyncStatusIndicator(),
                ),
                IconButton(
                  tooltip: 'Choose warehouse',
                  icon: const Icon(Icons.warehouse),
                  onPressed: () => _chooseWarehouseDialog(),
                ),
                if (_selectedWarehouseName != null)
                  Padding(padding: const EdgeInsets.symmetric(horizontal:8.0), child: Center(child: Text(_selectedWarehouseName!)))
              ],
          ),
          backgroundColor: app_colors.white,

          floatingActionButton: Padding(
            padding: EdgeInsets.only(bottom: 18.h, right: 18.w),
            child: FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () async {
                final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const PosScreen()));
                // If POS saved a bill, refresh list
                if (res == true) {
                  _onBillChanged();
                }
              },
            ),
          ),

          body: BlocBuilder<SaleBloc, SaleState>(
            builder: (context, state) {

              if (state is SaleLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is SaleError) {
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
                      Text('Error: ${state.message}'),
                      ElevatedButton(
                        onPressed: () {
                          _saleBloc.add(FetchSaleBills());
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (state is SaleLoaded) {
                final bills = state.bills;

                if (bills.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt, size: 80, color: Colors.grey),
                        SizedBox(height: 16.h),
                        Text(
                          'No sale bills found',
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
                        itemCount: bills.length,
                        itemBuilder: (context, index) {
                          final bill = bills[index];
                          return AppSaleBillItem(
                            billId: bill.id,
                            billNumber: bill.billNumber,
                            partyName: bill.customerName,
                            billDate: bill.billDate,
                            totalAmount: bill.totalAmount.toStringAsFixed(2),
                            paymentStatus: bill.paymentStatus,
                            onBillUpdated: _onBillChanged,
                          );
                        },
                      ),
                    ],
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}