import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/debug_logger.dart';

/// Per-device playback levels for a room: the video and the voices on the call.
///
/// Purely local — nothing here is broadcast, so every listener mixes the room
/// to their own taste without affecting anyone else. Values are 0–100 and are
/// remembered across sessions.
class VolumeService {
  static final VolumeService instance = VolumeService._();
  VolumeService._();

  static const _keyVideo = 'volume_video';
  static const _keyCall = 'volume_call';
  static const int maxVolume = 100;

  /// Exposed as notifiers so the player and LiveKit can react to a drag
  /// without rebuilding the room tree on every slider tick.
  final videoVolume = ValueNotifier<int>(maxVolume);
  final callVolume = ValueNotifier<int>(maxVolume);

  SharedPreferences? _prefs;
  Timer? _saveDebounce;

  /// 0.0–1.0 view of the same values, for APIs that want a gain factor.
  double get videoGain => videoVolume.value / maxVolume;
  double get callGain => callVolume.value / maxVolume;

  /// Called once at startup. A failure here is not fatal — we just fall back
  /// to full volume rather than leaving the user with a silent room.
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      videoVolume.value = _clamp(_prefs?.getInt(_keyVideo) ?? maxVolume);
      callVolume.value = _clamp(_prefs?.getInt(_keyCall) ?? maxVolume);
      DebugLogger.log(
        'volumes restored — video: ${videoVolume.value}, call: ${callVolume.value}',
        tag: 'VOL',
      );
    } catch (e) {
      DebugLogger.error('VolumeService init failed', error: e);
    }
  }

  void setVideoVolume(int value) {
    try {
      final next = _clamp(value);
      if (next == videoVolume.value) return;
      videoVolume.value = next;
      _scheduleSave();
    } catch (e) {
      DebugLogger.error('setVideoVolume failed', error: e);
    }
  }

  void setCallVolume(int value) {
    try {
      final next = _clamp(value);
      if (next == callVolume.value) return;
      callVolume.value = next;
      _scheduleSave();
    } catch (e) {
      DebugLogger.error('setCallVolume failed', error: e);
    }
  }

  /// Drop to zero, or restore to full if already silent.
  void toggleVideoMuted() =>
      setVideoVolume(videoVolume.value == 0 ? maxVolume : 0);

  void toggleCallMuted() => setCallVolume(callVolume.value == 0 ? maxVolume : 0);

  int _clamp(int value) => value.clamp(0, maxVolume);

  /// A slider drag fires dozens of times a second; only the resting value is
  /// worth a disk write.
  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), _save);
  }

  Future<void> _save() async {
    try {
      final prefs = _prefs;
      if (prefs == null) return;
      await prefs.setInt(_keyVideo, videoVolume.value);
      await prefs.setInt(_keyCall, callVolume.value);
    } catch (e) {
      DebugLogger.error('volume save failed', error: e);
    }
  }
}
