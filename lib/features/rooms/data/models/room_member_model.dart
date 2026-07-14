import 'package:equatable/equatable.dart';
import '../../../../core/utils/map_utils.dart';

class RoomMemberModel extends Equatable {
  final int userId;
  final String name;
  final String? avatar;

  /// The user muted their own mic.
  final bool isMuted;

  /// The host muted them. They cannot unmute themselves out of this.
  final bool mutedByHost;

  const RoomMemberModel({
    required this.userId,
    required this.name,
    this.avatar,
    this.isMuted = true,
    this.mutedByHost = false,
  });

  /// What the mic icon should reflect: either kind of mute silences you.
  bool get isEffectivelyMuted => isMuted || mutedByHost;

  factory RoomMemberModel.fromJson(Map<String, dynamic> json) {
    try {
      return RoomMemberModel(
        userId: MapUtils.handleNullableIntKey(json, 'userId') ?? 0,
        name: MapUtils.handleNullableStringKey(json, 'name') ?? 'User',
        avatar: MapUtils.handleNullableStringKey(json, 'avatar'),
        isMuted: MapUtils.handleNullableBoolKey(json, 'isMuted') ?? true,
        mutedByHost:
            MapUtils.handleNullableBoolKey(json, 'mutedByHost') ?? false,
      );
    } catch (_) {
      return const RoomMemberModel(userId: 0, name: 'User');
    }
  }

  RoomMemberModel copyWith({bool? isMuted, bool? mutedByHost}) =>
      RoomMemberModel(
        userId: userId,
        name: name,
        avatar: avatar,
        isMuted: isMuted ?? this.isMuted,
        mutedByHost: mutedByHost ?? this.mutedByHost,
      );

  @override
  List<Object?> get props => [userId, name, avatar, isMuted, mutedByHost];
}
