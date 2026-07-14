import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/di/service_locator.dart';
import '../../features/auth/presentation/cubits/auth_cubit.dart';
import '../../features/auth/presentation/cubits/auth_state.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/rooms/data/repositories/room_repository.dart';
import '../../features/rooms/presentation/cubits/room_cubit.dart';
import '../../features/rooms/presentation/screens/room_screen.dart';
import '../../features/rooms/presentation/screens/youtube_picker_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';

GoRouter buildAppRouter() {
  final authCubit = sl<AuthCubit>();

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _GoRouterRefreshStream(authCubit.stream),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final authState = authCubit.state;
      final isAuthenticated = authState is AuthAuthenticated;
      final isUnauthenticated = authState is AuthUnauthenticated;

      if (loc == '/splash') return null;
      if (isUnauthenticated && loc != '/sign-in') return '/sign-in';
      if (isAuthenticated && loc == '/sign-in') return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (_, __) => const SignInScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, _) => HomeScreen(
          onRoomTap: (id) => context.push('/room/$id'),
        ),
      ),
      GoRoute(
        path: '/youtube-picker',
        builder: (_, __) => const YoutubePickerScreen(),
      ),
      GoRoute(
        path: '/room/:id',
        builder: (context, state) {
          final id = int.tryParse(
                state.pathParameters['id'] ?? '') ??
              0;
          return BlocProvider(
            create: (_) => RoomCubit(sl<RoomRepository>()),
            child: RoomScreen(roomId: id),
          );
        },
      ),
    ],
  );
}

class _GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _sub;

  _GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
