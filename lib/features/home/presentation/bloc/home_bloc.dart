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

      // ─── SALE BILLS ───────────────────────────────────────────────
      final saleBills = await _db.getAllSaleBills();

      double totalSale      = 0;
      double youWillReceive = 0;
      double saleThisMonth  = 0;
      double saleLastMonth  = 0;

      final now          = DateTime.now();
      final currentYear  = now.year;
      final currentMonth = now.month;

      int lastMonthYear = currentYear;
      int lastMonth     = currentMonth - 1;
      if (lastMonth == 0) {
        lastMonth     = 12;
        lastMonthYear = currentYear - 1;
      }

      for (final bill in saleBills) {
        final amount = (bill['total_amount'] as num?)?.toDouble() ?? 0;
        final status = (bill['payment_status']?.toString() ?? 'unpaid').toLowerCase();

        totalSale += amount;

        // YOU'LL RECEIVE — unpaid/partial bills
        if (status == 'unpaid' || status == 'pending' || status == 'partial') {
          youWillReceive += amount;
        }

        // Monthly breakdown
        final billDate = DateTime.tryParse(bill['bill_date']?.toString() ?? '');
        if (billDate != null) {
          if (billDate.year == currentYear && billDate.month == currentMonth) {
            saleThisMonth += amount;
          }
          if (billDate.year == lastMonthYear && billDate.month == lastMonth) {
            saleLastMonth += amount;
          }
        }
      }

      // ─── PURCHASE BILLS ───────────────────────────────────────────
      final purchaseBills = await _db.getAllPurchaseBills();

      double totalPurchase      = 0;
      double youWillPay         = 0;
      double purchaseThisMonth  = 0;
      double purchaseLastMonth  = 0;

      for (final bill in purchaseBills) {
        final amount = (bill['total_amount'] as num?)?.toDouble() ?? 0;
        final status = (bill['payment_status']?.toString() ?? 'unpaid').toLowerCase();

        totalPurchase += amount;

        // YOU'LL PAY — unpaid/partial purchase bills
        if (status == 'unpaid' || status == 'pending' || status == 'partial') {
          youWillPay += amount;
        }

        // Monthly breakdown
        final billDate = DateTime.tryParse(bill['bill_date']?.toString() ?? '');
        if (billDate != null) {
          if (billDate.year == currentYear && billDate.month == currentMonth) {
            purchaseThisMonth += amount;
          }
          if (billDate.year == lastMonthYear && billDate.month == lastMonth) {
            purchaseLastMonth += amount;
          }
        }
      }

      // ─── PERCENTAGE CHANGE CALCULATIONS ──────────────────────────
      double percentageChangeSale = 0;
      if (saleLastMonth > 0) {
        percentageChangeSale = ((saleThisMonth - saleLastMonth) / saleLastMonth) * 100;
      } else if (saleThisMonth > 0) {
        percentageChangeSale = 100;
      }

      double percentageChangePurchase = 0;
      if (purchaseLastMonth > 0) {
        percentageChangePurchase = ((purchaseThisMonth - purchaseLastMonth) / purchaseLastMonth) * 100;
      } else if (purchaseThisMonth > 0) {
        percentageChangePurchase = 100;
      }

      // ─── EXPENSES ─────────────────────────────────────────────────
      final totalExpense       = await _db.getTotalExpenseAllTime();
      final expenseThisMonth   = await _db.getTotalExpenseThisMonth();
      final expenseLastMonth   = await _db.getTotalExpenseLastMonth();

      double percentageChangeExpense = 0;
      if (expenseLastMonth > 0) {
        percentageChangeExpense =
            ((expenseThisMonth - expenseLastMonth) / expenseLastMonth) * 100;
      } else if (expenseThisMonth > 0) {
        percentageChangeExpense = 100;
      }

      emit(
        HomeLoaded(
          youWillReceive:           youWillReceive,
          youWillPay:               youWillPay,
          totalSale:                totalSale,
          totalPurchase:            totalPurchase,
          totalExpense:             totalExpense,
          saleThisMonth:            saleThisMonth,
          saleLastMonth:            saleLastMonth,
          purchaseThisMonth:        purchaseThisMonth,
          purchaseLastMonth:        purchaseLastMonth,
          expenseThisMonth:         expenseThisMonth,
          expenseLastMonth:         expenseLastMonth,
          percentageChangeSale:     percentageChangeSale,
          percentageChangePurchase: percentageChangePurchase,
          percentageChangeExpense:  percentageChangeExpense,
        ),
      );

    } catch (e) {
      print('HomeBloc Error: $e');
      emit(HomeError(e.toString()));
    }
  }
}