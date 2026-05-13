import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../data/models/room_model.dart';
import '../../data/repositories/room_repository.dart';
import 'room_list_state.dart';

class RoomListCubit extends Cubit<RoomListState> {
  final RoomRepository _repo;

  RoomListCubit(this._repo) : super(const RoomListInitial());

  Future<void> loadRooms({String category = 'All'}) async {
    try {
      if (isClosed) return;
      emit(const RoomListLoading());
      final rooms = await _repo.browseRooms(
        page: 1,
        category: category == 'All' ? null : category,
      );
      if (isClosed) return;
      emit(RoomListLoaded(rooms: rooms, selectedCategory: category));
    } catch (e) {
      DebugLogger.error('loadRooms failed', error: e);
      if (!isClosed) emit(RoomListError(e.toString()));
    }
  }

  Future<void> loadMyRooms() async {
    try {
      if (isClosed) return;
      emit(const RoomListLoading());
      final rooms = await _repo.getMyRooms();
      if (isClosed) return;
      emit(RoomListLoaded(rooms: rooms));
    } catch (e) {
      DebugLogger.error('loadMyRooms failed', error: e);
      if (!isClosed) emit(RoomListError(e.toString()));
    }
  }

  Future<void> changeCategory(String category) async {
    if (state is RoomListLoaded &&
        (state as RoomListLoaded).selectedCategory == category) return;
    await loadRooms(category: category);
  }

  Future<void> refresh() async {
    final cat = state is RoomListLoaded
        ? (state as RoomListLoaded).selectedCategory
        : 'All';
    await loadRooms(category: cat);
  }

  Future<RoomModel> createRoom({
    required String name,
    required bool isPublic,
    String? category,
  }) async {
    final room = await _repo.createRoom(
      name: name,
      isPublic: isPublic,
      category: category,
    );
    // Refresh my rooms in background
    loadMyRooms();
    return room;
  }
}
