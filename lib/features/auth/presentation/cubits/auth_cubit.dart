import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/network/socket_service.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repo;
  final SocketService _socket;
  final SecureStorageService _storage;

  static final _googleSignIn = GoogleSignIn(
    serverClientId:
        '973014639758-o5gk7i97r3r5uqkpgg9tleq61gkenjnv.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  AuthCubit(this._repo, this._socket, this._storage)
      : super(const AuthInitial());

  Future<void> checkAuth() async {
    try {
      if (isClosed) return;
      emit(const AuthLoading());
      final user = await _repo.getMe();
      if (isClosed) return;
      if (user != null) {
        await _connectSocket();
        emit(AuthAuthenticated(user));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      DebugLogger.error('checkAuth failed', error: e);
      if (!isClosed) emit(const AuthUnauthenticated());
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      if (isClosed) return;
      emit(const AuthLoading());

      final account = await _googleSignIn.signIn();
      if (account == null) {
        if (!isClosed) emit(const AuthUnauthenticated());
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        if (!isClosed) emit(const AuthError('Failed to get ID token'));
        return;
      }

      final user = await _repo.signInWithGoogle(idToken);
      if (isClosed) return;
      await _connectSocket();
      emit(AuthAuthenticated(user));
    } catch (e) {
      DebugLogger.error('signInWithGoogle failed', error: e);
      if (!isClosed) emit(AuthError(e.toString()));
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    try {
      if (isClosed) return;
      emit(const AuthLoading());
      final user = await _repo.signInWithEmail(email, password);
      if (isClosed) return;
      await _connectSocket();
      emit(AuthAuthenticated(user));
    } catch (e) {
      DebugLogger.error('signInWithEmail failed', error: e);
      if (!isClosed) emit(AuthError(e.toString()));
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _socket.disconnect();
      await _repo.signOut();
      if (!isClosed) emit(const AuthUnauthenticated());
    } catch (e) {
      DebugLogger.error('signOut failed', error: e);
    }
  }

  void updateUser(dynamic user) {
    if (!isClosed && state is AuthAuthenticated) {
      emit(AuthAuthenticated(user));
    }
  }

  /// Saves profile edits and syncs the result back into auth state so every
  /// screen showing the avatar/name updates at once.
  Future<void> updateProfile({
    String? name,
    String? username,
    String? bio,
  }) async {
    try {
      final user = await _repo.updateProfile(
        name: name,
        username: username,
        bio: bio,
      );
      updateUser(user);
    } catch (e) {
      DebugLogger.error('updateProfile failed', error: e);
      rethrow;
    }
  }

  Future<void> uploadAvatar(String filePath) async {
    try {
      final user = await _repo.uploadAvatar(filePath);
      updateUser(user);
    } catch (e) {
      DebugLogger.error('uploadAvatar failed', error: e);
      rethrow;
    }
  }

  Future<String?> usernameTakenReason(String username) =>
      _repo.usernameTakenReason(username);

  Future<void> _connectSocket() async {
    final token = await _storage.getAccessToken();
    if (token != null) _socket.connect(token);
  }
}
