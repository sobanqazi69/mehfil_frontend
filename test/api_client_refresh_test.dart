import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mehfil_frontend/core/network/api_client.dart';
import 'package:mehfil_frontend/core/services/secure_storage_service.dart';

/// In-memory stand-in so the test never touches platform secure storage.
class _FakeStorage implements SecureStorageService {
  String? access = 'expired-token';
  String? refresh = 'refresh-token';

  @override
  Future<String?> getAccessToken() async => access;
  @override
  Future<String?> getRefreshToken() async => refresh;
  @override
  Future<void> saveAccessToken(String token) async => access = token;
  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> clearAll() async {
    access = null;
    refresh = null;
  }
}

void main() {
  test('concurrent 401s trigger ONE refresh and every request recovers',
      () async {
    var refreshCalls = 0;

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      if (req.uri.path.contains('/auth/refresh')) {
        refreshCalls++;
        // Real latency so the concurrent requests genuinely overlap.
        await Future.delayed(const Duration(milliseconds: 120));
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"accessToken":"fresh-token"}');
        return req.response.close();
      }

      final auth = req.headers.value('authorization');
      if (auth == 'Bearer fresh-token') {
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"ok":true}');
      } else {
        req.response
          ..statusCode = 401
          ..headers.contentType = ContentType.json
          ..write('{"message":"Invalid or expired token"}');
      }
      return req.response.close();
    });

    final base = 'http://127.0.0.1:${server.port}';
    final storage = _FakeStorage();
    final client = ApiClient(storage, refreshUrl: '$base/api/auth/refresh');

    // Five requests firing at once — exactly the sleep/wake scenario.
    final results = await Future.wait(
      List.generate(5, (_) => client.get('$base/api/rooms')),
    );

    expect(results.every((r) => r.statusCode == 200), isTrue,
        reason: 'every queued request should recover, not just the first');
    expect(refreshCalls, 1, reason: 'refresh must be single-flight');
    expect(storage.access, 'fresh-token');

    await server.close(force: true);
  });
}
