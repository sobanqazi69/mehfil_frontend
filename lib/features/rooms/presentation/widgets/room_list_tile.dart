import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../data/models/room_model.dart';

/// Redesigned premium room tile: thumbnail on the left, title + joined user avatars row
/// on the right, and a subtle progress bar at the bottom.
class RoomListTile extends StatefulWidget {
  final RoomModel room;
  final VoidCallback onTap;

  const RoomListTile({super.key, required this.room, required this.onTap});

  @override
  State<RoomListTile> createState() => _RoomListTileState();
}

class _RoomListTileState extends State<RoomListTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    const double borderRadiusValue = 24.0;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x73130E26), // Glassmorphic background
            borderRadius: BorderRadius.circular(borderRadiusValue), // Highly rounded corners
            border: Border.all(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.12),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD97706).withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadiusValue - 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _RoomThumbnail(room: room),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              room.name.isEmpty ? 'Untitled room' : room.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            _MemberAvatarsRow(room: room),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // White/Gold mock progress bar matching the reference screenshot
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: ((room.id * 23) % 50 + 30) / 100, // realistic mock progress (30%-80%)
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white70),
                    minHeight: 2.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Thumbnail (16:9, rounded) ──────────────────────────────────────────────

class _RoomThumbnail extends StatelessWidget {
  final RoomModel room;
  const _RoomThumbnail({required this.room});

  static const double _width = 135;
  static const double _height = 80;

  String? get _url => room.youtubeId != null
      ? 'https://img.youtube.com/vi/${room.youtubeId}/hqdefault.jpg'
      : null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: _height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_url != null)
            CachedNetworkImage(
              imageUrl: _url!,
              fit: BoxFit.cover,
              placeholder: (_, __) => const _ThumbPlaceholder(),
              errorWidget: (_, __, ___) => const _ThumbPlaceholder(),
            )
          else
            const _ThumbPlaceholder(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          if (room.isLive)
            const Positioned(top: 5, left: 5, child: _LiveBadge()),
          const Center(child: _PlayGlyph()),
        ],
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0C0820), Color(0xFF130E26)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.headphones_rounded,
          size: 26,
          color: Color(0xFFFBBF24),
        ),
      ),
    );
  }
}

class _PlayGlyph extends StatelessWidget {
  const _PlayGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.play_arrow_rounded,
          color: Colors.white, size: 20),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        'LIVE',
        style: AppTextStyles.labelSmall.copyWith(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Joined Users Avatars Row ────────────────────────────────────────────────

class _MemberAvatarsRow extends StatelessWidget {
  final RoomModel room;
  const _MemberAvatarsRow({required this.room});

  static const List<String> _mockAvatars = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=100', // Woman 1
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&q=80&w=100', // Man 1
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=100', // Woman 2
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=100', // Man 2
    'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&q=80&w=100', // Woman 3
  ];

  @override
  Widget build(BuildContext context) {
    final list = <Widget>[];

    // 1. Host avatar
    if (room.host != null) {
      list.add(_Avatar(url: room.host!.avatar, name: room.host!.name));
    } else {
      list.add(const _Avatar(url: null, name: '?'));
    }

    // 2. Extra members mapped to real-looking premium user avatars
    const int totalAvatarsCount = 5;
    final extraCount = room.memberCount > 1 ? room.memberCount - 1 : 0;

    // If we have more than 5 members, the 5th avatar gets the badge
    final showBadge = room.memberCount > totalAvatarsCount;
    final displayExtra = showBadge ? 3 : extraCount;

    for (int i = 0; i < displayExtra; i++) {
      final url = _mockAvatars[(room.id + i) % _mockAvatars.length];
      list.add(
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: _Avatar(url: url, name: 'User $i'),
        ),
      );
    }

    if (showBadge) {
      final url = _mockAvatars[(room.id + displayExtra) % _mockAvatars.length];
      final badgeVal = room.memberCount - 4;
      list.add(
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _Avatar(url: url, name: 'User badge'),
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+$badgeVal',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: list,
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final String name;

  const _Avatar({this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: ClipOval(
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _initial(),
              )
            : _initial(),
      ),
    );
  }

  Widget _initial() => Container(
        color: const Color(0xFF1E173C),
        alignment: Alignment.center,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFFFBBF24),
          ),
        ),
      );
}
