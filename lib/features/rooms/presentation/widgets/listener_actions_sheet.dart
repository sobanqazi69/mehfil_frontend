import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../data/models/room_member_model.dart';

enum ListenerAction { toggleMute, makeHost, kick }

/// Host-only actions for a single listener. Returns the chosen action, or null
/// if dismissed.
/// [hostMuted] is the host lock on this member — the sheet toggles that lock,
/// not the member's own mic setting.
Future<ListenerAction?> showListenerActionsSheet(
  BuildContext context, {
  required RoomMemberModel member,
  required bool hostMuted,
}) {
  return showModalBottomSheet<ListenerAction>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _ListenerActionsSheet(member: member, hostMuted: hostMuted),
  );
}

class _ListenerActionsSheet extends StatelessWidget {
  final RoomMemberModel member;
  final bool hostMuted;

  const _ListenerActionsSheet({required this.member, required this.hostMuted});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
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
                  _MemberHeader(member: member),
                  const Divider(color: AppColors.divider, height: 1),
                  _ActionRow(
                    icon: hostMuted
                        ? Icons.mic_rounded
                        : Icons.mic_off_rounded,
                    label: hostMuted ? 'Let them speak' : 'Mute',
                    subtitle: hostMuted
                        ? 'Lift your mute — their own mic setting applies'
                        : 'They cannot unmute themselves',
                    color: AppColors.slate,
                    onTap: () =>
                        Navigator.pop(context, ListenerAction.toggleMute),
                  ),
                  const Divider(color: AppColors.divider, height: 1),
                  _ActionRow(
                    icon: Icons.workspace_premium_rounded,
                    label: 'Make host',
                    subtitle: 'You become a normal listener',
                    color: AppColors.gold,
                    onTap: () =>
                        Navigator.pop(context, ListenerAction.makeHost),
                  ),
                  const Divider(color: AppColors.divider, height: 1),
                  _ActionRow(
                    icon: Icons.person_remove_rounded,
                    label: 'Remove from room',
                    color: AppColors.error,
                    onTap: () => Navigator.pop(context, ListenerAction.kick),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: Material(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.pop(context),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberHeader extends StatelessWidget {
  final RoomMemberModel member;
  const _MemberHeader({required this.member});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
            ),
            child: ClipOval(
              child: member.avatar != null
                  ? CachedNetworkImage(
                      imageUrl: member.avatar!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _initial(),
                    )
                  : _initial(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              member.name,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.slate,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _initial() => Center(
        child: Text(
          member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      );
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.grey,
                          fontSize: 10,
                        ),
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
