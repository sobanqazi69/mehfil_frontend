import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_text_styles.dart';
import '../cubits/room_cubit.dart';
import '../cubits/room_state.dart';

const _gold = Color(0xFFFBBF24);
const _mint = Color(0xFF00FFB2);

/// The floating pill shown while a room is minimised.
///
/// Draggable, because a fixed bubble always ends up covering the one control
/// the user wants. Position is kept in local state so it survives the room's
/// own rebuilds.
class RoomPipOverlay extends StatefulWidget {
  final RoomCubit cubit;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const RoomPipOverlay({
    super.key,
    required this.cubit,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<RoomPipOverlay> createState() => _RoomPipOverlayState();
}

class _RoomPipOverlayState extends State<RoomPipOverlay> {
  Offset? _pos;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;

    // Default to just above the bottom nav, out of the way of most content.
    final pos = _pos ??
        Offset(size.width - 186, size.height - media.padding.bottom - 132);

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        onPanUpdate: (d) {
          final next = (_pos ?? pos) + d.delta;
          setState(() {
            // Clamp so it can never be dragged off-screen and stranded.
            _pos = Offset(
              next.dx.clamp(8.0, size.width - 178),
              next.dy.clamp(media.padding.top + 8, size.height - 84),
            );
          });
        },
        onTap: widget.onTap,
        child: Material(
          color: Colors.transparent,
          child: BlocProvider.value(
            value: widget.cubit,
            child: const _PipCard(),
          ),
        ),
      ),
    );
  }
}

class _PipCard extends StatelessWidget {
  const _PipCard();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoomCubit, RoomState>(
      buildWhen: (_, curr) => curr is RoomLoaded,
      builder: (context, state) {
        final name = state is RoomLoaded ? state.room.name : 'Room';
        final live = state is RoomLoaded && !state.isMicMuted;

        return Container(
          width: 170,
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF130E26),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _gold.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Pulses only while our mic is actually open, so the dot means
              // "they can hear you" rather than merely "still connected".
              _LiveDot(live: live),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name.isEmpty ? 'Room' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Tap to return',
                      style: AppTextStyles.labelSmall.copyWith(
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _confirmLeave(context),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(Icons.close_rounded,
                      color: Color(0xFFEF4444), size: 17),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Confirm before closing: the bubble is small and easy to hit by accident,
  /// and leaving is not undoable in a room you were invited to.
  void _confirmLeave(BuildContext context) {
    final overlay = context.findAncestorWidgetOfExactType<RoomPipOverlay>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF130E26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _gold.withValues(alpha: 0.18)),
        ),
        title: Text('Leave room?',
            style: AppTextStyles.heading3.copyWith(fontSize: 16, color: _gold)),
        content: Text(
          'You will leave the watch party.',
          style: AppTextStyles.bodySmall
              .copyWith(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Stay', style: TextStyle(color: _gold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              overlay?.onClose();
            },
            child: const Text('Leave',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  final bool live;
  const _LiveDot({required this.live});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (live ? _mint : Colors.white).withValues(alpha: 0.12),
        border: Border.all(
          color: (live ? _mint : Colors.white).withValues(alpha: 0.35),
        ),
      ),
      child: Icon(
        live ? Icons.mic_rounded : Icons.headphones_rounded,
        size: 15,
        color: live ? _mint : Colors.white70,
      ),
    );
  }
}
