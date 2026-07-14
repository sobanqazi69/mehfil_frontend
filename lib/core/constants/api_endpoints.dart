class ApiEndpoints {
  ApiEndpoints._();

  static const String _base = 'https://mehfil.microdesk.tech/api';
  static const String socketUrl = 'https://mehfil.microdesk.tech';

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
