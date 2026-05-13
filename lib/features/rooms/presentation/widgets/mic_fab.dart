import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';

class MicFab extends StatelessWidget {
  final bool isMuted;
  final VoidCallback onToggle;

  const MicFab({
    super.key,
    required this.isMuted,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: isMuted ? null : AppColors.primaryGradient,
          color: isMuted ? AppColors.cardBg : null,
          shape: BoxShape.circle,
          border: isMuted
              ? Border.all(color: AppColors.fieldBorder, width: 1.5)
              : null,
          boxShadow: isMuted
              ? null
              : [
                  BoxShadow(
                    color: AppColors.purple.withOpacity(0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Icon(
          isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          color: isMuted ? AppColors.grey : Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
