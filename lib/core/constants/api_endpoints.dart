class ApiEndpoints {
  ApiEndpoints._();

  static const String _base = 'https://mehfil.microdesk.tech/api';
  static const String socketUrl = 'https://mehfil.microdesk.tech';

  // Voice runs on the shared LiveKit server (nginx-fronted, TLS). Rooms are
  // namespaced `mehfil_room_<id>` server-side so they never collide with other
  // apps on the same LiveKit instance.
  static const String livekitUrl = 'wss://livekit.bazmivoicechat.tech';

  // Auth
  static const String googleAuth  = '$_base/auth/google';
  static const String refreshToken = '$_base/auth/refresh';

  // Users
  static const String me = '$_base/users/me';
  static const String avatarUpload = '$_base/users/me/avatar';
  static const String usernameAvailable = '$_base/users/username-available';

  // Rooms
  static const String rooms    = '$_base/rooms';
  static const String myRooms  = '$_base/rooms/my';
  static String room(int id)        => '$_base/rooms/$id';
  static String roomMessages(int id) => '$_base/rooms/$id/messages';

  // Voice
  static const String voiceToken = '$_base/voice/token';
}
