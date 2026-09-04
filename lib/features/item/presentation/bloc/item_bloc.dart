import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../database/app_database.dart';
import '../../model/item_model.dart'; // adjust path

part 'item_event.dart';
part 'item_state.dart';

class ItemBloc extends Bloc<ItemEvent, ItemState> {
  final AppDatabase _db;

  ItemBloc(this._db) : super(ItemInitial()) {
    on<FetchItems>(_onFetchItems);
  }

  Future<void> _onFetchItems(FetchItems event, Emitter<ItemState> emit) async {
    emit(ItemLoading());
    try {
      final items = await _db.getAllItems();
      emit(ItemLoaded(items));
    } catch (e) {
      emit(ItemError(e.toString()));
    }
  }
}