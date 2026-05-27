import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../database/app_database.dart';
import '../../model/sale_bill_model.dart';
import 'sale_event.dart';
import 'sale_state.dart';

class SaleBloc extends Bloc<SaleEvent, SaleState> {
  final AppDatabase _db;

  SaleBloc(this._db) : super(SaleInitial()) {
    on<FetchSaleBills>(_onFetchSaleBills);
  }

  Future<void> _onFetchSaleBills(FetchSaleBills event, Emitter<SaleState> emit) async {
    emit(SaleLoading());
    try {
      final maps = await _db.getAllSaleBills();
      final bills = maps.map((map) => SaleBillModel.fromMap(map)).toList();
      emit(SaleLoaded(bills));
    } catch (e) {
      emit(SaleError(e.toString()));
    }
  }
}