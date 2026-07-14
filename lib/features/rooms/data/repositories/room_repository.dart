import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/socket_service.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../../../core/utils/map_utils.dart';
import '../models/message_model.dart';
import '../models/room_member_model.dart';
import '../models/room_model.dart';

class RoomRepository {
  final ApiClient _api;
  final SocketService _socket;

  RoomRepository(this._api, this._socket);

  // ── REST ────────────────────────────────────────────────────────────

  Future<List<RoomModel>> browseRooms({int page = 1}) async {
    try {
      final res = await _api.get(ApiEndpoints.rooms, params: {'page': page});
      final list = MapUtils.asMapList(MapUtils.asMap(res.data)['rooms']);
      return list.map(RoomModel.fromJson).toList();
    } on DioException catch (e) {
      DebugLogger.error('browseRooms failed', error: e);
      throw _parseError(e);
    }
  }

  Future<List<RoomModel>> getMyRooms() async {
    try {
      final res = await _api.get(ApiEndpoints.myRooms);
      final list = MapUtils.asMapList(res.data);
      return list.map(RoomModel.fromJson).toList();
    } on DioException catch (e) {
      DebugLogger.error('getMyRooms failed', error: e);
      throw _parseError(e);
    }
  }

  Future<RoomModel> createRoom({
    required String name,
    required String youtubeId,
  }) async {
    try {
      final res = await _api.post(ApiEndpoints.rooms, data: {
        'name': name,
        'youtubeId': youtubeId,
      });
      return RoomModel.fromJson(MapUtils.asMap(res.data));
    } on DioException catch (e) {
      DebugLogger.error('createRoom failed', error: e);
      throw _parseError(e);
    }
  }

  Future<RoomModel> getRoom(int id) async {
    try {
      final res = await _api.get(ApiEndpoints.room(id));
      return RoomModel.fromJson(MapUtils.asMap(res.data));
    } on DioException catch (e) {
      DebugLogger.error('getRoom failed', error: e);
      throw _parseError(e);
    }
  }

  Future<void> deleteRoom(int id) async {
    try {
      await _api.delete(ApiEndpoints.room(id));
    } on DioException catch (e) {
      DebugLogger.error('deleteRoom failed', error: e);
      throw _parseError(e);
    }
  }

  Future<List<MessageModel>> getRoomMessages(int roomId) async {
    try {
      final res = await _api.get(ApiEndpoints.roomMessages(roomId));
      final list = MapUtils.asMapList(res.data);
      return list.map(MessageModel.fromJson).toList();
    } on DioException catch (e) {
      DebugLogger.error('getRoomMessages failed', error: e);
      throw _parseError(e);
    }
  }

  Future<Map<String, dynamic>> getVoiceToken(int roomId) async {
    try {
      final res = await _api.post(ApiEndpoints.voiceToken,
          data: {'roomId': roomId});
      return MapUtils.asMap(res.data);
    } on DioException catch (e) {
      DebugLogger.error('getVoiceToken failed', error: e);
      throw _parseError(e);
    }
  }

  // ── Socket ──────────────────────────────────────────────────────────

  void joinRoom(int roomId, int userId) {
    _socket.emit('room:join', {'roomId': roomId, 'userId': userId});
  }

  void leaveRoom(int roomId, int userId) {
    _socket.emit('room:leave', {'roomId': roomId, 'userId': userId});
  }

  void sendMessage(int roomId, String text) {
    _socket.emit('chat:send', {'roomId': roomId, 'text': text});
  }

  void toggleMic(int roomId, int userId, bool isMuted) {
    _socket.emit('mic:toggle',
        {'roomId': roomId, 'userId': userId, 'isMuted': isMuted});
  }

  void muteAll(int roomId) {
    _socket.emit('mic:mute_all', {'roomId': roomId});
  }

  void loadVideo(int roomId, String youtubeId) {
    _socket.emit('video:load', {'roomId': roomId, 'youtubeId': youtubeId});
  }

  void syncVideo(int roomId, double timestamp, bool isPlaying) {
    _socket.emit('video:sync',
        {'roomId': roomId, 'timestamp': timestamp, 'isPlaying': isPlaying});
  }

  void queueVideo(int roomId, String youtubeId) {
    _socket.emit('video:queue', {'roomId': roomId, 'nextYoutubeId': youtubeId});
  }

  void updateSettings(int roomId, bool isPublic) {
    _socket.emit('room:update_settings',
        {'roomId': roomId, 'isPublic': isPublic});
  }

  void onRoomMembers(Function(List<RoomMemberModel>, int? hostId) callback) {
    _socket.on('room:members', (data) {
      try {
        final payload = MapUtils.asMap(data);
        final members = MapUtils.asMapList(payload['members'])
            .map(RoomMemberModel.fromJson)
            .toList();
        final hostId = MapUtils.handleNullableIntKey(payload, 'hostId');
        callback(members, hostId);
      } catch (e) {
        DebugLogger.error('onRoomMembers parse error', error: e);
      }
    });
  }

  void onVideoState(Function(Map<String, dynamic>) callback) {
    _socket.on('video:state', (data) {
      try {
        callback(MapUtils.asMap(data));
      } catch (e) {
        DebugLogger.error('onVideoState parse error', error: e);
      }
    });
  }

  void onChatMessage(Function(MessageModel) callback) {
    _socket.on('chat:message', (data) {
      try {
        callback(MessageModel.fromJson(MapUtils.asMap(data)));
      } catch (e) {
        DebugLogger.error('onChatMessage parse error', error: e);
      }
    });
  }

  void onMicState(Function(int userId, bool isMuted) callback) {
    _socket.on('mic:state', (data) {
      try {
        final payload = MapUtils.asMap(data);
        final userId = MapUtils.handleNullableIntKey(payload, 'userId') ?? 0;
        final isMuted =
            MapUtils.handleNullableBoolKey(payload, 'isMuted') ?? true;
        callback(userId, isMuted);
      } catch (e) {
        DebugLogger.error('onMicState parse error', error: e);
      }
    });
  }

  void onMicMutedAll(VoidCallback callback) {
    _socket.on('mic:muted_all', (_) => callback());
  }

  void onSettingsUpdated(Function(bool isPublic) callback) {
    _socket.on('room:settings_updated', (data) {
      try {
        final isPublic = MapUtils.handleNullableBoolKey(
                MapUtils.asMap(data), 'isPublic') ??
            true;
        callback(isPublic);
      } catch (e) {
        DebugLogger.error('onSettingsUpdated parse error', error: e);
      }
    });
  }

  void offRoomListeners() {
    _socket.off('room:members');
    _socket.off('video:state');
    _socket.off('chat:message');
    _socket.off('mic:state');
    _socket.off('mic:muted_all');
    _socket.off('room:settings_updated');
  }

  String _parseError(DioException e) =>
      MapUtils.handleNullableStringKey(
        MapUtils.asMap(e.response?.data),
        'message',
      ) ??
      'Something went wrong.';
}

typedef VoidCallback = void Function();
