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
    return SizedBox(
      width: 62,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Glow ring for active speakers
              if (!isMuted)
                _SpeakerGlow(),
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  border: Border.all(
                    color: isMuted
                        ? AppColors.fieldBorder
                        : AppColors.cyan,
                    width: isMuted ? 1.5 : 2.5,
                  ),
                ),
                child: ClipOval(
                  child: member.avatar != null
                      ? CachedNetworkImage(
                          imageUrl: member.avatar!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _Initial(name: member.name),
                        )
                      : _Initial(name: member.name),
                ),
              ),
              // Host crown
              if (isHost)
                Positioned(
                  top: -8,
                  child: _CrownBadge(),
                ),
              // Mic indicator
              Positioned(
                bottom: -4,
                right: -4,
                child: _MicBadge(isMuted: isMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            member.name.split(' ').first,
            style: AppTextStyles.labelSmall.copyWith(
              color: isMuted
                  ? AppColors.grey
                  : AppColors.slate,
              fontWeight:
                  isMuted ? FontWeight.w400 : FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SpeakerGlow extends StatefulWidget {
  @override
  State<_SpeakerGlow> createState() => _SpeakerGlowState();
}

class _SpeakerGlowState extends State<_SpeakerGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _anim,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.cyan.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}

class _CrownBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.5),
            blurRadius: 6,
          ),
        ],
      ),
      child: const Icon(Icons.star_rounded, color: Colors.white, size: 10),
    );
  }
}

class _MicBadge extends StatelessWidget {
  final bool isMuted;
  const _MicBadge({required this.isMuted});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: isMuted ? AppColors.white : AppColors.cyan,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.lightBg, width: 1.5),
        boxShadow: isMuted
            ? null
            : [
                BoxShadow(
                  color: AppColors.cyan.withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
      ),
      child: Icon(
        isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
        color: Colors.white,
        size: 11,
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  final String name;
  const _Initial({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cyan.withValues(alpha: 0.12),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: AppTextStyles.heading3.copyWith(
            color: AppColors.white,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}
