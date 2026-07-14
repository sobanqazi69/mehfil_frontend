import 'package:equatable/equatable.dart';
import '../../../../core/utils/map_utils.dart';

class MessageModel extends Equatable {
  final int id;
  final int userId;
  final String name;
  final String? avatar;
  final String text;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.userId,
    required this.name,
    this.avatar,
    required this.text,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    try {
      final userMap = MapUtils.handleNullableMapKey(json, 'user');
      return MessageModel(
        id: MapUtils.handleNullableIntKey(json, 'id') ?? 0,
        userId: MapUtils.handleNullableIntKey(json, 'userId') ??
            MapUtils.handleNullableIntKey(userMap, 'id') ?? 0,
        name: MapUtils.handleNullableStringKey(userMap, 'name') ??
            MapUtils.handleNullableStringKey(json, 'name') ?? 'User',
        avatar: MapUtils.handleNullableStringKey(userMap, 'avatar') ??
            MapUtils.handleNullableStringKey(json, 'avatar'),
        text: MapUtils.handleNullableStringKey(json, 'text') ?? '',
        createdAt: DateTime.tryParse(
                MapUtils.handleNullableStringKey(json, 'createdAt') ?? '') ??
            DateTime.now(),
      );
    } catch (_) {
      return MessageModel(
        id: 0,
        userId: 0,
        name: 'User',
        text: MapUtils.handleNullableStringKey(json, 'text') ?? '',
        createdAt: DateTime.now(),
      );
    }
  }

  @override
  List<Object?> get props => [id, userId, text, createdAt];
}
