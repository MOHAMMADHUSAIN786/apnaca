// lib/features/home/presentation/bloc/home_state.dart
part of 'home_bloc.dart';

abstract class HomeState extends Equatable {
  const HomeState();
  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final double youWillReceive;
  final double youWillPay;
  final double totalSale;
  final double totalPurchase;
  final double totalExpense;
  final double saleThisMonth;
  final double saleLastMonth;
  final double purchaseThisMonth;
  final double purchaseLastMonth;
  final double expenseThisMonth;
  final double expenseLastMonth;
  final double percentageChangeSale;
  final double percentageChangePurchase;
  final double percentageChangeExpense;

  const HomeLoaded({
    required this.youWillReceive,
    required this.youWillPay,
    required this.totalSale,
    required this.totalPurchase,
    required this.totalExpense,
    required this.saleThisMonth,
    required this.saleLastMonth,
    required this.purchaseThisMonth,
    required this.purchaseLastMonth,
    required this.expenseThisMonth,
    required this.expenseLastMonth,
    required this.percentageChangeSale,
    required this.percentageChangePurchase,
    required this.percentageChangeExpense,
  });

  @override
  List<Object?> get props => [
    youWillReceive,
    youWillPay,
    totalSale,
    totalPurchase,
    totalExpense,
    saleThisMonth,
    saleLastMonth,
    purchaseThisMonth,
    purchaseLastMonth,
    expenseThisMonth,
    expenseLastMonth,
  ];
}

class HomeError extends HomeState {
  final String message;
  const HomeError(this.message);
  @override
  List<Object?> get props => [message];
}