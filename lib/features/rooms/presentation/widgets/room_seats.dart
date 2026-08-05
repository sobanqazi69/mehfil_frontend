import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_text_styles.dart';
import '../../data/models/room_seat_model.dart';
import '../cubits/room_cubit.dart';
import '../cubits/room_state.dart';
import 'seat_tile.dart';

/// The mic strip under the video: a fixed row of seats, only whose occupants
/// may speak. Everyone else is in the audience and can still watch and chat.
///
/// Mirrors the seat model in Bazmi — seat 0 is the host's.
class RoomSeats extends StatelessWidget {
  /// Matches Bazmi's `Room.maxSeats` default. Until the server sends a real
  /// seat list we still draw this many empty slots so the row never collapses.
  static const int defaultSeatCount = 5;

  final int currentUserId;
  const RoomSeats({super.key, required this.currentUserId});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoomCubit, RoomState>(
      buildWhen: (_, curr) => curr is RoomLoaded,
      builder: (context, state) {
        if (state is! RoomLoaded) return const SizedBox.shrink();

        final seats = _padded(state.seats);
        final isHost = state.room.hostId == currentUserId;
        final mySeatNo = seats
            .where((s) => s.userId == currentUserId)
            .map((s) => s.seatNo)
            .firstOrNull;

        // Group seats into rows dynamically for theater seating map layout
        final List<List<RoomSeatModel>> rows = [];
        if (seats.length <= 4) {
          rows.add(seats);
        } else if (seats.length == 5) {
          rows.add(seats.sublist(0, 2));
          rows.add(seats.sublist(2));
        } else if (seats.length <= 8) {
          rows.add(seats.sublist(0, 3));
          rows.add(seats.sublist(3));
        } else {
          rows.add(seats.sublist(0, 3));
          rows.add(seats.sublist(3, 7));
          rows.add(seats.sublist(7));
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0C0820).withValues(alpha: 0.35),
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFFFBBF24).withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cinema Screen stage glow effect
              Container(
                height: 24,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -1.2),
                    radius: 1.5,
                    colors: [
                      const Color(0xFF0EA5E9).withValues(alpha: 0.22),
                      const Color(0xFF6366F1).withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 160,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.6),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // The speaking levels bound builder
              ValueListenableBuilder<Map<String, double>>(
                valueListenable: context.read<RoomCubit>().speakingLevels,
                builder: (_, levels, __) {
                  return ValueListenableBuilder<Map<int, String>>(
                    valueListenable: context.read<RoomCubit>().seatReactions,
                    builder: (_, reactions, __) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int rowIndex = 0;
                          rowIndex < rows.length;
                          rowIndex++) ...[
                        if (rowIndex > 0) const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (int i = 0; i < rows[rowIndex].length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Builder(
                                builder: (context) {
                                  final seat = rows[rowIndex][i];
                                  final rowSize = rows[rowIndex].length;
                                  // Subtle curve: outer seats in the row are placed 4px higher
                                  final double curveOffset = rowSize > 1
                                      ? (i - (rowSize - 1) / 2.0).abs() * 4.0
                                      : 0.0;
                                  return Padding(
                                    padding: EdgeInsets.only(top: curveOffset),
                                    child: SeatTile(
                                      seat: seat,
                                      isMine: seat.userId == currentUserId,
                                      isSpeaking:
                                          (levels['${seat.userId}'] ?? 0) >
                                                  0.05 &&
                                              !seat.isMuted,
                                      reaction: reactions[seat.seatNo],
                                      onTap: () => _onSeatTap(
                                        context,
                                        seat: seat,
                                        isHost: isHost,
                                        mySeatNo: mySeatNo,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                    ),
                  );
                },
              ),

              if (mySeatNo == null) ...[
                const SizedBox(height: 16),
                Text(
                  'Tap an empty velvet chair to take a seat',
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.35),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// The server is the source of truth, but it may send fewer entries than the
  /// room has slots (or nothing at all yet). Pad so the row is always stable.
  List<RoomSeatModel> _padded(List<RoomSeatModel> seats) {
    final count =
        seats.isEmpty ? defaultSeatCount : (seats.length).clamp(1, 12);
    final byNo = {for (final s in seats) s.seatNo: s};
    return [
      for (var i = 0; i < count; i++) byNo[i] ?? RoomSeatModel.vacant(i),
    ];
  }

  void _onSeatTap(
    BuildContext context, {
    required RoomSeatModel seat,
    required bool isHost,
    required int? mySeatNo,
  }) {
    final cubit = context.read<RoomCubit>();

    // Our own seat: never step down on a stray tap — offer the choice.
    if (seat.userId == currentUserId) {
      showMySeatActions(context, seat);
      return;
    }

    // Someone else is sitting here. Only the host has anything to do.
    if (seat.isOccupied) {
      if (isHost) showSeatHostActions(context, seat);
      return;
    }

    // Empty. The host gets the management sheet — it is the only way to reach
    // lock/unlock, and it is also how a locked seat gets reopened.
    if (isHost) {
      showSeatHostActions(context, seat);
      return;
    }

    if (seat.isLocked) return;

    // Only the host may take the host seat.
    if (seat.isHostSeat) return;

    cubit.takeSeat(seat.seatNo);
  }
}

const _sheetGold = Color(0xFFFBBF24);
const _sheetRed = Color(0xFFEF4444);
const _sheetGreen = Color(0xFF10B981);

/// Options for the seat we are sitting on. Tapping our own chair opens this
/// rather than standing up straight away — losing the mic to a stray tap in a
/// full room is not something you can undo.
Future<void> showMySeatActions(BuildContext context, RoomSeatModel seat) {
  final cubit = context.read<RoomCubit>();
  final state = cubit.state;
  final selfMuted = state is RoomLoaded ? state.isMicMuted : true;

  return _seatSheet(
    context,
    title: 'Your seat',
    actions: [
      // The host's seat-mute is not ours to lift, so only offer the self-mute
      // when we are not already silenced by them.
      if (!seat.isMuted)
        _SeatAction(
          icon: selfMuted ? Icons.mic_rounded : Icons.mic_off_rounded,
          label: selfMuted ? 'Unmute my mic' : 'Mute my mic',
          color: selfMuted ? _sheetGreen : _sheetRed,
          onTap: () {
            cubit.toggleMic(seat.userId ?? 0);
            Navigator.pop(context);
          },
        ),
      _SeatAction(
        icon: Icons.logout_rounded,
        label: 'Leave seat',
        color: _sheetRed,
        onTap: () {
          cubit.leaveSeat();
          Navigator.pop(context);
        },
      ),
    ],
  );
}

/// Host controls for any seat — occupied or not. An empty seat still needs a
/// way in, because lock/unlock lives here.
Future<void> showSeatHostActions(BuildContext context, RoomSeatModel seat) {
  final cubit = context.read<RoomCubit>();

  return _seatSheet(
    context,
    title: seat.name ?? 'Seat ${seat.seatNo + 1}',
    actions: [
      if (seat.isEmpty && !seat.isLocked)
        _SeatAction(
          icon: Icons.event_seat_rounded,
          label: 'Sit here',
          color: const Color(0xFF00FFB2),
          onTap: () {
            cubit.takeSeat(seat.seatNo);
            Navigator.pop(context);
          },
        ),
      if (seat.isOccupied) ...[
        _SeatAction(
          icon: seat.isMuted ? Icons.mic_rounded : Icons.mic_off_rounded,
          label: seat.isMuted ? 'Unmute on seat' : 'Mute on seat',
          color: seat.isMuted ? _sheetGreen : _sheetRed,
          onTap: () {
            cubit.setSeatMuted(seat.seatNo, !seat.isMuted);
            Navigator.pop(context);
          },
        ),
        _SeatAction(
          icon: Icons.logout_rounded,
          label: 'Remove from seat',
          color: _sheetRed,
          onTap: () {
            cubit.removeFromSeat(seat.seatNo);
            Navigator.pop(context);
          },
        ),
      ],
      _SeatAction(
        icon: seat.isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
        label: seat.isLocked ? 'Unlock seat' : 'Lock seat',
        subtitle: seat.isLocked
            ? 'Let anyone sit here again'
            : seat.isOccupied
                // Say so up front — the host is about to cut someone off.
                ? 'Closes the seat and removes them'
                : 'Nobody can take this seat',
        color: seat.isLocked ? _sheetGreen : _sheetGold,
        onTap: () {
          cubit.setSeatLocked(seat.seatNo, !seat.isLocked);
          Navigator.pop(context);
        },
      ),
    ],
  );
}

Future<void> _seatSheet(
  BuildContext context, {
  required String title,
  required List<Widget> actions,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF130E26),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _sheetGold.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    const Icon(Icons.event_seat_rounded,
                        size: 17, color: _sheetGold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.heading3
                            .copyWith(fontSize: 15, color: _sheetGold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: _sheetGold.withValues(alpha: 0.12)),
              ...actions,
            ],
          ),
        ),
      ),
    ),
  );
}

class _SeatAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SeatAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: color, fontWeight: FontWeight.w500),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
