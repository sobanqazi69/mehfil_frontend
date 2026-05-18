import 'package:equatable/equatable.dart';
import '../../../../core/utils/map_utils.dart';
import '../../../auth/data/models/user_model.dart';

class RoomModel extends Equatable {
  final int id;
  final String name;
  final int hostId;
  final int creatorId;
  final bool isPublic;
  final String? category;
  final String? youtubeId;
  final String? nextYoutubeId;
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
    required this.creatorId,
    this.isPublic = true,
    this.category,
    this.youtubeId,
    this.nextYoutubeId,
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
        creatorId: MapUtils.handleNullableIntKey(json, 'creatorId') ?? 0,
        isPublic: MapUtils.handleNullableBoolKey(json, 'isPublic') ?? true,
        category: MapUtils.handleNullableStringKey(json, 'category'),
        youtubeId: MapUtils.handleNullableStringKey(json, 'youtubeId'),
        nextYoutubeId: MapUtils.handleNullableStringKey(json, 'nextYoutubeId'),
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
          hostId: 0,
          creatorId: 0);
    }
  }

  RoomModel copyWith({
    int? hostId,
    int? creatorId,
    String? youtubeId,
    String? nextYoutubeId,
    bool? isPublic,
    double? timestampSec,
    bool? isPlaying,
    bool? isLive,
    int? memberCount,
  }) {
    return RoomModel(
      id: id,
      name: name,
      hostId: hostId ?? this.hostId,
      creatorId: creatorId ?? this.creatorId,
      isPublic: isPublic ?? this.isPublic,
      category: category,
      youtubeId: youtubeId ?? this.youtubeId,
      nextYoutubeId: nextYoutubeId ?? this.nextYoutubeId,
      timestampSec: timestampSec ?? this.timestampSec,
      isPlaying: isPlaying ?? this.isPlaying,
      isLive: isLive ?? this.isLive,
      host: host,
      memberCount: memberCount ?? this.memberCount,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        hostId,
        creatorId,
        isPublic,
        youtubeId,
        nextYoutubeId,
        timestampSec,
        isPlaying,
        isLive,
        memberCount
      ];
}
