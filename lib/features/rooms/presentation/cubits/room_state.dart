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
  final Map<int, bool> mutedMap; // userId → self-muted
  final Map<int, bool> hostMutedMap; // userId → muted by host
  final bool isMicMuted; // our own self-mute
  final bool isHostMuted; // the host muted us

  const RoomLoaded({
    required this.room,
    this.members = const [],
    this.messages = const [],
    this.voiceToken,
    this.voiceRoomName,
    this.mutedMap = const {},
    this.hostMutedMap = const {},
    this.isMicMuted = true,
    this.isHostMuted = false,
  });

  RoomLoaded copyWith({
    RoomModel? room,
    List<RoomMemberModel>? members,
    List<MessageModel>? messages,
    String? voiceToken,
    String? voiceRoomName,
    Map<int, bool>? mutedMap,
    Map<int, bool>? hostMutedMap,
    bool? isMicMuted,
    bool? isHostMuted,
  }) {
    return RoomLoaded(
      room: room ?? this.room,
      members: members ?? this.members,
      messages: messages ?? this.messages,
      voiceToken: voiceToken ?? this.voiceToken,
      voiceRoomName: voiceRoomName ?? this.voiceRoomName,
      mutedMap: mutedMap ?? this.mutedMap,
      hostMutedMap: hostMutedMap ?? this.hostMutedMap,
      isMicMuted: isMicMuted ?? this.isMicMuted,
      isHostMuted: isHostMuted ?? this.isHostMuted,
    );
  }

  @override
  List<Object?> get props =>
      [room, members, messages, voiceToken, mutedMap, hostMutedMap,
        isMicMuted, isHostMuted];
}

class RoomError extends RoomState {
  final String message;
  const RoomError(this.message);
  @override
  List<Object?> get props => [message];
}

/// The host removed us from the room.
class RoomKicked extends RoomState {
  const RoomKicked();
}
