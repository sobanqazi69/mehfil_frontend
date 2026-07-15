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

  int? _userId;

  RoomCubit(this._repo) : super(const RoomInitial());

  Future<void> enterRoom(int roomId, int userId) async {
    try {
      _roomId = roomId;
      _userId = userId;
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
    _repo.onKicked(_onKicked);
    _repo.onMicBlocked(_onMicBlocked);
  }

  void _onMembers(List<RoomMemberModel> members, int? hostId) {
    if (isClosed) return;
    if (state is RoomLoaded) {
      final s = state as RoomLoaded;
      // The roster is the source of truth for both mute kinds.
      final muted = {for (final m in members) m.userId: m.isMuted};
      final hostMuted = {for (final m in members) m.userId: m.mutedByHost};
      final me = _userId;

      emit(s.copyWith(
        members: members,
        room: hostId != null ? s.room.copyWith(hostId: hostId) : s.room,
        mutedMap: muted,
        hostMutedMap: hostMuted,
        isMicMuted: me != null ? (muted[me] ?? s.isMicMuted) : s.isMicMuted,
        isHostMuted:
            me != null ? (hostMuted[me] ?? s.isHostMuted) : s.isHostMuted,
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

  void _onMicState(int userId, bool isMuted, bool mutedByHost) {
    if (isClosed) return;
    if (state is RoomLoaded) {
      final s = state as RoomLoaded;
      final muted = Map<int, bool>.from(s.mutedMap)..[userId] = isMuted;
      final hostMuted = Map<int, bool>.from(s.hostMutedMap)
        ..[userId] = mutedByHost;

      emit(s.copyWith(
        mutedMap: muted,
        hostMutedMap: hostMuted,
        isMicMuted: userId == _userId ? isMuted : s.isMicMuted,
        isHostMuted: userId == _userId ? mutedByHost : s.isHostMuted,
      ));
    }
  }

  /// We tried to unmute while host-muted; the server refused.
  void _onMicBlocked(String message) {
    if (isClosed) return;
    if (state is RoomLoaded) {
      final s = state as RoomLoaded;
      // Snap the button back — our optimistic unmute never took effect.
      emit(s.copyWith(isMicMuted: true, isHostMuted: true));
    }
    micBlocked?.call(message);
  }

  /// Set by the room screen to surface a snackbar.
  void Function(String message)? micBlocked;

  void _onMicMutedAll() {
    if (isClosed) return;
    if (state is RoomLoaded) {
      final s = state as RoomLoaded;
      final amHost = _userId == s.room.hostId;
      // The host is exempt from its own mute-all. A fresh room:members
      // broadcast follows with the authoritative per-user flags.
      emit(s.copyWith(
        isMicMuted: amHost ? s.isMicMuted : true,
        isHostMuted: amHost ? s.isHostMuted : true,
      ));
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

    // Host-muted: don't even ask the server, and tell the user why.
    if (s.isHostMuted) {
      micBlocked?.call('The host has muted you');
      return;
    }

    final newMuted = !s.isMicMuted;
    _repo.toggleMic(_roomId!, userId, newMuted);
    if (!isClosed) emit(s.copyWith(isMicMuted: newMuted));
  }

  void muteAll() {
    if (_roomId == null) return;
    _repo.muteAll(_roomId!);
  }

  void unmuteAll() {
    if (_roomId == null) return;
    _repo.unmuteAll(_roomId!);
  }

  /// True when the host has at least one listener under a host-mute.
  bool get anyoneHostMuted {
    if (state is! RoomLoaded) return false;
    final s = state as RoomLoaded;
    return s.members.any((m) =>
        m.userId != s.room.hostId &&
        (s.hostMutedMap[m.userId] ?? m.mutedByHost));
  }

  /// Host-only. The server re-checks that we are the host before acting; the
  /// UI only offers these on other listeners.
  void hostToggleMic(int targetUserId, bool isMuted) {
    if (_roomId == null) return;
    _repo.forceToggleMic(_roomId!, targetUserId, isMuted);
  }

  /// Promote another listener to host. The authoritative hostId comes back on
  /// the room:members broadcast, so no optimistic update here.
  void hostTransferTo(int targetUserId) {
    if (_roomId == null) return;
    _repo.transferHost(_roomId!, targetUserId);
  }

  void hostKickUser(int targetUserId) {
    if (_roomId == null) return;
    _repo.kickUser(_roomId!, targetUserId);
  }

  void _onKicked() {
    if (isClosed) return;
    _repo.offRoomListeners();
    emit(const RoomKicked());
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
