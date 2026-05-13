import 'package:equatable/equatable.dart';
import '../../data/models/room_model.dart';

abstract class RoomListState extends Equatable {
  const RoomListState();
  @override
  List<Object?> get props => [];
}

class RoomListInitial extends RoomListState {
  const RoomListInitial();
}

class RoomListLoading extends RoomListState {
  const RoomListLoading();
}

class RoomListLoaded extends RoomListState {
  final List<RoomModel> rooms;

  const RoomListLoaded({required this.rooms});

  RoomListLoaded copyWith({List<RoomModel>? rooms}) =>
      RoomListLoaded(rooms: rooms ?? this.rooms);

  @override
  List<Object?> get props => [rooms];
}

class RoomListError extends RoomListState {
  final String message;
  const RoomListError(this.message);
  @override
  List<Object?> get props => [message];
}
