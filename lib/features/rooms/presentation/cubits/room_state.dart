import 'package:equatable/equatable.dart';
import '../../data/models/message_model.dart';
import '../../data/models/room_member_model.dart';
import '../../data/models/room_model.dart';

abstract class RoomState extends Equatable {
  const RoomState();
  @override
  List<Object?> get props => [];
}

class RoomInitial extends RoomState {
  const RoomInitial();
}

class RoomLoading extends RoomState {
  const RoomLoading();
}

class RoomLoaded extends RoomState {
  final RoomModel room;
  final List<RoomMemberModel> members;
  final List<MessageModel> messages;
  final String? voiceToken;
  final String? voiceRoomName;
  final Map<int, bool> mutedMap; // userId → isMuted
  final bool isMicMuted;

  const RoomLoaded({
    required this.room,
    this.members = const [],
    this.messages = const [],
    this.voiceToken,
    this.voiceRoomName,
    this.mutedMap = const {},
    this.isMicMuted = true,
  });

  RoomLoaded copyWith({
    RoomModel? room,
    List<RoomMemberModel>? members,
    List<MessageModel>? messages,
    String? voiceToken,
    String? voiceRoomName,
    Map<int, bool>? mutedMap,
    bool? isMicMuted,
  }) {
    return RoomLoaded(
      room: room ?? this.room,
      members: members ?? this.members,
      messages: messages ?? this.messages,
      voiceToken: voiceToken ?? this.voiceToken,
      voiceRoomName: voiceRoomName ?? this.voiceRoomName,
      mutedMap: mutedMap ?? this.mutedMap,
      isMicMuted: isMicMuted ?? this.isMicMuted,
    );
  }

  @override
  List<Object?> get props =>
      [room, members, messages, voiceToken, mutedMap, isMicMuted];
}

class RoomError extends RoomState {
  final String message;
  const RoomError(this.message);
  @override
  List<Object?> get props => [message];
}
