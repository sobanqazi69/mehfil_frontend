import 'package:dio/dio.dart';
import '../constants/api_endpoints.dart';
import '../services/secure_storage_service.dart';
import '../utils/debug_logger.dart';
import '../utils/map_utils.dart';

class ApiClient {
  late final Dio _dio;
  final SecureStorageService _storage;

  ApiClient(this._storage) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(_AuthInterceptor(_dio, _storage));
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (o) => DebugLogger.log(o.toString(), tag: 'HTTP'),
    ));
  }

  Future<Response> get(String url, {Map<String, dynamic>? params}) =>
      _dio.get(url, queryParameters: params);

  Future<Response> post(String url, {dynamic data}) =>
      _dio.post(url, data: data);

  Future<Response> patch(String url, {dynamic data}) =>
      _dio.patch(url, data: data);

  Future<Response> delete(String url) => _dio.delete(url);

  Future<Response> postMultipart(
    String url, {
    required String filePath,
    required String field,
  }) async {
    final form = FormData.fromMap({
      field: await MultipartFile.fromFile(filePath),
    });
    return _dio.post(url, data: form);
  }
}

class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  final SecureStorageService _storage;
  bool _isRefreshing = false;

  _AuthInterceptor(this._dio, this._storage);

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.getAccessToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await _storage.getRefreshToken();
        if (refreshToken == null) {
          _isRefreshing = false;
          return handler.next(err);
        }
        final res = await _dio.post(
          ApiEndpoints.refreshToken,
          data: {'refreshToken': refreshToken},
        );
        final newToken = MapUtils.handleNullableStringKey(
            MapUtils.asMap(res.data), 'accessToken');
        if (newToken != null) {
          await _storage.saveAccessToken(newToken);
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          final response = await _dio.fetch(err.requestOptions);
          _isRefreshing = false;
          return handler.resolve(response);
        }
      } catch (e) {
        DebugLogger.error('Token refresh failed', error: e);
      }
      _isRefreshing = false;
    }
    handler.next(err);
  }
}
