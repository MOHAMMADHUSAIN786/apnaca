import 'package:flutter_bloc/flutter_bloc.dart';
import 'warehouse_event.dart';
import 'warehouse_state.dart';
import '../../data/repository/warehouse_repository.dart';

class WarehouseBloc extends Bloc<WarehouseEvent, WarehouseState> {
  final WarehouseRepository _repo = WarehouseRepository.instance;

  WarehouseBloc(): super(WarehouseInitial()) {
    on<LoadWarehouses>((e, emit) async {
      emit(WarehouseLoading());
      try {
        final list = await _repo.getAllWarehouses();
        emit(WarehousesLoaded(list));
      } catch (err) { emit(WarehouseOperationFailure(err.toString())); }
    });

    on<CreateWarehouse>((e, emit) async {
      emit(WarehouseLoading());
      try {
        await _repo.createWarehouse(e.name, code: e.code, location: e.location);
        final list = await _repo.getAllWarehouses();
        emit(WarehousesLoaded(list));
      } catch (err) { emit(WarehouseOperationFailure(err.toString())); }
    });

    on<UpdateWarehouse>((e, emit) async {
      emit(WarehouseLoading());
      try {
        await _repo.updateWarehouse(e.id, e.name, code: e.code, location: e.location);
        final list = await _repo.getAllWarehouses();
        emit(WarehousesLoaded(list));
      } catch (err) { emit(WarehouseOperationFailure(err.toString())); }
    });

    on<DeleteWarehouse>((e, emit) async {
      emit(WarehouseLoading());
      try {
        await _repo.deleteWarehouse(e.id);
        final list = await _repo.getAllWarehouses();
        emit(WarehousesLoaded(list));
      } catch (err) { emit(WarehouseOperationFailure(err.toString())); }
    });

    on<TransferStockEvent>((e, emit) async {
      emit(WarehouseLoading());
      try {
        await _repo.transferStock(fromWarehouseId: e.from, toWarehouseId: e.to, itemId: e.itemId, qty: e.qty);
        emit(WarehouseOperationSuccess());
      } catch (err) { emit(WarehouseOperationFailure(err.toString())); }
    });

    on<LoadTransfers>((e, emit) async {
      emit(WarehouseLoading());
      try {
        final rows = await _repo.getTransferHistory();
        emit(TransfersLoaded(rows));
      } catch (err) { emit(WarehouseOperationFailure(err.toString())); }
    });
  }
}
