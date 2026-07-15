import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../cubits/room_cubit.dart';
import '../cubits/room_state.dart';

/// Host-only room controls: privacy and room-wide mic.
Future<void> showRoomSettingsSheet(BuildContext context) {
  final cubit = context.read<RoomCubit>();

  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    isScrollControlled: true,
    // The sheet lives outside the room screen's provider scope once pushed, so
    // hand it the cubit explicitly.
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: const _RoomSettingsSheet(),
    ),
  );
}

class _RoomSettingsSheet extends StatelessWidget {
  const _RoomSettingsSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: BlocBuilder<RoomCubit, RoomState>(
          buildWhen: (_, curr) => curr is RoomLoaded,
          builder: (context, state) {
            if (state is! RoomLoaded) return const SizedBox.shrink();

            final cubit = context.read<RoomCubit>();
            final isPublic = state.room.isPublic;
            final anyoneMuted = cubit.anyoneHostMuted;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.fieldBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                        child: Row(
                          children: [
                            const Icon(Icons.tune_rounded,
                                size: 18, color: AppColors.cyanDark),
                            const SizedBox(width: 10),
                            Text(
                              'Room settings',
                              style: AppTextStyles.heading3
                                  .copyWith(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: AppColors.divider, height: 1),

                      _PrivacyRow(
                        isPublic: isPublic,
                        onChanged: (value) {
                          cubit.updateSettings(isPublic: value);
                          AppSnackbar.info(
                            context,
                            value
                                ? 'Room is now public'
                                : 'Room is now private',
                          );
                        },
                      ),
                      const Divider(color: AppColors.divider, height: 1),

                      // One action, not two: whichever is useful right now.
                      if (anyoneMuted)
                        _ActionRow(
                          icon: Icons.volume_up_rounded,
                          label: 'Unmute everyone',
                          subtitle: 'Give all listeners their mic back',
                          color: AppColors.success,
                          onTap: () {
                            cubit.unmuteAll();
                            Navigator.pop(context);
                            AppSnackbar.info(context, 'Everyone can speak');
                          },
                        )
                      else
                        _ActionRow(
                          icon: Icons.volume_off_rounded,
                          label: 'Mute everyone',
                          subtitle: 'Listeners cannot unmute themselves',
                          color: AppColors.error,
                          onTap: () {
                            cubit.muteAll();
                            Navigator.pop(context);
                            AppSnackbar.info(context, 'Everyone muted');
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _CancelButton(onTap: () => Navigator.pop(context)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  final bool isPublic;
  final ValueChanged<bool> onChanged;

  const _PrivacyRow({required this.isPublic, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(
            isPublic ? Icons.public_rounded : Icons.lock_rounded,
            size: 20,
            color: isPublic ? AppColors.cyanDark : AppColors.grey,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isPublic ? 'Public room' : 'Private room',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.slate,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  isPublic
                      ? 'Anyone can find and join'
                      : 'Hidden from browse',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.grey, fontSize: 10),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isPublic,
            onChanged: onChanged,
            activeTrackColor: AppColors.cyan,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.grey, fontSize: 10),
                    ),
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

class _CancelButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CancelButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Cancel',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
