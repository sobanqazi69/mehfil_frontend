import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/utils/debug_logger.dart';
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
      final data = res.data as Map<String, dynamic>;
      await _storage.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return UserModel.fromJson(
          data['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      DebugLogger.error('signInWithGoogle failed', error: e);
      throw _parseError(e);
    }
  }

  Future<UserModel?> getMe() async {
    try {
      final res = await _api.get(ApiEndpoints.me);
      return UserModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      DebugLogger.error('getMe failed', error: e);
      if (e.response?.statusCode == 401) return null;
      throw _parseError(e);
    }
  }

  Future<void> signOut() async {
    await _storage.clearAll();
  }

  String _parseError(DioException e) {
    return (e.response?.data as Map?)?['message']?.toString() ??
        'Something went wrong. Please try again.';
  }
}
