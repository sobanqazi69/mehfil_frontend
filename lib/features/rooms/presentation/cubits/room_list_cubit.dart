import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../data/models/room_model.dart';
import '../../data/repositories/room_repository.dart';
import 'room_list_state.dart';

class RoomListCubit extends Cubit<RoomListState> {
  final RoomRepository _repo;

  RoomListCubit(this._repo) : super(const RoomListInitial());

  Future<void> loadRooms() async {
    try {
      if (isClosed) return;
      emit(const RoomListLoading());
      final rooms = await _repo.browseRooms();
      if (!isClosed) emit(RoomListLoaded(rooms: rooms));
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
      if (!isClosed) emit(RoomListLoaded(rooms: rooms));
    } catch (e) {
      DebugLogger.error('loadMyRooms failed', error: e);
      if (!isClosed) emit(RoomListError(e.toString()));
    }
  }

  Future<void> refresh() async => loadRooms();

  Future<RoomModel> createRoom({
    required String name,
    required String youtubeId,
  }) async {
    final room = await _repo.createRoom(name: name, youtubeId: youtubeId);
    loadMyRooms(); // refresh in background
    return room;
  }
}
