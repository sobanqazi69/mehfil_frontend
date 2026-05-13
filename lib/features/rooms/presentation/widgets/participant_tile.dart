import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../data/models/room_member_model.dart';

class ParticipantTile extends StatelessWidget {
  final RoomMemberModel member;
  final bool isMuted;
  final bool isHost;

  const ParticipantTile({
    super.key,
    required this.member,
    this.isMuted = true,
    this.isHost = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                border: Border.all(
                  color: isMuted ? AppColors.fieldBorder : AppColors.cyan,
                  width: isMuted ? 1.5 : 2.5,
                ),
              ),
              child: ClipOval(
                child: member.avatar != null
                    ? CachedNetworkImage(
                        imageUrl: member.avatar!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _InitialPlaceholder(name: member.name),
                      )
                    : _InitialPlaceholder(name: member.name),
              ),
            ),
            if (isHost)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star_rounded,
                      color: Colors.white, size: 10),
                ),
              ),
            Positioned(
              bottom: -4,
              right: -4,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: isMuted ? AppColors.cardBg : AppColors.cyan,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: AppColors.darkBg, width: 1.5),
                ),
                child: Icon(
                  isMuted
                      ? Icons.mic_off_rounded
                      : Icons.mic_rounded,
                  color: Colors.white,
                  size: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 60,
          child: Text(
            member.name.split(' ').first,
            style: AppTextStyles.labelSmall,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _InitialPlaceholder extends StatelessWidget {
  final String name;
  const _InitialPlaceholder({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.purple.withOpacity(0.4),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: AppTextStyles.heading3.copyWith(color: AppColors.white),
        ),
      ),
    );
  }
}
