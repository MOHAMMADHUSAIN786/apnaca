import 'package:equatable/equatable.dart';

abstract class WarehouseState extends Equatable {
  @override
  List<Object?> get props => [];
}

class WarehouseInitial extends WarehouseState {}
class WarehouseLoading extends WarehouseState {}
class WarehousesLoaded extends WarehouseState {
  final List<Map<String, dynamic>> warehouses;
  WarehousesLoaded(this.warehouses);
  @override List<Object?> get props => [warehouses];
}
class WarehouseOperationSuccess extends WarehouseState {}
class WarehouseOperationFailure extends WarehouseState {
  final String message;
  WarehouseOperationFailure(this.message);
  @override List<Object?> get props => [message];
}
class TransfersLoaded extends WarehouseState {
  final List<Map<String, dynamic>> transfers;
  TransfersLoaded(this.transfers);
  @override List<Object?> get props => [transfers];
}
