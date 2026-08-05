import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../config/theme/app_text_styles.dart';
import '../../data/models/room_seat_model.dart';
import 'animated_emoji.dart';

const _mint = Color(0xFF00FFB2);

/// A single mic slot: avatar when taken, a dashed outline when free.
///
/// Purely presentational — every decision about whether a tap is allowed is
/// made by the parent, so this widget stays trivial to reason about.
class SeatTile extends StatelessWidget {
  final RoomSeatModel seat;

  /// This seat is ours. Drawn with a brighter ring so it is findable instantly.
  final bool isMine;

  /// Driven by LiveKit's active-speaker levels.
  final bool isSpeaking;

  /// Emoji floating over this chair right now, if any.
  final String? reaction;

  /// Distinguishes consecutive sends of the same emoji.
  final int? reactionId;

  final VoidCallback? onTap;

  const SeatTile({
    super.key,
    required this.seat,
    this.isMine = false,
    this.isSpeaking = false,
    this.reaction,
    this.reactionId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                _CinemaChair(
                    seat: seat, isMine: isMine, isSpeaking: isSpeaking),
                if (reaction != null)
                  Positioned(
                    // Above the chair, overflowing the tile — the row's
                    // Clip.none lets it float free rather than squashing in.
                    top: -22,
                    child: _SeatReaction(
                      // Keyed so a repeat of the same emoji restarts the
                      // animation instead of sitting there already finished.
                      key: ValueKey('${seat.seatNo}-$reactionId'),
                      emoji: reaction!,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _SeatLabel(seat: seat, isMine: isMine),
          ],
        ),
      ),
    );
  }
}

/// The emoji that pops over a chair: rises slightly and fades as it settles,
/// so it reads as "just sent" rather than as a permanent badge.
class _SeatReaction extends StatefulWidget {
  final String emoji;
  const _SeatReaction({super.key, required this.emoji});

  @override
  State<_SeatReaction> createState() => _SeatReactionState();
}

class _SeatReactionState extends State<_SeatReaction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    return FadeTransition(
      opacity: _ctrl,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.45),
          end: Offset.zero,
        ).animate(curve),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.6, end: 1).animate(curve),
          child: AnimatedEmoji(char: widget.emoji, size: 34, repeat: false),
        ),
      ),
    );
  }
}

class _CinemaChair extends StatelessWidget {
  final RoomSeatModel seat;
  final bool isMine;
  final bool isSpeaking;

  const _CinemaChair({
    required this.seat,
    required this.isMine,
    required this.isSpeaking,
  });

  @override
  Widget build(BuildContext context) {
    final isHost = seat.isHostSeat;
    final isOccupied = seat.isOccupied;

    // Select proper 3D chair asset
    final String chairAsset;
    if (isHost) {
      chairAsset = 'assets/images/cinema_chair_gold.png';
    } else if (isMine) {
      chairAsset = 'assets/images/cinema_chair_blue.png';
    } else {
      chairAsset = 'assets/images/cinema_chair_red.png';
    }

    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1. The 3D Chair Asset
          Opacity(
            opacity: isOccupied ? 1.0 : 0.35,
            child: Image.asset(
              chairAsset,
              width: 88,
              height: 88,
              fit: BoxFit.contain,
            ),
          ),

          // 2. Avatar/Icon overlay (positioned exactly on the backrest)
          Positioned(
            top: 17,
            child: _avatarOrIcon(),
          ),

          // 3. Status Badges — the gold chair already marks the host, so a
          // crown on top of it was only adding clutter.
          if (isOccupied && seat.isMuted)
            const Positioned(
              right: 2,
              bottom: 8,
              child: _Badge(
                icon: Icons.mic_off_rounded,
                color: Color(0xFFEF4444),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatarOrIcon() {
    const double size = 33.0;

    if (seat.isLocked && seat.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black54,
        ),
        child: const Icon(
          Icons.lock_rounded,
          size: 16,
          color: Colors.white38,
        ),
      );
    }

    if (seat.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white30,
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: const Icon(
          Icons.add_rounded,
          size: 18,
          color: Colors.white60,
        ),
      );
    }

    final avatarRing = isSpeaking ? _mint : Colors.transparent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: avatarRing,
          width: isSpeaking ? 1.5 : 0.0,
        ),
        boxShadow: isSpeaking
            ? [
                BoxShadow(
                  color: _mint.withValues(alpha: 0.8),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: seat.avatar != null && seat.avatar!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: seat.avatar!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _initial(size),
                placeholder: (_, __) => _initial(size),
              )
            : _initial(size),
      ),
    );
  }

  Widget _initial(double size) {
    final n = seat.name ?? '';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        n.isNotEmpty ? n[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _SeatLabel extends StatelessWidget {
  final RoomSeatModel seat;
  final bool isMine;

  const _SeatLabel({required this.seat, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;

    if (seat.isOccupied) {
      text = isMine ? 'You' : (seat.name ?? 'User');
      color = isMine ? _mint : Colors.white.withValues(alpha: 0.75);
    } else if (seat.isLocked) {
      text = 'Locked';
      color = Colors.white.withValues(alpha: 0.3);
    } else {
      text = seat.isHostSeat ? 'Host' : '${seat.seatNo + 1}';
      color = Colors.white.withValues(alpha: 0.35);
    }

    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: AppTextStyles.labelSmall.copyWith(
        fontSize: 11,
        color: color,
        fontWeight: isMine ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _Badge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 21,
      height: 21,
      decoration: BoxDecoration(
        color: const Color(0xFF130E26),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Icon(icon, size: 12, color: color),
    );
  }
}
