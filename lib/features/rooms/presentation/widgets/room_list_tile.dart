import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../data/models/room_model.dart';

/// Compact horizontal room row: thumbnail on the left, title + listeners on the
/// right. Used by the browse list.
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.fieldBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.cyan.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RoomThumbnail(room: room),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name.isEmpty ? 'Untitled room' : room.name,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.slate,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    _ListenerRow(room: room),
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

// ── Thumbnail (16:9, reserved space so the list never shifts) ──────────────

class _RoomThumbnail extends StatelessWidget {
  final RoomModel room;
  const _RoomThumbnail({required this.room});

  static const double _width = 124;
  static const double _height = 70; // ~16:9

  String? get _url => room.youtubeId != null
      ? 'https://img.youtube.com/vi/${room.youtubeId}/hqdefault.jpg'
      : null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: _height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
            // Scrim so the badges stay legible on bright frames.
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
          colors: [Color(0xFFE0F2FE), Color(0xFFEFF6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.headphones_rounded,
          size: 26,
          color: AppColors.purple.withValues(alpha: 0.45),
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

// ── Listener row: avatar stack + count ────────────────────────────────────

class _ListenerRow extends StatelessWidget {
  final RoomModel room;
  const _ListenerRow({required this.room});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AvatarStack(room: room),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            room.memberCount == 1
                ? '1 listening'
                : '${room.memberCount} listening',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.grey,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Overlapping avatars. Only the host's avatar is known from the list API, so
/// remaining listeners collapse into a "+N" bubble.
class _AvatarStack extends StatelessWidget {
  final RoomModel room;
  const _AvatarStack({required this.room});

  static const double _size = 24;
  static const double _overlap = 17;

  @override
  Widget build(BuildContext context) {
    final others = room.memberCount > 1 ? room.memberCount - 1 : 0;
    final showOthers = others > 0;
    final width = showOthers ? _size + _overlap : _size;

    return SizedBox(
      width: width,
      height: _size,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: _Avatar(
              avatarUrl: room.host?.avatar,
              name: room.host?.name ?? '?',
            ),
          ),
          if (showOthers)
            Positioned(
              left: _overlap,
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  color: AppColors.cardBg2,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.cardBg, width: 2),
                ),
                child: Center(
                  child: Text(
                    others > 9 ? '9+' : '+$others',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.grey,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  const _Avatar({this.avatarUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _AvatarStack._size,
      height: _AvatarStack._size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.cardBg, width: 2),
      ),
      child: ClipOval(
        child: avatarUrl != null
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _initial(),
              )
            : _initial(),
      ),
    );
  }

  Widget _initial() => Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
}
