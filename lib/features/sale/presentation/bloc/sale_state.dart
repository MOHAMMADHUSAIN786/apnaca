import 'package:equatable/equatable.dart';
import '../../model/sale_bill_model.dart';

abstract class SaleState extends Equatable {
  const SaleState();
  @override
  List<Object?> get props => [];
}

class SaleInitial extends SaleState {}

class SaleLoading extends SaleState {}

class SaleLoaded extends SaleState {
  final List<SaleBillModel> bills;
  const SaleLoaded(this.bills);
  @override
  List<Object?> get props => [bills];
}

class SaleError extends SaleState {
  final String message;
  const SaleError(this.message);
  @override
  List<Object?> get props => [message];
}