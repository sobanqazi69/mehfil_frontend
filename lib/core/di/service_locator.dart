import 'package:get_it/get_it.dart';
import '../network/api_client.dart';
import '../network/socket_service.dart';
import '../services/secure_storage_service.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/auth/presentation/cubits/auth_cubit.dart';
import '../../features/rooms/data/repositories/room_repository.dart';
import '../../features/rooms/presentation/cubits/room_list_cubit.dart';

final sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Core services (singletons)
  sl.registerLazySingleton<SecureStorageService>(() => SecureStorageService());
  sl.registerLazySingleton<SocketService>(() => SocketService());
  sl.registerLazySingleton<ApiClient>(() => ApiClient(sl()));

  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepository(sl(), sl()),
  );
  sl.registerLazySingleton<RoomRepository>(
    () => RoomRepository(sl(), sl()),
  );

  // Cubits as singletons so go_router can access AuthCubit for auth redirect
  sl.registerLazySingleton<AuthCubit>(
    () => AuthCubit(sl(), sl(), sl()),
  );
  sl.registerLazySingleton<RoomListCubit>(
    () => RoomListCubit(sl()),
  );
}
