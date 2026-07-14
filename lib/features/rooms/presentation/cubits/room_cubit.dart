import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../../../core/utils/map_utils.dart';
import '../../data/models/message_model.dart';
import '../../data/models/room_member_model.dart';
import '../../data/repositories/room_repository.dart';
import 'room_state.dart';

class RoomCubit extends Cubit<RoomState> {
  final RoomRepository _repo;
  int? _roomId;

  RoomCubit(this._repo) : super(const RoomInitial());

  Future<void> enterRoom(int roomId, int userId) async {
    try {
      _roomId = roomId;
      if (isClosed) return;
      emit(const RoomLoading());

      final results = await Future.wait([
        _repo.getRoom(roomId),
        _repo.getVoiceToken(roomId),
      ]);

      if (isClosed) return;
      final voice = MapUtils.asMap(results[1]);
      emit(RoomLoaded(
        room: results[0] as dynamic,
        // Chat history is deliberately not loaded: a user only sees messages
        // sent after they joined.
        messages: const [],
        voiceToken: MapUtils.handleNullableStringKey(voice, 'token'),
        voiceRoomName: MapUtils.handleNullableStringKey(voice, 'roomName'),
      ));

      _repo.joinRoom(roomId, userId);
      _listenToSocketEvents();
    } catch (e) {
      DebugLogger.error('enterRoom failed', error: e);
      if (!isClosed) emit(RoomError(e.toString()));
    }
  }

  void _listenToSocketEvents() {
    _repo.onRoomMembers(_onMembers);
    _repo.onChatMessage(_onChatMessage);
    _repo.onMicState(_onMicState);
    _repo.onMicMutedAll(_onMicMutedAll);
    _repo.onVideoState(_onVideoState);
    _repo.onSettingsUpdated(_onSettingsUpdated);
  }

  void _onMembers(List<RoomMemberModel> members, int? hostId) {
    if (isClosed) return;
    if (state is RoomLoaded) {
      final s = state as RoomLoaded;
      emit(s.copyWith(
        members: members,
        room: hostId != null ? s.room.copyWith(hostId: hostId) : s.room,
      ));
    }
  }

  void _onChatMessage(MessageModel msg) {
    if (isClosed) return;
    if (state is RoomLoaded) {
      final s = state as RoomLoaded;
      emit(s.copyWith(messages: [...s.messages, msg]));
    }
  }

  void _onMicState(int userId, bool isMuted) {
    if (isClosed) return;
    if (state is RoomLoaded) {
      final s = state as RoomLoaded;
      final updated = Map<int, bool>.from(s.mutedMap)..[userId] = isMuted;
      emit(s.copyWith(mutedMap: updated));
    }
  }

  void _onMicMutedAll() {
    if (isClosed) return;
    if (state is RoomLoaded) {
      emit((state as RoomLoaded).copyWith(isMicMuted: true, mutedMap: {}));
    }
  }

  void _onSettingsUpdated(bool isPublic) {
    if (isClosed) return;
    if (state is RoomLoaded) {
      final s = state as RoomLoaded;
      emit(s.copyWith(room: s.room.copyWith(isPublic: isPublic)));
    }
  }

  void _onVideoState(Map<String, dynamic> data) {
    if (isClosed) return;
    if (state is RoomLoaded) {
      final s = state as RoomLoaded;
      final payload = MapUtils.asMap(data);
      emit(s.copyWith(
        room: s.room.copyWith(
          youtubeId: MapUtils.handleNullableStringKey(payload, 'youtubeId'),
          nextYoutubeId:
              MapUtils.handleNullableStringKey(payload, 'nextYoutubeId'),
          timestampSec:
              MapUtils.handleNullableDoubleKey(payload, 'timestampSec') ??
                  MapUtils.handleNullableDoubleKey(payload, 'timestamp') ??
                  0,
          isPlaying:
              MapUtils.handleNullableBoolKey(payload, 'isPlaying') ?? false,
        ),
      ));
    }
  }

  void sendMessage(String text) {
    if (_roomId == null || text.trim().isEmpty) return;
    _repo.sendMessage(_roomId!, text.trim());
  }

  void toggleMic(int userId) {
    if (_roomId == null || state is! RoomLoaded) return;
    final s = state as RoomLoaded;
    final newMuted = !s.isMicMuted;
    _repo.toggleMic(_roomId!, userId, newMuted);
    if (!isClosed) emit(s.copyWith(isMicMuted: newMuted));
  }

  void muteAll() {
    if (_roomId == null) return;
    _repo.muteAll(_roomId!);
  }

  void loadVideo(String youtubeId) {
    if (_roomId == null) return;
    _repo.loadVideo(_roomId!, youtubeId);
  }

  void syncVideo(double timestamp, bool isPlaying) {
    if (_roomId == null) return;
    _repo.syncVideo(_roomId!, timestamp, isPlaying);
  }

  Future<void> leaveRoom(int userId) async {
    if (_roomId != null) {
      _repo.leaveRoom(_roomId!, userId);
      _repo.offRoomListeners();
    }
    if (!isClosed) emit(const RoomInitial());
  }

  void updateSettings({bool? isPublic}) {
    if (_roomId == null || state is! RoomLoaded) return;
    if (isPublic != null) {
      _repo.updateSettings(_roomId!, isPublic);
      // Optimistic update
      final s = state as RoomLoaded;
      emit(s.copyWith(room: s.room.copyWith(isPublic: isPublic)));
    }
  }

  void queueVideo(String youtubeId) {
    if (_roomId == null) return;
    _repo.queueVideo(_roomId!, youtubeId);
  }

  @override
  Future<void> close() {
    _repo.offRoomListeners();
    return super.close();
  }
}
