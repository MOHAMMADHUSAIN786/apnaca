// lib/features/sale/presentation/pages/sale_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/widgets/common_widgets/app_status_bar.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../database/app_database.dart';
import '../bloc/sale_bloc.dart';
import '../bloc/sale_event.dart';
import '../bloc/sale_state.dart';
import '../widgets/app_sale_bill_item.dart';
import 'create_sale_bill_screen.dart';

class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key});

  @override
  State<SaleScreen> createState() => SaleScreenState();
}

class SaleScreenState extends State<SaleScreen> {
  late SaleBloc _saleBloc;

  // Callback — NavBar set karega taaki dashboard bhi refresh ho
  VoidCallback? onRefreshParent;

  @override
  void initState() {
    super.initState();
    _saleBloc = SaleBloc(AppDatabase.instance)..add(FetchSaleBills());
  }

  void refreshSales() {
    _saleBloc.add(FetchSaleBills());
  }

  void _onBillChanged() {
    refreshSales();
    onRefreshParent?.call();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _saleBloc.close();
    super.dispose();
  }

  // ── Open Create Sale Bill screen ─────────────────────────────────
  void _openCreateBill() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateSaleBillScreen(onBillCreated: _onBillChanged),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _saleBloc,

      child: AppStatusBarUtils(
        color: app_colors.table_header_bg,

        child: Scaffold(
          backgroundColor: app_colors.white,

          // ── FAB — hidden for viewers ─────────────────────────────
          floatingActionButton: PermissionService.instance.canCreateSaleBills
              ? Padding(
                  padding: EdgeInsets.only(bottom: 18.h, right: 4.w),
                  child: FloatingActionButton(
                    heroTag: 'fab_sale_bill',
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
              Expanded(
                child: BlocBuilder<SaleBloc, SaleState>(
                  builder: (context, state) {
                    if (state is SaleLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state is SaleLoaded) {
                      final bills = state.bills;

                      if (bills.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 80,
                                color: Colors.grey.shade300,
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                'Koi sale bill nahi mila',
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  color: Colors.grey.shade500,
                                  fontFamily: app_fonts.Medium,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Naya bill banane ke liye + button dabayein',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              SizedBox(height: 24.h),
                              // Hide create button for viewers
                              if (PermissionService.instance.canCreateSaleBills)
                                ElevatedButton.icon(
                                  onPressed: _openCreateBill,
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.black,
                                  ),
                                  label: Text(
                                    'Create Sale Bill',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontFamily: app_fonts.Medium,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: app_colors.table_header_bg,
                                    elevation: 0,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 20.w,
                                      vertical: 12.h,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async => refreshSales(),
                        child: ListView.builder(
                          padding: EdgeInsets.only(bottom: 100.h),
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
                      );
                    }

                    if (state is SaleError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: app_colors.c_danger,
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              'Error: ${state.message}',
                              style: TextStyle(fontSize: 13.sp),
                            ),
                            SizedBox(height: 12.h),
                            ElevatedButton(
                              onPressed: refreshSales,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: app_colors.table_header_bg,
                                elevation: 0,
                              ),
                              child: const Text(
                                'Retry',
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
