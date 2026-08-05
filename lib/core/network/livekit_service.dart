import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/api_endpoints.dart';
import '../services/volume_service.dart';
import '../utils/debug_logger.dart';

/// Singleton managing the LiveKit voice connection for a room.
///
/// One connection at a time. Every method is guarded — a voice failure must
/// never take down the room; the worst case is silence, not a crash.
class LiveKitService {
  static final LiveKitService instance = LiveKitService._();
  LiveKitService._();

  Room? _room;
  EventsListener<RoomEvent>? _listener;

  /// Listener-side playback gain for everyone else's voice, 0.0–1.0. Local
  /// only: this changes what *we* hear, never what we send.
  double _callVolume = 1.0;

  /// identity (userId string) → audio level, for active speakers only.
  void Function(Map<String, double> levels)? onActiveSpeakersChanged;
  void Function()? onDisconnected;

  bool get isConnected => _room?.connectionState == ConnectionState.connected;

  bool get isMicEnabled =>
      _room?.localParticipant?.isMicrophoneEnabled() ?? false;

  /// Connect to the room. Mic starts OFF — publishing is driven by the mute
  /// state in RoomCubit, so we never grab the mic before the user intends to.
  Future<void> connect(String token) async {
    try {
      if (token.isEmpty) {
        DebugLogger.log('LiveKit: empty token, skipping connect', tag: 'LK');
        return;
      }

      // Ask up front; the actual publish still checks enablement later.
      try {
        await Permission.microphone.request();
      } catch (e) {
        DebugLogger.error('LiveKit mic permission failed', error: e);
      }

      await disconnect();

      _room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          // WebRTC 3A at the capture layer: hardware echo cancellation, noise
          // suppression, auto gain, plus a high-pass filter for low rumble.
          defaultAudioCaptureOptions: AudioCaptureOptions(
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
            highPassFilter: true,
            typingNoiseDetection: true,
          ),
          // dtx off: silence-based transmission gaps clip word starts and make
          // voices sound choppy. Bandwidth cost is negligible for a chat room.
          defaultAudioPublishOptions: AudioPublishOptions(dtx: false),
        ),
      );

      _setupListeners();

      await _room!.connect(
        ApiEndpoints.livekitUrl,
        token,
        // Fast path: establish the transport immediately, mic disabled. Cuts
        // perceived join latency — audio flows the instant the room is ready.
        fastConnectOptions: FastConnectOptions(
          microphone: const TrackOption(enabled: false),
        ),
      );
      DebugLogger.log('LiveKit: connected', tag: 'LK');

      // Whatever level the user last chose applies to this room too.
      VolumeService.instance.callVolume.addListener(_onCallVolumeChanged);
      _onCallVolumeChanged();
    } catch (e) {
      DebugLogger.error('LiveKit connect failed', error: e);
    }
  }

  void _onCallVolumeChanged() {
    try {
      setCallVolume(VolumeService.instance.callGain);
    } catch (e) {
      DebugLogger.error('LiveKit call volume listener failed', error: e);
    }
  }

  /// Set the playback gain (0.0–1.0) for every remote voice in the room.
  ///
  /// livekit_client has no volume API of its own at this version, so the gain
  /// is pushed down to each subscribed remote audio track through WebRTC. The
  /// local mic track is deliberately never touched — turning our own voice
  /// down would only mute us for everyone else.
  void setCallVolume(double volume) {
    _callVolume = volume.clamp(0.0, 1.0);
    final room = _room;
    if (room == null) return;

    for (final participant in room.remoteParticipants.values) {
      for (final pub in participant.audioTrackPublications) {
        _applyVolumeToTrack(pub.track);
      }
    }
  }

  void _applyVolumeToTrack(Track? track) {
    if (track == null || track is! AudioTrack) return;
    try {
      // Fire-and-forget — one track failing to take the gain is a wrong volume
      // on one voice, never a reason to tear anything down.
      rtc.Helper.setVolume(_callVolume, track.mediaStreamTrack).catchError(
        (Object e) =>
            DebugLogger.error('LiveKit setVolume failed', error: e),
      );
    } catch (e) {
      DebugLogger.error('LiveKit setVolume failed', error: e);
    }
  }

  /// Enable the mic. Retries a couple of times — right after connect the
  /// transport can briefly not be ready, and a single failure would leave the
  /// user silently muted.
  Future<void> enableMic() async {
    if (_room == null) return;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await _room!.localParticipant?.setMicrophoneEnabled(true);
        DebugLogger.log('LiveKit: mic on', tag: 'LK');
        return;
      } catch (e) {
        if (attempt == 3) {
          DebugLogger.error('LiveKit enableMic failed', error: e);
          return;
        }
        await Future.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
  }

  Future<void> disableMic() async {
    try {
      await _room?.localParticipant?.setMicrophoneEnabled(false);
      DebugLogger.log('LiveKit: mic off', tag: 'LK');
    } catch (e) {
      DebugLogger.error('LiveKit disableMic failed', error: e);
    }
  }

  /// Single entry point RoomCubit uses to reflect effective mute state.
  Future<void> setMicEnabled(bool enabled) =>
      enabled ? enableMic() : disableMic();

  Future<void> disconnect() async {
    try {
      VolumeService.instance.callVolume.removeListener(_onCallVolumeChanged);
      _listener?.dispose();
      _listener = null;
      if (_room != null) {
        await _room!.disconnect();
        await _room!.dispose();
        _room = null;
      }
      DebugLogger.log('LiveKit: disconnected', tag: 'LK');
    } catch (e) {
      DebugLogger.error('LiveKit disconnect failed', error: e);
      VolumeService.instance.callVolume.removeListener(_onCallVolumeChanged);
      _listener = null;
      _room = null;
    }
  }

  void _setupListeners() {
    if (_room == null) return;
    _listener = _room!.createListener();
    _listener!
      ..on<ActiveSpeakersChangedEvent>((event) {
        try {
          final levels = <String, double>{};
          for (final p in event.speakers) {
            levels[p.identity] = p.audioLevel;
          }
          onActiveSpeakersChanged?.call(levels);
        } catch (e) {
          DebugLogger.error('LiveKit speakers event failed', error: e);
        }
      })
      // A voice that arrives after the user set their level must not come in
      // at full blast, so every new track inherits the current gain.
      ..on<TrackSubscribedEvent>((event) {
        try {
          _applyVolumeToTrack(event.track);
        } catch (e) {
          DebugLogger.error('LiveKit track subscribed volume failed', error: e);
        }
      })
      ..on<RoomDisconnectedEvent>((_) {
        try {
          onDisconnected?.call();
        } catch (e) {
          DebugLogger.error('LiveKit disconnected event failed', error: e);
        }
      })
      ..on<RoomReconnectingEvent>(
          (_) => DebugLogger.log('LiveKit: reconnecting…', tag: 'LK'))
      ..on<RoomReconnectedEvent>(
          (_) => DebugLogger.log('LiveKit: reconnected', tag: 'LK'));
  }
}
