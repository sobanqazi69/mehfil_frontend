import 'package:dio/dio.dart';
import '../constants/api_endpoints.dart';
import '../services/secure_storage_service.dart';
import '../utils/debug_logger.dart';
import '../utils/map_utils.dart';

class ApiClient {
  late final Dio _dio;
  final SecureStorageService _storage;

  /// [refreshUrl] is injectable so the refresh/retry flow can be tested
  /// against a local server; production uses the real endpoint.
  ApiClient(this._storage, {String? refreshUrl}) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(_AuthInterceptor(
      _dio,
      _storage,
      refreshUrl ?? ApiEndpoints.refreshToken,
    ));
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

/// Attaches the access token and transparently recovers from expiry.
///
/// The tricky case is waking from sleep: the token has expired and several
/// requests fire at once, so every one of them 401s together. They must all
/// wait on a SINGLE refresh and then retry — refreshing per-request would
/// stampede the server, and letting the losers fail is what used to surface a
/// spurious "Something went wrong" on resume.
class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  final SecureStorageService _storage;
  final String _refreshUrl;

  /// Bare client for the refresh call itself: no interceptors, so a failing
  /// refresh can never recurse back into this handler.
  final Dio _refreshDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  /// Non-null while a refresh is in flight; every concurrent 401 awaits it.
  Future<String?>? _refreshInFlight;

  _AuthInterceptor(this._dio, this._storage, this._refreshUrl);

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.getAccessToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_shouldTryRefresh(err)) return handler.next(err);

    try {
      // Another request may have already refreshed while this one was failing.
      // If the stored token is newer than the one we sent, just reuse it.
      final sent = err.requestOptions.headers['Authorization'];
      final stored = await _storage.getAccessToken();
      final alreadyRefreshed =
          stored != null && sent != null && 'Bearer $stored' != sent;

      final token = alreadyRefreshed ? stored : await _refresh();
      if (token == null) return handler.next(err);

      return handler.resolve(await _retry(err.requestOptions, token));
    } catch (e) {
      DebugLogger.error('Retry after refresh failed', error: e);
      return handler.next(err);
    }
  }

  bool _shouldTryRefresh(DioException err) {
    if (err.response?.statusCode != 401) return false;
    // A 401 from the auth routes means the credentials themselves are bad —
    // refreshing would just loop.
    if (err.requestOptions.path.contains('/auth/')) return false;
    // Only ever retry a given request once.
    if (err.requestOptions.extra['__didRetry'] == true) return false;
    return true;
  }

  /// Single-flight refresh: the first caller starts it, the rest join it.
  Future<String?> _refresh() {
    return _refreshInFlight ??=
        _performRefresh().whenComplete(() => _refreshInFlight = null);
  }

  Future<String?> _performRefresh() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) return null;

      final res = await _refreshDio.post(
        _refreshUrl,
        data: {'refreshToken': refreshToken},
      );
      final newToken = MapUtils.handleNullableStringKey(
          MapUtils.asMap(res.data), 'accessToken');

      if (newToken != null) await _storage.saveAccessToken(newToken);
      return newToken;
    } catch (e) {
      DebugLogger.error('Token refresh failed', error: e);
      return null;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions options, String token) {
    options.headers['Authorization'] = 'Bearer $token';
    options.extra['__didRetry'] = true;
    return _dio.fetch(options);
  }
}
