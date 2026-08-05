import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/api_endpoints.dart';
import '../services/secure_storage_service.dart';
import '../utils/debug_logger.dart';

class SocketService {
  static final SocketService _instance = SocketService._();
  factory SocketService() => _instance;
  SocketService._();

  io.Socket? _socket;
  bool get isConnected => _socket?.connected ?? false;

  /// Set once at connect so every later reconnect can mint a fresh token.
  SecureStorageService? _storage;

  /// Fired after every successful (re)connect.
  ///
  /// A reconnect always carries a NEW socket id, and anything the server keyed
  /// to the old one — socket.io room membership above all — is gone. Features
  /// register here to re-announce themselves instead of going quietly deaf.
  final List<void Function()> _connectHandlers = [];

  void addConnectHandler(void Function() handler) {
    if (!_connectHandlers.contains(handler)) _connectHandlers.add(handler);
  }

  void removeConnectHandler(void Function() handler) =>
      _connectHandlers.remove(handler);

  void connect(String accessToken, {SecureStorageService? storage}) {
    if (isConnected) return;
    _storage = storage ?? _storage;

    _socket = io.io(
      ApiEndpoints.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          // Auth is resolved lazily on EVERY (re)connect rather than frozen at
          // connect time. Access tokens live an hour; a phone that sat in a
          // pocket longer than that would otherwise reconnect with a stale
          // token forever and silently never rejoin.
          .setAuthFn((callback) async {
            try {
              final token = await _storage?.getAccessToken();
              callback({'token': token ?? accessToken});
            } catch (e) {
              DebugLogger.error('socket auth fn failed', error: e);
              callback({'token': accessToken});
            }
          })
          .enableAutoConnect()
          .enableReconnection()
          // Was 5 attempts: after ~15s of background the client gave up for
          // good and never came back when the app returned. Keep trying, with
          // an exponential delay capped so we are not hammering the server.
          .setReconnectionAttempts(double.infinity)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(10000)
          .build(),
    );

    _socket!.onConnect((_) {
      DebugLogger.socket('connected');
      // Copy first: a handler may deregister itself while we iterate.
      for (final handler in List.of(_connectHandlers)) {
        try {
          handler();
        } catch (e) {
          DebugLogger.error('socket connect handler failed', error: e);
        }
      }
    });
    _socket!.onDisconnect((_) => DebugLogger.socket('disconnected'));
    _socket!.onConnectError(
        (e) => DebugLogger.error('Socket connect error', error: e));
    _socket!.onReconnect((_) => DebugLogger.socket('reconnected'));
  }

  /// Nudge the socket after the app returns to the foreground.
  ///
  /// Android tears down sockets for backgrounded apps without always telling
  /// the client, so the socket can believe it is healthy while the OS has
  /// already dropped it. Calling this on resume forces the issue instead of
  /// waiting for the next failed emit.
  void ensureConnected() {
    try {
      final socket = _socket;
      if (socket == null) return;
      if (!socket.connected) {
        DebugLogger.socket('resume → reconnecting');
        socket.connect();
      }
    } catch (e) {
      DebugLogger.error('socket ensureConnected failed', error: e);
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void emit(String event, [dynamic data]) {
    if (!isConnected) return;
    DebugLogger.socket('emit $event', data);
    _socket!.emit(event, data);
  }

  void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void off(String event, [Function(dynamic)? handler]) {
    if (handler != null) {
      _socket?.off(event, handler);
    } else {
      _socket?.off(event);
    }
  }

  void onAny(Function(String, dynamic) handler) {
    _socket?.onAny(handler);
  }
}
