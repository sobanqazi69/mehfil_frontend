import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../../../core/utils/map_utils.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient _api;
  final SecureStorageService _storage;

  AuthRepository(this._api, this._storage);

  Future<UserModel> signInWithGoogle(String idToken) async {
    try {
      final res = await _api.post(
        ApiEndpoints.googleAuth,
        data: {'idToken': idToken},
      );
      final data = MapUtils.asMap(res.data);
      final accessToken = MapUtils.handleNullableStringKey(data, 'accessToken');
      final refreshToken =
          MapUtils.handleNullableStringKey(data, 'refreshToken');
      if (accessToken == null || refreshToken == null) {
        throw 'Sign-in failed. Please try again.';
      }
      await _storage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      return UserModel.fromJson(
          MapUtils.handleNullableMapKey(data, 'user') ?? const {});
    } on DioException catch (e) {
      DebugLogger.error('signInWithGoogle failed', error: e);
      throw _parseError(e);
    }
  }

  Future<UserModel?> getMe() async {
    try {
      if (await _storage.getAccessToken() == null) return null;
      final res = await _api.get(ApiEndpoints.me);
      return UserModel.fromJson(MapUtils.asMap(res.data));
    } on DioException catch (e) {
      DebugLogger.error('getMe failed', error: e);
      if (e.response?.statusCode == 401) return null;
      throw _parseError(e);
    }
  }

  Future<UserModel> updateProfile({
    String? name,
    String? username,
    String? bio,
  }) async {
    try {
      final res = await _api.patch(ApiEndpoints.me, data: {
        if (name != null) 'name': name,
        if (username != null) 'username': username,
        if (bio != null) 'bio': bio,
      });
      return UserModel.fromJson(MapUtils.asMap(res.data));
    } on DioException catch (e) {
      DebugLogger.error('updateProfile failed', error: e);
      throw _parseError(e);
    }
  }

  Future<UserModel> uploadAvatar(String filePath) async {
    try {
      final res = await _api.postMultipart(
        ApiEndpoints.avatarUpload,
        filePath: filePath,
        field: 'avatar',
      );
      return UserModel.fromJson(MapUtils.asMap(res.data));
    } on DioException catch (e) {
      DebugLogger.error('uploadAvatar failed', error: e);
      throw _parseError(e);
    }
  }

  /// Returns null when available, otherwise the reason it is not.
  Future<String?> usernameTakenReason(String username) async {
    try {
      final res = await _api.get(
        ApiEndpoints.usernameAvailable,
        params: {'username': username},
      );
      final data = MapUtils.asMap(res.data);
      final available =
          MapUtils.handleNullableBoolKey(data, 'available') ?? false;
      return available ? null : 'That username is already taken';
    } on DioException catch (e) {
      // 400 carries the format rule; anything else is a real failure.
      final data = MapUtils.asMap(e.response?.data);
      return MapUtils.handleNullableStringKey(data, 'message') ??
          'Could not check that username';
    }
  }

  Future<void> signOut() async {
    await _storage.clearAll();
  }

  String _parseError(DioException e) {
    return MapUtils.handleNullableStringKey(
          MapUtils.asMap(e.response?.data),
          'message',
        ) ??
        'Something went wrong. Please try again.';
  }
}
