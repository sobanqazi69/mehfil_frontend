import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/rooms/data/repositories/room_repository.dart';
import '../../features/rooms/presentation/cubits/room_cubit.dart';
import '../../features/rooms/presentation/widgets/room_pip_overlay.dart';
import '../di/service_locator.dart';
import '../utils/debug_logger.dart';

/// Keeps a room alive while the user is somewhere else in the app.
///
/// The room screen used to own its cubit, so popping the route closed the
/// socket, dropped LiveKit and left the room. Minimising instead hands the
/// cubit to this singleton and puts a floating bubble on screen: the user
/// browses, the voice and video keep running, and tapping the bubble drops
/// them straight back in.
class ActiveRoomService with WidgetsBindingObserver {
  ActiveRoomService._() {
    WidgetsBinding.instance.addObserver(this);
  }
  static final ActiveRoomService instance = ActiveRoomService._();

  RoomCubit? _cubit;
  int? _roomId;
  OverlayEntry? _pip;
  GoRouter? _router;

  int? get activeRoomId => _roomId;
  bool get isMinimised => _pip != null;

  /// Reused across navigations so the room survives leaving the screen. A
  /// cubit that has already been closed (kicked, left, torn down) must never
  /// be handed back out — re-entering would render dead state.
  RoomCubit cubitFor(int roomId) {
    final existing = _cubit;
    if (existing != null && _roomId == roomId && !existing.isClosed) {
      return existing;
    }

    // Different room, or the old one is finished: retire it first.
    _closeCubit();

    final cubit = RoomCubit(sl<RoomRepository>());
    _cubit = cubit;
    _roomId = roomId;
    return cubit;
  }

  /// Drop out of the room screen but stay in the room.
  void minimise(BuildContext context) {
    try {
      final roomId = _roomId;
      if (roomId == null || _cubit == null) return;

      // Capture both before popping — the context is defunct afterwards.
      final overlay = Overlay.of(context, rootOverlay: true);
      _router = GoRouter.of(context);

      if (context.canPop()) context.pop();

      _showPip(overlay, roomId);
      DebugLogger.log('room $roomId minimised', tag: 'ROOM');
    } catch (e) {
      DebugLogger.error('minimise room failed', error: e);
    }
  }

  void _showPip(OverlayState overlay, int roomId) {
    _removePip();

    final cubit = _cubit;
    if (cubit == null || cubit.isClosed) return;

    _pip = OverlayEntry(
      builder: (_) => RoomPipOverlay(
        cubit: cubit,
        onTap: restore,
        onClose: leave,
      ),
    );
    overlay.insert(_pip!);
  }

  /// Back into the full room screen.
  void restore() {
    try {
      final roomId = _roomId;
      if (roomId == null) return;
      _removePip();
      _router?.push('/room/$roomId');
    } catch (e) {
      DebugLogger.error('restore room failed', error: e);
    }
  }

  /// Actually leave: tell the server, then tear the session down.
  Future<void> leave() async {
    try {
      _removePip();
      final cubit = _cubit;
      final userId = cubit?.currentUserId;
      if (cubit != null && !cubit.isClosed && userId != null) {
        await cubit.leaveRoom(userId);
      }
    } catch (e) {
      DebugLogger.error('leave from pip failed', error: e);
    } finally {
      _closeCubit();
    }
  }

  /// The full room screen is on screen, so the bubble is redundant. Covers
  /// re-entering from browse, which does not go through restore().
  void onRoomScreenShown() => _removePip();

  /// The room screen popped without minimising — the user left for real.
  void clear() {
    _removePip();
    _closeCubit();
  }

  void _removePip() {
    try {
      _pip?.remove();
    } catch (e) {
      DebugLogger.error('pip remove failed', error: e);
    }
    _pip = null;
  }

  void _closeCubit() {
    // Always take the bubble down with the session. Switching to another room
    // retires this cubit, and a bubble still bound to a closed one would
    // render dead state and throw on tap.
    _removePip();
    final cubit = _cubit;
    _cubit = null;
    _roomId = null;
    if (cubit != null && !cubit.isClosed) unawaited(cubit.close());
  }

  /// A swipe-away never runs our leave flow, so LiveKit and the Android
  /// foreground service would linger and the phone would keep showing the app
  /// as in use. Force the teardown; the server cleans up its side when the
  /// socket drops.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) clear();
  }
}
