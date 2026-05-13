import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/api_endpoints.dart';
import '../utils/debug_logger.dart';

class SocketService {
  static final SocketService _instance = SocketService._();
  factory SocketService() => _instance;
  SocketService._();

  io.Socket? _socket;
  bool get isConnected => _socket?.connected ?? false;

  void connect(String accessToken) {
    if (isConnected) return;
    _socket = io.io(
      ApiEndpoints.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': accessToken})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(1000)
          .build(),
    );

    _socket!.onConnect((_) => DebugLogger.socket('connected'));
    _socket!.onDisconnect((_) => DebugLogger.socket('disconnected'));
    _socket!.onConnectError((e) => DebugLogger.error('Socket connect error', error: e));
    _socket!.onReconnect((_) => DebugLogger.socket('reconnected'));
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
