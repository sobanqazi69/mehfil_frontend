import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme/app_colors.dart';
import '../../data/models/room_member_model.dart';
import '../cubits/room_cubit.dart';
import '../cubits/room_state.dart';

/// Row of avatars for everyone whose mic is currently on.
///
/// NOTE: this reflects mic state (unmuted), not voice activity. There is no
/// LiveKit connection yet, so the app cannot know who is actually talking.
class UnmutedAvatars extends StatelessWidget {
  const UnmutedAvatars({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoomCubit, RoomState>(
      buildWhen: (prev, curr) => curr is RoomLoaded,
      builder: (context, state) {
        if (state is! RoomLoaded) return const SizedBox.shrink();

        final unmuted = state.members
            .where((m) => !(state.mutedMap[m.userId] ?? m.isMuted))
            .toList();

        if (unmuted.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 34,
          child: Center(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: unmuted.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) => _UnmutedAvatar(
                member: unmuted[i],
                isHost: unmuted[i].userId == state.room.hostId,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UnmutedAvatar extends StatelessWidget {
  final RoomMemberModel member;
  final bool isHost;

  const _UnmutedAvatar({required this.member, required this.isHost});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: member.name,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
          border: Border.all(
            color: isHost ? AppColors.gold : AppColors.success,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withValues(alpha: 0.35),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
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
    );
  }

  Widget _initial() => Center(
        child: Text(
          member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
}
