// lib/features/home/presentation/bloc/home_event.dart
part of 'home_bloc.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object?> get props => [];
}

class FetchHomeData extends HomeEvent {}