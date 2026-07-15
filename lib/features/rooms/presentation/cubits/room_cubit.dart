import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/network/livekit_service.dart';
import '../../../../core/services/room_foreground_service.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../../../core/utils/map_utils.dart';
import '../../data/models/message_model.dart';
import '../../data/models/room_member_model.dart';
import '../../data/repositories/room_repository.dart';
import 'room_state.dart';

class RoomCubit extends Cubit<RoomState> {
  final RoomRepository _repo;
  final LiveKitService _livekit;
  int? _roomId;

  int? _userId;

  /// identity (userId string) → audio level for whoever is currently speaking.
  /// Kept off the bloc state and fed via a throttled ValueNotifier so the
  /// speaking rings repaint ~8fps without rebuilding the whole room tree.
  final speakingLevels = ValueNotifier<Map<String, double>>({});
  Map<String, double>? _pendingLevels;
  Timer? _levelsThrottle;

  RoomCubit(this._repo, {LiveKitService? livekit})
      : _livekit = livekit ?? LiveKitService.instance,
        super(const RoomInitial());

  /// The user is audible only when neither mute applies.
  bool get _shouldMicBeLive {
    final s = state;
    return s is RoomLoaded && !s.isMicMuted && !s.isHostMuted;
  }

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

      // Voice is best-effort and must never block entering the room, so fire it
      // without awaiting: chat/video are usable instantly while audio connects.
      unawaited(_startVoice(
        MapUtils.handleNullableStringKey(voice, 'token'),
        MapUtils.handleNullableStringKey(voice, 'roomName'),
      ));
    } catch (e) {
      DebugLogger.error('enterRoom failed', error: e);
      if (!isClosed) emit(RoomError(e.toString()));
    }
  }

  Future<void> _startVoice(String? token, String? roomName) async {
    try {
      _livekit.onActiveSpeakersChanged = _onSpeakers;
      if (token == null || token.isEmpty) return;

      // Order matters on Android 14+: a microphone-typed foreground service
      // cannot start until RECORD_AUDIO is actually granted, or the OS kills
      // the process. So request the permission FIRST, connect, and only start
      // the keep-alive service once we hold the permission.
      final micGranted = await _requestMicPermission();

      await _livekit.connect(token);
      // Reflect whatever mute state we already hold (host may have us muted).
      await _livekit.setMicEnabled(_shouldMicBeLive);

      if (micGranted) {
        unawaited(RoomForegroundService.instance
            .start(roomName: roomName ?? 'Room'));
      }
    } catch (e) {
      DebugLogger.error('startVoice failed', error: e);
    }
  }

  Future<bool> _requestMicPermission() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      DebugLogger.error('mic permission request failed', error: e);
      return false;
    }
  }

  /// Push the current effective-mute state to the live mic. Called after any
  /// change that could flip our own audibility. Idempotent and non-blocking.
  void _syncMic() {
    if (!_livekit.isConnected) return;
    final live = _shouldMicBeLive;
    if (live == _livekit.isMicEnabled) return;
    unawaited(_livekit.setMicEnabled(live));
  }

  void _onSpeakers(Map<String, double> levels) {
    if (isClosed) return;
    // Coalesce the firehose of speaker events into one repaint per ~120ms.
    _pendingLevels = levels;
    _levelsThrottle ??= Timer(const Duration(milliseconds: 120), () {
      _levelsThrottle = null;
      final pending = _pendingLevels;
      _pendingLevels = null;
      if (pending != null) speakingLevels.value = pending;
    });
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
      _syncMic();
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
      if (userId == _userId) _syncMic();
    }
  }

  /// We tried to unmute while host-muted; the server refused.
  void _onMicBlocked(String message) {
    if (isClosed) return;
    if (state is RoomLoaded) {
      final s = state as RoomLoaded;
      // Snap the button back — our optimistic unmute never took effect.
      emit(s.copyWith(isMicMuted: true, isHostMuted: true));
      _syncMic();
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
      _syncMic();
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
    if (!isClosed) {
      emit(s.copyWith(isMicMuted: newMuted));
      _syncMic();
    }
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
    _stopVoice();
    emit(const RoomKicked());
  }

  /// Release the mic, drop the LiveKit connection, and stop the Android
  /// foreground service. Safe to call more than once.
  void _stopVoice() {
    _livekit.onActiveSpeakersChanged = null;
    unawaited(_livekit.disconnect());
    unawaited(RoomForegroundService.instance.stop());
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
    _stopVoice();
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
    _stopVoice();
    _levelsThrottle?.cancel();
    _levelsThrottle = null;
    speakingLevels.dispose();
    return super.close();
  }
}
