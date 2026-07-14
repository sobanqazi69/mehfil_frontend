import 'package:equatable/equatable.dart';
import '../../../../core/utils/map_utils.dart';

class UserModel extends Equatable {
  final int id;
  final String googleId;
  final String name;
  final String? username;
  final String email;
  final String? avatar;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.googleId,
    required this.name,
    this.username,
    required this.email,
    this.avatar,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    try {
      return UserModel(
        id: MapUtils.handleNullableIntKey(json, 'id') ?? 0,
        googleId: MapUtils.handleNullableStringKey(json, 'googleId') ?? '',
        name: MapUtils.handleNullableStringKey(json, 'name') ?? 'User',
        username: MapUtils.handleNullableStringKey(json, 'username'),
        email: MapUtils.handleNullableStringKey(json, 'email') ?? '',
        avatar: MapUtils.handleNullableStringKey(json, 'avatar'),
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString())
            : null,
      );
    } catch (_) {
      return const UserModel(
          id: 0, googleId: '', name: 'User', email: '');
    }
  }

  UserModel copyWith({
    int? id,
    String? googleId,
    String? name,
    String? username,
    String? email,
    String? avatar,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      googleId: googleId ?? this.googleId,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, googleId, name, username, email, avatar];
}
