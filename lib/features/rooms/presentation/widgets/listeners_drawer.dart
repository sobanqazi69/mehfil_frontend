import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../data/models/room_member_model.dart';
import '../cubits/room_cubit.dart';
import '../cubits/room_state.dart';

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

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: members.length,
              itemBuilder: (_, i) {
                final m = members[i];
                return _ListenerRow(
                  member: m,
                  isHost: m.userId == hostId,
                  // Live mic state overrides the value baked into the member
                  // payload.
                  isMuted: state.mutedMap[m.userId] ?? m.isMuted,
                );
              },
            );
          },
        ),
      ),
    );
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
  final bool isMuted;

  const _ListenerRow({
    required this.member,
    required this.isHost,
    required this.isMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                  ),
              ],
            ),
          ),
          Icon(
            isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            size: 18,
            color: isMuted ? AppColors.greyLight : AppColors.success,
          ),
        ],
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
