import 'package:equatable/equatable.dart';
import '../../../../core/utils/map_utils.dart';

class RoomMemberModel extends Equatable {
  final int userId;
  final String name;
  final String? avatar;
  final bool isMuted;

  const RoomMemberModel({
    required this.userId,
    required this.name,
    this.avatar,
    this.isMuted = true,
  });

  factory RoomMemberModel.fromJson(Map<String, dynamic> json) {
    try {
      return RoomMemberModel(
        userId: MapUtils.handleNullableIntKey(json, 'userId') ?? 0,
        name: MapUtils.handleNullableStringKey(json, 'name') ?? 'User',
        avatar: MapUtils.handleNullableStringKey(json, 'avatar'),
        isMuted: MapUtils.handleNullableBoolKey(json, 'isMuted') ?? true,
      );
    } catch (_) {
      return const RoomMemberModel(userId: 0, name: 'User');
    }
  }

  RoomMemberModel copyWith({bool? isMuted}) =>
      RoomMemberModel(
          userId: userId, name: name, avatar: avatar,
          isMuted: isMuted ?? this.isMuted);

  @override
  List<Object?> get props => [userId, name, avatar, isMuted];
}
