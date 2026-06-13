import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../database/app_database.dart';
import '../../model/item_model.dart';

part 'item_event.dart';
part 'item_state.dart';

class ItemBloc extends Bloc<ItemEvent, ItemState> {
  ItemBloc() : super(ItemInitial()) {
    on<FetchItems>((event, emit) async {
      emit(ItemLoading());
      try {
        final items = await AppDatabase.instance.getAllItems();
        emit(ItemLoaded(items));
      } catch (err) {
        emit(ItemError(err.toString()));
      }
    });
  }
}
