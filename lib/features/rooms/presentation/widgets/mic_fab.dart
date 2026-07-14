import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';

class MicFab extends StatelessWidget {
  /// The user's own mic setting.
  final bool isMuted;

  /// The host muted us — we cannot unmute ourselves out of it.
  final bool isHostMuted;

  final VoidCallback onToggle;

  const MicFab({
    super.key,
    required this.isMuted,
    this.isHostMuted = false,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // A host mute outranks the user's own setting.
    final muted = isMuted || isHostMuted;

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: muted ? null : AppColors.primaryGradient,
          color: isHostMuted
              ? AppColors.error.withValues(alpha: 0.12)
              : (muted ? AppColors.cardBg : null),
          shape: BoxShape.circle,
          border: muted
              ? Border.all(
                  color: isHostMuted
                      ? AppColors.error.withValues(alpha: 0.5)
                      : AppColors.fieldBorder,
                  width: 1.5,
                )
              : null,
          boxShadow: muted
              ? null
              : [
                  BoxShadow(
                    color: AppColors.purple.withValues(alpha: 0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              muted ? Icons.mic_off_rounded : Icons.mic_rounded,
              color: isHostMuted
                  ? AppColors.error
                  : (muted ? AppColors.grey : Colors.white),
              size: 22,
            ),
            // Locked by the host: only they can lift it.
            if (isHostMuted)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 8,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
