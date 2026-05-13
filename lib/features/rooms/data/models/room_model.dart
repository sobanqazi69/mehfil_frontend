import 'package:equatable/equatable.dart';
import '../../../../core/utils/map_utils.dart';
import '../../../auth/data/models/user_model.dart';

class RoomModel extends Equatable {
  final int id;
  final String name;
  final int hostId;
  final bool isPublic;
  final String? category;
  final String? youtubeId;
  final double timestampSec;
  final bool isPlaying;
  final bool isLive;
  final UserModel? host;
  final int memberCount;
  final DateTime? createdAt;

  const RoomModel({
    required this.id,
    required this.name,
    required this.hostId,
    this.isPublic = true,
    this.category,
    this.youtubeId,
    this.timestampSec = 0,
    this.isPlaying = false,
    this.isLive = true,
    this.host,
    this.memberCount = 0,
    this.createdAt,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    try {
      final countData = MapUtils.handleNullableMapKey(json, '_count');
      final hostData = MapUtils.handleNullableMapKey(json, 'host');

      return RoomModel(
        id: MapUtils.handleNullableIntKey(json, 'id') ?? 0,
        name: MapUtils.handleNullableStringKey(json, 'name') ?? '',
        hostId: MapUtils.handleNullableIntKey(json, 'hostId') ?? 0,
        isPublic: MapUtils.handleNullableBoolKey(json, 'isPublic') ?? true,
        category: MapUtils.handleNullableStringKey(json, 'category'),
        youtubeId: MapUtils.handleNullableStringKey(json, 'youtubeId'),
        timestampSec:
            MapUtils.handleNullableDoubleKey(json, 'timestampSec') ?? 0,
        isPlaying: MapUtils.handleNullableBoolKey(json, 'isPlaying') ?? false,
        isLive: MapUtils.handleNullableBoolKey(json, 'isLive') ?? true,
        host: hostData != null ? UserModel.fromJson(hostData) : null,
        memberCount: MapUtils.handleNullableIntKey(countData, 'members') ?? 0,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString())
            : null,
      );
    } catch (_) {
      return RoomModel(
          id: 0,
          name: MapUtils.handleNullableStringKey(json, 'name') ?? '',
          hostId: 0);
    }
  }

  RoomModel copyWith({
    String? youtubeId,
    double? timestampSec,
    bool? isPlaying,
    bool? isLive,
    int? memberCount,
  }) {
    return RoomModel(
      id: id,
      name: name,
      hostId: hostId,
      isPublic: isPublic,
      category: category,
      youtubeId: youtubeId ?? this.youtubeId,
      timestampSec: timestampSec ?? this.timestampSec,
      isPlaying: isPlaying ?? this.isPlaying,
      isLive: isLive ?? this.isLive,
      host: host,
      memberCount: memberCount ?? this.memberCount,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, hostId, youtubeId, isPlaying, isLive, memberCount];
}
