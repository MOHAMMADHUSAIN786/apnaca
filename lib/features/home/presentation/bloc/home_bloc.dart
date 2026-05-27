// lib/features/home/presentation/bloc/home_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../database/app_database.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final AppDatabase _db;

  HomeBloc(this._db) : super(HomeInitial()) {
    on<FetchHomeData>(_onFetchHomeData);
  }

  Future<void> _onFetchHomeData(
      FetchHomeData event,
      Emitter<HomeState> emit,
      ) async {

    emit(HomeLoading());

    try {

      // Get all sale bills
      final saleBills =
      await _db.getAllSaleBills();

      double totalSale = 0;

      double youWillReceive = 0;

      double paidAmount = 0;

      final now = DateTime.now();

      final currentYear = now.year;

      final currentMonth = now.month;

      double saleThisMonth = 0;

      double saleLastMonth = 0;

      int lastMonthYear = currentYear;

      int lastMonth = currentMonth - 1;

      if (lastMonth == 0) {
        lastMonth = 12;
        lastMonthYear = currentYear - 1;
      }

      for (final bill in saleBills) {

        final amount =
            (bill['total_amount'] as num?)
                ?.toDouble() ??
                0;

        final status =
        (bill['payment_status']
            ?.toString() ??
            'unpaid')
            .toLowerCase();

        // TOTAL SALE
        totalSale += amount;

        // YOU'LL RECEIVE
        if (status == 'unpaid' ||
            status == 'pending' ||
            status == 'partial') {

          youWillReceive += amount;
        }

        // PAID AMOUNT
        if (status == 'paid') {
          paidAmount += amount;
        }

        // DATE PARSE

        final billDate =
        DateTime.tryParse(
          bill['bill_date']
              ?.toString() ??
              '',
        );

        if (billDate != null) {

          // CURRENT MONTH
          if (billDate.year == currentYear &&
              billDate.month == currentMonth) {

            saleThisMonth += amount;
          }

          // LAST MONTH
          if (billDate.year == lastMonthYear &&
              billDate.month == lastMonth) {

            saleLastMonth += amount;
          }
        }
      }

      print('=== HOME CALCULATION ===');

      print('Total Sale: ₹$totalSale');

      print('Paid Amount: ₹$paidAmount');

      print(
          'You Will Receive: ₹$youWillReceive');

      print('========================');

      double percentageChangeSale = 0;

      if (saleLastMonth > 0) {

        percentageChangeSale =
            ((saleThisMonth - saleLastMonth) /
                saleLastMonth) *
                100;

      } else if (saleThisMonth > 0) {

        percentageChangeSale = 100;
      }

      emit(
        HomeLoaded(
          youWillReceive:
          youWillReceive,

          youWillPay: 0,

          totalSale: totalSale,

          totalPurchase: 0,

          totalExpense: 0,

          saleThisMonth:
          saleThisMonth,

          saleLastMonth:
          saleLastMonth,

          purchaseThisMonth: 0,

          purchaseLastMonth: 0,

          expenseThisMonth: 0,

          expenseLastMonth: 0,

          percentageChangeSale:
          percentageChangeSale,

          percentageChangePurchase: 0,

          percentageChangeExpense: 0,
        ),
      );

    } catch (e) {

      print('HomeBloc Error: $e');

      emit(HomeError(e.toString()));
    }
  }
}