import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/socket_service.dart';
import '../../../../core/utils/debug_logger.dart';
import '../models/message_model.dart';
import '../models/room_member_model.dart';
import '../models/room_model.dart';

class RoomRepository {
  final ApiClient _api;
  final SocketService _socket;

  RoomRepository(this._api, this._socket);

  // ── REST ────────────────────────────────────────────────────────────

  Future<List<RoomModel>> browseRooms({
    int page = 1,
    String? category,
  }) async {
    try {
      final res = await _api.get(ApiEndpoints.rooms, params: {
        'page': page,
        if (category != null && category != 'All') 'category': category,
      });
      final list = (res.data['rooms'] as List?) ?? [];
      return list
          .map((e) => RoomModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      DebugLogger.error('browseRooms failed', error: e);
      throw _parseError(e);
    }
  }

  Future<List<RoomModel>> getMyRooms() async {
    try {
      final res = await _api.get(ApiEndpoints.myRooms);
      final list = (res.data as List?) ?? [];
      return list
          .map((e) => RoomModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      DebugLogger.error('getMyRooms failed', error: e);
      throw _parseError(e);
    }
  }

  Future<RoomModel> createRoom({
    required String name,
    bool isPublic = true,
    String? category,
  }) async {
    try {
      final res = await _api.post(ApiEndpoints.rooms, data: {
        'name': name,
        'isPublic': isPublic,
        if (category != null) 'category': category,
      });
      return RoomModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      DebugLogger.error('createRoom failed', error: e);
      throw _parseError(e);
    }
  }

  Future<RoomModel> getRoom(int id) async {
    try {
      final res = await _api.get(ApiEndpoints.room(id));
      return RoomModel.fromJson(res.data as Map<String, dynamic>);
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
      final list = (res.data as List?) ?? [];
      return list
          .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      DebugLogger.error('getRoomMessages failed', error: e);
      throw _parseError(e);
    }
  }

  Future<Map<String, dynamic>> getVoiceToken(int roomId) async {
    try {
      final res = await _api.post(ApiEndpoints.voiceToken,
          data: {'roomId': roomId});
      return res.data as Map<String, dynamic>;
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

  void onRoomMembers(Function(List<RoomMemberModel>) callback) {
    _socket.on('room:members', (data) {
      try {
        final members = (data['members'] as List?)
                ?.map((e) => RoomMemberModel.fromJson(
                    e as Map<String, dynamic>))
                .toList() ??
            [];
        callback(members);
      } catch (e) {
        DebugLogger.error('onRoomMembers parse error', error: e);
      }
    });
  }

  void onVideoState(Function(Map<String, dynamic>) callback) {
    _socket.on('video:state', (data) {
      try {
        callback(data as Map<String, dynamic>);
      } catch (e) {
        DebugLogger.error('onVideoState parse error', error: e);
      }
    });
  }

  void onChatMessage(Function(MessageModel) callback) {
    _socket.on('chat:message', (data) {
      try {
        callback(MessageModel.fromJson(data as Map<String, dynamic>));
      } catch (e) {
        DebugLogger.error('onChatMessage parse error', error: e);
      }
    });
  }

  void onMicState(Function(int userId, bool isMuted) callback) {
    _socket.on('mic:state', (data) {
      try {
        final userId = (data['userId'] as num?)?.toInt() ?? 0;
        final isMuted = data['isMuted'] as bool? ?? true;
        callback(userId, isMuted);
      } catch (e) {
        DebugLogger.error('onMicState parse error', error: e);
      }
    });
  }

  void onMicMutedAll(VoidCallback callback) {
    _socket.on('mic:muted_all', (_) => callback());
  }

  void offRoomListeners() {
    _socket.off('room:members');
    _socket.off('video:state');
    _socket.off('chat:message');
    _socket.off('mic:state');
    _socket.off('mic:muted_all');
  }

  String _parseError(DioException e) =>
      (e.response?.data as Map?)?['message']?.toString() ??
      'Something went wrong.';
}

typedef VoidCallback = void Function();
