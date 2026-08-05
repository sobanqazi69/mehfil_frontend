import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/services/volume_service.dart';

/// Per-listener mixer: how loud the video is, and how loud everyone else is.
/// Open to every user — these levels are local and never leave the device.
Future<void> showVolumeSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    isScrollControlled: true,
    builder: (_) => const _VolumeSheet(),
  );
}

const _gold = Color(0xFFFBBF24);
const _mint = Color(0xFF00FFB2);
const _sheetBg = Color(0xFF130E26);

class _VolumeSheet extends StatelessWidget {
  const _VolumeSheet();

  @override
  Widget build(BuildContext context) {
    final volume = VolumeService.instance;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          decoration: BoxDecoration(
            color: _sheetBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _gold.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 18, color: _gold),
                    const SizedBox(width: 10),
                    Text(
                      'Sound',
                      style: AppTextStyles.heading3
                          .copyWith(fontSize: 16, color: _gold),
                    ),
                    const Spacer(),
                    Text(
                      'Only you',
                      style: AppTextStyles.labelSmall.copyWith(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: _gold.withValues(alpha: 0.12),
              ),
              _VolumeRow(
                label: 'Video',
                subtitle: 'Music and sound from the video',
                accent: _gold,
                onIcon: Icons.movie_filter_rounded,
                offIcon: Icons.videocam_off_rounded,
                listenable: volume.videoVolume,
                onChanged: volume.setVideoVolume,
                onToggleMuted: volume.toggleVideoMuted,
              ),
              Divider(
                height: 1,
                indent: 22,
                endIndent: 22,
                color: _gold.withValues(alpha: 0.08),
              ),
              _VolumeRow(
                label: 'Voices',
                subtitle: 'Everyone talking on the call',
                accent: _mint,
                onIcon: Icons.record_voice_over_rounded,
                offIcon: Icons.voice_over_off_rounded,
                listenable: volume.callVolume,
                onChanged: volume.setCallVolume,
                onToggleMuted: volume.toggleCallMuted,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color accent;
  final IconData onIcon;
  final IconData offIcon;
  final ValueListenable<int> listenable;
  final ValueChanged<int> onChanged;
  final VoidCallback onToggleMuted;

  const _VolumeRow({
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.onIcon,
    required this.offIcon,
    required this.listenable,
    required this.onChanged,
    required this.onToggleMuted,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: listenable,
      builder: (context, value, _) {
        final isMuted = value == 0;
        final tint = isMuted ? Colors.white.withValues(alpha: 0.35) : accent;

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _MuteButton(
                    icon: isMuted ? offIcon : onIcon,
                    tint: tint,
                    onTap: onToggleMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          isMuted ? 'Muted' : subtitle,
                          style: AppTextStyles.labelSmall.copyWith(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '$value%',
                      textAlign: TextAlign.right,
                      style: AppTextStyles.labelSmall.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tint,
                      ),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  activeTrackColor: tint,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.10),
                  thumbColor: isMuted ? Colors.white.withValues(alpha: 0.5) : accent,
                  overlayColor: accent.withValues(alpha: 0.15),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                  trackShape: const RoundedRectSliderTrackShape(),
                ),
                child: Slider(
                  value: value.toDouble(),
                  min: 0,
                  max: VolumeService.maxVolume.toDouble(),
                  onChanged: (v) => onChanged(v.round()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MuteButton extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  const _MuteButton({
    required this.icon,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: tint.withValues(alpha: 0.30)),
        ),
        child: Icon(icon, size: 18, color: tint),
      ),
    );
  }
}
