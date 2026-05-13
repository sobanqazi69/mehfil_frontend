import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../data/models/room_model.dart';

class RoomCard extends StatelessWidget {
  final RoomModel room;
  final VoidCallback onTap;

  const RoomCard({super.key, required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppColors.cardDecoration,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _HostAvatar(avatarUrl: room.host?.avatar, name: room.host?.name),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.host?.name ?? 'Unknown',
                        style: AppTextStyles.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        room.name,
                        style: AppTextStyles.labelMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _LiveBadge(isLive: room.isLive),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (room.category != null) ...[
                  _CategoryBadge(category: room.category!),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                const Icon(Icons.people_alt_rounded,
                    size: 14, color: AppColors.grey),
                const SizedBox(width: 4),
                Text(
                  '${room.memberCount}',
                  style: AppTextStyles.bodySmall,
                ),
                if (room.youtubeId != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.play_circle_outline_rounded,
                      size: 14, color: AppColors.cyan),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HostAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? name;
  const _HostAvatar({this.avatarUrl, this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
      ),
      child: ClipOval(
        child: avatarUrl != null
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _initials(name),
              )
            : _initials(name),
      ),
    );
  }

  Widget _initials(String? n) => Center(
        child: Text(
          (n?.isNotEmpty == true ? n![0] : '?').toUpperCase(),
          style: AppTextStyles.labelMedium,
        ),
      );
}

class _LiveBadge extends StatelessWidget {
  final bool isLive;
  const _LiveBadge({required this.isLive});

  @override
  Widget build(BuildContext context) {
    if (!isLive) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.error.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text('LIVE',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.error, fontSize: 10)),
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.purple.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.purple.withOpacity(0.3)),
      ),
      child: Text(
        category,
        style: AppTextStyles.labelSmall
            .copyWith(color: AppColors.purpleLight, fontSize: 10),
      ),
    );
  }
}
