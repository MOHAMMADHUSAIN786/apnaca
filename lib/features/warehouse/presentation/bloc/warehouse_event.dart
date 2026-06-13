import 'package:equatable/equatable.dart';

abstract class WarehouseEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadWarehouses extends WarehouseEvent {}
class CreateWarehouse extends WarehouseEvent {
  final String name;
  final String? code;
  final String? location;
  CreateWarehouse(this.name, {this.code, this.location});
  @override
  List<Object?> get props => [name, code, location];
}
class UpdateWarehouse extends WarehouseEvent {
  final int id; final String name; final String? code; final String? location;
  UpdateWarehouse(this.id, this.name, {this.code, this.location});
  @override List<Object?> get props => [id, name, code, location];
}
class DeleteWarehouse extends WarehouseEvent { final int id; DeleteWarehouse(this.id); @override List<Object?> get props => [id]; }
class TransferStockEvent extends WarehouseEvent { final int? from; final int? to; final int itemId; final double qty; TransferStockEvent({this.from, this.to, required this.itemId, required this.qty}); @override List<Object?> get props => [from, to, itemId, qty]; }
class LoadTransfers extends WarehouseEvent {}
