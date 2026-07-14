import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/cubits/auth_cubit.dart';
import '../../../auth/presentation/cubits/auth_state.dart';
import '../../data/models/room_member_model.dart';
import '../cubits/room_cubit.dart';
import '../cubits/room_state.dart';
import 'listener_actions_sheet.dart';

/// Right-side drawer listing everyone currently in the room.
///
/// Reads straight off RoomCubit, which re-emits on every `room:members` socket
/// event, so joins, leaves and mute changes land here without extra plumbing.
class ListenersDrawer extends StatelessWidget {
  const ListenersDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.cardBg,
      child: SafeArea(
        child: BlocBuilder<RoomCubit, RoomState>(
          buildWhen: (prev, curr) => curr is RoomLoaded,
          builder: (context, state) {
            if (state is! RoomLoaded) {
              return const Center(child: CircularProgressIndicator());
            }

            final hostId = state.room.hostId;
            // Backend sends members oldest-join-first; lift the host out so it
            // pins to the top while everyone else keeps that join order.
            final members = [
              ...state.members.where((m) => m.userId == hostId),
              ...state.members.where((m) => m.userId != hostId),
            ];

            if (members.isEmpty) return const _EmptyListeners();

            final authState = context.watch<AuthCubit>().state;
            final currentUserId =
                authState is AuthAuthenticated ? authState.user.id : 0;
            final amHost = currentUserId == hostId;

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: members.length,
              itemBuilder: (_, i) {
                final m = members[i];
                // Live socket state overrides what the roster payload carried.
                final selfMuted = state.mutedMap[m.userId] ?? m.isMuted;
                final hostMuted = state.hostMutedMap[m.userId] ?? m.mutedByHost;
                // Host can act on everyone but themselves.
                final canManage = amHost && m.userId != currentUserId;

                return _ListenerRow(
                  member: m,
                  isHost: m.userId == hostId,
                  selfMuted: selfMuted,
                  hostMuted: hostMuted,
                  onTap:
                      canManage ? () => _manage(context, m, hostMuted) : null,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// [hostMuted] is the host lock, not the member's own mute — the sheet only
/// ever toggles the lock.
Future<void> _manage(
  BuildContext context,
  RoomMemberModel member,
  bool hostMuted,
) async {
  final cubit = context.read<RoomCubit>();
  final action = await showListenerActionsSheet(
    context,
    member: member,
    hostMuted: hostMuted,
  );
  if (action == null) return;

  switch (action) {
    case ListenerAction.toggleMute:
      cubit.hostToggleMic(member.userId, !hostMuted);
      if (context.mounted) {
        AppSnackbar.info(
          context,
          hostMuted ? '${member.name} can speak again' : '${member.name} muted',
        );
      }
    case ListenerAction.makeHost:
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Make host?'),
          content: Text(
            '${member.name} will control the room. '
            'You will become a normal listener and cannot take it back.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Make host'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      cubit.hostTransferTo(member.userId);
      if (context.mounted) {
        AppSnackbar.info(context, '${member.name} is now the host');
      }
    case ListenerAction.kick:
      cubit.hostKickUser(member.userId);
      if (context.mounted) {
        AppSnackbar.info(context, '${member.name} removed from the room');
      }
  }
}

class _EmptyListeners extends StatelessWidget {
  const _EmptyListeners();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Nobody else is here yet.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey),
        ),
      ),
    );
  }
}

class _ListenerRow extends StatelessWidget {
  final RoomMemberModel member;
  final bool isHost;
  final bool selfMuted;
  final bool hostMuted;
  final VoidCallback? onTap;

  const _ListenerRow({
    required this.member,
    required this.isHost,
    required this.selfMuted,
    required this.hostMuted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _Avatar(member: member, isHost: isHost),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    member.name,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.slate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isHost)
                    Text(
                      'Host',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.gold, fontSize: 10),
                    )
                  else if (hostMuted)
                    Text(
                      'Muted by host',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.error, fontSize: 10),
                    ),
                ],
              ),
            ),
            // Host-mute is red and locked; a plain self-mute is just grey.
            Icon(
              hostMuted
                  ? Icons.mic_off_rounded
                  : (selfMuted ? Icons.mic_off_rounded : Icons.mic_rounded),
              size: 18,
              color: hostMuted
                  ? AppColors.error
                  : (selfMuted ? AppColors.greyLight : AppColors.success),
            ),
            // if (onTap != null) ...[
            //   const SizedBox(width: 8),
            //   const Icon(Icons.more_vert_rounded,
            //       size: 18, color: AppColors.greyLight),
            // ],
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final RoomMemberModel member;
  final bool isHost;

  const _Avatar({required this.member, required this.isHost});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
        border: Border.all(
          color: isHost ? AppColors.gold : AppColors.fieldBorder,
          width: isHost ? 2 : 1,
        ),
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
    );
  }

  Widget _initial() => Center(
        child: Text(
          member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      );
}
