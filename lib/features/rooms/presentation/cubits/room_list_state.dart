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
  final String selectedCategory;
  final bool hasMore;
  final int page;

  const RoomListLoaded({
    required this.rooms,
    this.selectedCategory = 'All',
    this.hasMore = false,
    this.page = 1,
  });

  RoomListLoaded copyWith({
    List<RoomModel>? rooms,
    String? selectedCategory,
    bool? hasMore,
    int? page,
  }) {
    return RoomListLoaded(
      rooms: rooms ?? this.rooms,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
    );
  }

  @override
  List<Object?> get props => [rooms, selectedCategory, hasMore, page];
}

class RoomListError extends RoomListState {
  final String message;
  const RoomListError(this.message);
  @override
  List<Object?> get props => [message];
}
