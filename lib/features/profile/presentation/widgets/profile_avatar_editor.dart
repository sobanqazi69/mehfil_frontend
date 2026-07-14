import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';

/// Tappable avatar with a camera badge. Shows a spinner over the image while
/// the new photo uploads, so the tap never feels like it did nothing.
class ProfileAvatarEditor extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final bool uploading;
  final VoidCallback? onTap;

  const ProfileAvatarEditor({
    super.key,
    required this.avatarUrl,
    required this.name,
    required this.uploading,
    this.onTap,
  });

  static const double _size = 108;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Change profile photo',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: _size + 8,
          height: _size + 8,
          child: Stack(
            children: [
              Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyan.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (avatarUrl != null)
                        CachedNetworkImage(
                          imageUrl: avatarUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _initial(),
                          errorWidget: (_, __, ___) => _initial(),
                        )
                      else
                        _initial(),
                      if (uploading)
                        Container(
                          color: Colors.black.withValues(alpha: 0.45),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.fieldBorder, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    size: 16,
                    color: AppColors.cyanDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _initial() => Container(
        color: AppColors.cardBg2,
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: AppColors.grey,
            ),
          ),
        ),
      );
}
