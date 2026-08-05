import 'package:equatable/equatable.dart';
import '../../../../core/utils/map_utils.dart';

/// One mic slot in a room.
///
/// Mirrors Bazmi's `RoomSeat` so the two apps stay conceptually identical:
/// seats are numbered from 0, seat 0 belongs to the host, and only a user
/// sitting on a seat is allowed to speak. An empty seat has a null [userId].
class RoomSeatModel extends Equatable {
  final int seatNo;
  final int? userId;
  final String? name;
  final String? avatar;

  /// Muted while seated. Distinct from leaving the seat entirely.
  final bool isMuted;

  /// The host locked this slot — nobody may sit down on it.
  final bool isLocked;

  /// Seat reserved for the host (`SeatRole.HOST` in Bazmi).
  final bool isHostSeat;

  const RoomSeatModel({
    required this.seatNo,
    this.userId,
    this.name,
    this.avatar,
    this.isMuted = false,
    this.isLocked = false,
    this.isHostSeat = false,
  });

  bool get isOccupied => userId != null;
  bool get isEmpty => userId == null;

  /// An empty slot the UI can render before the server has said anything.
  factory RoomSeatModel.vacant(int seatNo) =>
      RoomSeatModel(seatNo: seatNo, isHostSeat: seatNo == 0);

  factory RoomSeatModel.fromJson(Map<String, dynamic> json) {
    try {
      final user = MapUtils.handleNullableMapKey(json, 'user');
      return RoomSeatModel(
        seatNo: MapUtils.handleNullableIntKey(json, 'seatNo') ?? 0,
        userId: MapUtils.handleNullableIntKey(json, 'userId') ??
            (user != null ? MapUtils.handleNullableIntKey(user, 'id') : null),
        name: user != null
            ? MapUtils.handleNullableStringKey(user, 'name')
            : MapUtils.handleNullableStringKey(json, 'name'),
        avatar: user != null
            ? MapUtils.handleNullableStringKey(user, 'avatar')
            : MapUtils.handleNullableStringKey(json, 'avatar'),
        isMuted: MapUtils.handleNullableBoolKey(json, 'isMuted') ?? false,
        isLocked: MapUtils.handleNullableBoolKey(json, 'isLocked') ?? false,
        isHostSeat:
            (MapUtils.handleNullableStringKey(json, 'role') ?? '').toUpperCase() ==
                'HOST',
      );
    } catch (_) {
      return const RoomSeatModel(seatNo: 0);
    }
  }

  RoomSeatModel copyWith({
    int? userId,
    String? name,
    String? avatar,
    bool? isMuted,
    bool? isLocked,
    bool clearUser = false,
  }) =>
      RoomSeatModel(
        seatNo: seatNo,
        userId: clearUser ? null : (userId ?? this.userId),
        name: clearUser ? null : (name ?? this.name),
        avatar: clearUser ? null : (avatar ?? this.avatar),
        isMuted: clearUser ? false : (isMuted ?? this.isMuted),
        isLocked: isLocked ?? this.isLocked,
        isHostSeat: isHostSeat,
      );

  @override
  List<Object?> get props =>
      [seatNo, userId, name, avatar, isMuted, isLocked, isHostSeat];
}
