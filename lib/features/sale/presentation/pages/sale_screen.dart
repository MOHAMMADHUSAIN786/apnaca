// lib/features/sale/presentation/pages/sale_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_status_bar.dart';
import '../../../../database/app_database.dart';
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

  @override
  void initState() {
    super.initState();

    _saleBloc = SaleBloc(AppDatabase.instance)
      ..add(FetchSaleBills());
  }

  void refreshSales() {
    _saleBloc.add(FetchSaleBills());
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
          backgroundColor: app_colors.white,

          floatingActionButton: Padding(
            padding: EdgeInsets.only(bottom: 18.h, right: 18.w),
          ),

          body: BlocBuilder<SaleBloc, SaleState>(
            builder: (context, state) {

              if (state is SaleLoading) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              else if (state is SaleLoaded) {

                final bills = state.bills;

                if (bills.isEmpty) {

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        Icon(
                          Icons.receipt,
                          size: 80,
                          color: Colors.grey,
                        ),

                        SizedBox(height: 16.h),

                        Text(
                          'No sale bills found',
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.only(bottom: 80.h),
                  itemCount: bills.length,

                  itemBuilder: (context, index) {

                    final bill = bills[index];

                    return AppSaleBillItem(
                      billId: bill.id,
                      billNumber: bill.billNumber,
                      partyName: bill.customerName,
                      billDate: bill.billDate,
                      totalAmount:
                      bill.totalAmount.toStringAsFixed(2),
                      paymentStatus: bill.paymentStatus,

                      onBillUpdated: () {

                        refreshSales();

                        // rebuild parent screens too
                        if (mounted) {
                          setState(() {});
                        }
                      },
                    );
                  },
                );
              }

              else if (state is SaleError) {

                return Center(
                  child: Text('Error: ${state.message}'),
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