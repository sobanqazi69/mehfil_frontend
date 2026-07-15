import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../utils/debug_logger.dart';

// Android suspends background sockets and WebRTC within ~60s of the app leaving
// the foreground (aggressive OEMs like Samsung/Xiaomi are worse). Without a real
// foreground service the server sees the socket drop and kicks the user from the
// room, and voice cuts out. This keeps both alive while a room is open.

@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(_RoomTaskHandler());
}

class _RoomTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

class RoomForegroundService {
  static final instance = RoomForegroundService._();
  RoomForegroundService._();

  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized || !Platform.isAndroid) return;
    _initialized = true;
    try {
      FlutterForegroundTask.initCommunicationPort();
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'mehfil_room_channel',
          channelName: 'Voice Room',
          channelDescription:
              'Keeps your voice connection alive while you are in a room',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.nothing(),
          autoRunOnBoot: false,
          autoRunOnMyPackageReplaced: false,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
    } catch (e) {
      DebugLogger.error('RoomForegroundService init failed',
          error: e);
    }
  }

  Future<void> start({required String roomName}) async {
    if (!Platform.isAndroid) return;
    try {
      await _init();
      if (await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.startService(
        notificationTitle: 'Mehfil — $roomName',
        notificationText: "You're in a voice room. Tap to return.",
        callback: _startCallback,
      );
    } catch (e) {
      DebugLogger.error('RoomForegroundService start failed',
          error: e);
    }
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      if (!await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.stopService();
    } catch (e) {
      DebugLogger.error('RoomForegroundService stop failed',
          error: e);
    }
  }
}
