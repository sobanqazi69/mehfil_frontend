import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'config/routes/app_router.dart';
import 'config/theme/app_theme.dart';
import 'core/di/service_locator.dart';
import 'features/auth/presentation/cubits/auth_cubit.dart';
import 'features/rooms/presentation/cubits/room_list_cubit.dart';

class MehfilApp extends StatefulWidget {
  const MehfilApp({super.key});

  @override
  State<MehfilApp> createState() => _MehfilAppState();
}

class _MehfilAppState extends State<MehfilApp> {
  late final _router = buildAppRouter();

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<AuthCubit>()),
        BlocProvider.value(value: sl<RoomListCubit>()),
      ],
      child: MaterialApp.router(
        title: 'Mehfil',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
