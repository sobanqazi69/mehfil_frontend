import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme/app_colors.dart';
import '../../data/models/room_member_model.dart';
import '../cubits/room_cubit.dart';
import '../cubits/room_state.dart';

/// Header row of avatars for everyone whose mic is on. Each avatar grows a
/// glowing ring while that person is actually speaking, driven live by
/// LiveKit's active-speaker levels.
class UnmutedAvatars extends StatelessWidget {
  const UnmutedAvatars({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoomCubit, RoomState>(
      buildWhen: (prev, curr) => curr is RoomLoaded,
      builder: (context, state) {
        if (state is! RoomLoaded) return const SizedBox.shrink();

        final unmuted = state.members
            .where((m) =>
                !(state.mutedMap[m.userId] ?? m.isMuted) &&
                !(state.hostMutedMap[m.userId] ?? m.mutedByHost))
            .toList();

        if (unmuted.isEmpty) return const SizedBox.shrink();

        // Only the speaking rings listen to the level notifier, so the firehose
        // of audio updates never rebuilds the row itself.
        return ValueListenableBinder(
          notifier: context.read<RoomCubit>().speakingLevels,
          unmuted: unmuted,
          hostId: state.room.hostId,
        );
      },
    );
  }
}

class ValueListenableBinder extends StatelessWidget {
  final ValueNotifier<Map<String, double>> notifier;
  final List<RoomMemberModel> unmuted;
  final int hostId;

  const ValueListenableBinder({
    super.key,
    required this.notifier,
    required this.unmuted,
    required this.hostId,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Center(
        child: ValueListenableBuilder<Map<String, double>>(
          valueListenable: notifier,
          builder: (_, levels, __) {
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: unmuted.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final m = unmuted[i];
                // LiveKit identity is the userId as a string.
                final level = levels['${m.userId}'] ?? 0;
                return _UnmutedAvatar(
                  member: m,
                  isHost: m.userId == hostId,
                  speaking: level > 0.05,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _UnmutedAvatar extends StatelessWidget {
  final RoomMemberModel member;
  final bool isHost;
  final bool speaking;

  const _UnmutedAvatar({
    required this.member,
    required this.isHost,
    required this.speaking,
  });

  @override
  Widget build(BuildContext context) {
    final ring = isHost ? AppColors.gold : AppColors.success;

    return Tooltip(
      message: member.name,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
          border: Border.all(
            color: speaking ? AppColors.success : ring,
            // Ring thickens while talking — the cue you notice at a glance.
            width: speaking ? 3 : 2,
          ),
          boxShadow: speaking
              ? [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.6),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : null,
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
