import 'package:get_it/get_it.dart';
import 'package:singbox_flutter/singbox_flutter.dart';

import '../core/network/api_client.dart';
import '../core/storage/local_storage.dart';
import '../core/storage/secure_storage.dart';
import '../data/datasources/remote/auth_remote_datasource.dart';
import '../data/datasources/remote/user_remote_datasource.dart';
import '../data/datasources/remote/server_remote_datasource.dart';
import '../data/datasources/remote/velox_sync_datasource.dart';
import '../data/datasources/remote/order_remote_datasource.dart';
import '../data/datasources/remote/invite_remote_datasource.dart';
import '../data/datasources/remote/ticket_remote_datasource.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../data/repositories/user_repository_impl.dart';
import '../data/repositories/server_repository_impl.dart';
import '../data/repositories/order_repository_impl.dart';
import '../data/repositories/invite_repository_impl.dart';
import '../data/repositories/ticket_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/user_repository.dart';
import '../domain/repositories/server_repository.dart';
import '../domain/repositories/order_repository.dart';
import '../domain/repositories/invite_repository.dart';
import '../domain/repositories/ticket_repository.dart';
// UseCases
import '../domain/usecases/auth/login_usecase.dart';
import '../domain/usecases/auth/register_usecase.dart';
import '../domain/usecases/auth/logout_usecase.dart';
import '../domain/usecases/auth/send_verify_code_usecase.dart';
import '../domain/usecases/auth/forgot_password_usecase.dart';
import '../domain/usecases/auth/check_auth_status_usecase.dart';
import '../domain/usecases/user/get_user_info_usecase.dart';
import '../domain/usecases/user/get_subscribe_info_usecase.dart';
import '../domain/usecases/user/get_plan_list_usecase.dart';
import '../domain/usecases/server/get_server_list_usecase.dart';
import '../domain/usecases/server/get_last_server_usecase.dart';
import '../domain/usecases/server/save_last_server_usecase.dart';
import '../domain/usecases/server/ping_server_usecase.dart';
import '../domain/usecases/server/ping_all_servers_usecase.dart';
import '../domain/usecases/server/toggle_favorite_usecase.dart';
// Services
import '../core/services/auto_test_service.dart';
// BLoCs
import '../presentation/blocs/auth/auth_bloc.dart';
import '../presentation/blocs/user/user_bloc.dart';
import '../presentation/blocs/node/node_bloc.dart';
import '../presentation/blocs/vpn/vpn_bloc.dart';

final getIt = GetIt.instance;

Future<void> initDependencies() async {
  // ===== 核心服务 =====
  // 存储服务
  getIt.registerLazySingleton<SecureStorageService>(
    () => SecureStorageService(),
  );

  final localStorage = LocalStorageService();
  await localStorage.init();
  getIt.registerLazySingleton<LocalStorageService>(() => localStorage);

  // 网络客户端
  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(secureStorage: getIt<SecureStorageService>()),
  );

  // sing-box 服务
  getIt.registerLazySingleton<MihomoService>(
    () => MihomoService.instance,
  );

  // 自动测速服务（singleton：定时器需跨 NodeBloc 生命周期持续运行）
  getIt.registerLazySingleton<AutoTestService>(() => AutoTestService());

  // ===== 数据源 =====
  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<UserRemoteDataSource>(
    () => UserRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<VeloxSyncDataSource>(
    () => VeloxSyncDataSourceImpl(apiClient: getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<ServerRemoteDataSource>(
    () => ServerRemoteDataSourceImpl(
      veloxSync: getIt<VeloxSyncDataSource>(),
    ),
  );

  getIt.registerLazySingleton<OrderRemoteDataSource>(
    () => OrderRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<InviteRemoteDataSource>(
    () => InviteRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<TicketRemoteDataSource>(
    () => TicketRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );

  // ===== 仓库 =====
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: getIt<AuthRemoteDataSource>(),
      secureStorage: getIt<SecureStorageService>(),
      localStorage: getIt<LocalStorageService>(),
    ),
  );

  getIt.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(
      remoteDataSource: getIt<UserRemoteDataSource>(),
      localStorage: getIt<LocalStorageService>(),
    ),
  );

  getIt.registerLazySingleton<ServerRepository>(
    () => ServerRepositoryImpl(
      remoteDataSource: getIt<ServerRemoteDataSource>(),
      localStorage: getIt<LocalStorageService>(),
    ),
  );

  getIt.registerLazySingleton<OrderRepository>(
    () => OrderRepositoryImpl(
      remoteDataSource: getIt<OrderRemoteDataSource>(),
    ),
  );

  getIt.registerLazySingleton<InviteRepository>(
    () => InviteRepositoryImpl(
      remoteDataSource: getIt<InviteRemoteDataSource>(),
    ),
  );

  getIt.registerLazySingleton<TicketRepository>(
    () => TicketRepositoryImpl(
      remoteDataSource: getIt<TicketRemoteDataSource>(),
    ),
  );

  // ===== UseCases =====
  // Auth UseCases
  getIt.registerLazySingleton<LoginUseCase>(
    () => LoginUseCase(authRepository: getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<RegisterUseCase>(
    () => RegisterUseCase(authRepository: getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<LogoutUseCase>(
    () => LogoutUseCase(authRepository: getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<SendVerifyCodeUseCase>(
    () => SendVerifyCodeUseCase(authRepository: getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<ForgotPasswordUseCase>(
    () => ForgotPasswordUseCase(authRepository: getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<CheckAuthStatusUseCase>(
    () => CheckAuthStatusUseCase(authRepository: getIt<AuthRepository>()),
  );

  // User UseCases
  getIt.registerLazySingleton<GetUserInfoUseCase>(
    () => GetUserInfoUseCase(userRepository: getIt<UserRepository>()),
  );
  getIt.registerLazySingleton<GetSubscribeInfoUseCase>(
    () => GetSubscribeInfoUseCase(userRepository: getIt<UserRepository>()),
  );
  getIt.registerLazySingleton<GetPlanListUseCase>(
    () => GetPlanListUseCase(userRepository: getIt<UserRepository>()),
  );

  // Server UseCases
  getIt.registerLazySingleton<GetServerListUseCase>(
    () => GetServerListUseCase(serverRepository: getIt<ServerRepository>()),
  );
  getIt.registerLazySingleton<GetLastServerUseCase>(
    () => GetLastServerUseCase(serverRepository: getIt<ServerRepository>()),
  );
  getIt.registerLazySingleton<SaveLastServerUseCase>(
    () => SaveLastServerUseCase(serverRepository: getIt<ServerRepository>()),
  );
  getIt.registerLazySingleton<PingServerUseCase>(
    () => PingServerUseCase(serverRepository: getIt<ServerRepository>()),
  );
  getIt.registerLazySingleton<PingAllServersUseCase>(
    () => PingAllServersUseCase(serverRepository: getIt<ServerRepository>()),
  );
  getIt.registerLazySingleton<ToggleFavoriteUseCase>(
    () => ToggleFavoriteUseCase(serverRepository: getIt<ServerRepository>()),
  );

  // ===== BLoC =====
  getIt.registerFactory<AuthBloc>(
    () => AuthBloc(authRepository: getIt<AuthRepository>()),
  );

  getIt.registerFactory<UserBloc>(
    () => UserBloc(userRepository: getIt<UserRepository>()),
  );

  getIt.registerFactory<NodeBloc>(
    () => NodeBloc(
      serverRepository: getIt<ServerRepository>(),
      autoTestService: getIt<AutoTestService>(),
    ),
  );

  getIt.registerLazySingleton<VpnBloc>(
    () => VpnBloc(
      mihomoService: getIt<MihomoService>(),
      userRepository: getIt<UserRepository>(),
      autoTestService: getIt<AutoTestService>(),
    ),
  );
}
