import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scaffold_core/core_common/module_event_bus.dart';
import 'package:scaffold_core/core_logger/logger.dart';
import 'package:scaffold_core/core_router/core_router.dart';
import 'package:scaffold_core/core_router/navigator_core_router.dart';
import 'package:scaffold_core/core_storage/storage.dart';
import 'package:flutter_scaffold_demo/data/auth/in_memory_auth_session_service.dart';
import 'package:flutter_scaffold_demo/app/core/network.dart';
import 'package:flutter_scaffold_demo/data/auth/login_local_data_source.dart';
import 'package:flutter_scaffold_demo/data/auth/login_remote_data_source.dart';
import 'package:flutter_scaffold_demo/data/auth/login_repository_impl.dart';
import 'package:flutter_scaffold_demo/data/order/order_local_data_source.dart';
import 'package:flutter_scaffold_demo/data/order/order_query_service_impl.dart';
import 'package:flutter_scaffold_demo/data/order/order_remote_data_source.dart';
import 'package:flutter_scaffold_demo/data/order/order_repository_impl.dart';
import 'package:flutter_scaffold_demo/domain/auth/auth_session_service.dart';
import 'package:flutter_scaffold_demo/domain/auth/logout_use_case.dart';
import 'package:flutter_scaffold_demo/domain/auth/login_use_case.dart';
import 'package:flutter_scaffold_demo/domain/order/create_order_use_case.dart';
import 'package:flutter_scaffold_demo/domain/order/fetch_orders_use_case.dart';
import 'package:flutter_scaffold_demo/domain/order/order_query_service.dart';

class AppScope {
  AppScope({
    required this.logger,
    required this.eventBus,
    required this.router,
    required this.storage,
    required this.authSessionService,
    required this.orderQueryService,
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.fetchOrdersUseCase,
    required this.createOrderUseCase,
  });

  final AppLogger logger;
  final ModuleEventBus eventBus;
  final CoreRouter router;
  final CoreStorage storage;
  final AuthSessionService authSessionService;
  final OrderQueryService orderQueryService;
  final LoginUseCase loginUseCase;
  final LogoutUseCase logoutUseCase;
  final FetchOrdersUseCase fetchOrdersUseCase;
  final CreateOrderUseCase createOrderUseCase;

  static Future<AppScope> create() async {
    final logger = AppLogger(
      minLevel: LogLevel.debug,
      formatter: const LineLogFormatter(includeStackTrace: false),
    );
    final eventBus = ModuleEventBus();
    final router = NavigatorCoreRouter();
    final storage = CoreStorage();
    await storage.initialize();
    final authSessionService = InMemoryAuthSessionService();
    final networkClient = AppNetwork(auth: authSessionService).client;
    final loginRemoteDataSource = LoginRemoteDataSource(networkClient);
    final loginLocalDataSource = LoginLocalDataSource(storage);
    final loginRepository = LoginRepositoryImpl(
      remoteDataSource: loginRemoteDataSource,
      localDataSource: loginLocalDataSource,
    );
    final loginUseCase = LoginUseCase(loginRepository, authSessionService);
    final logoutUseCase = LogoutUseCase(authSessionService);
    final orderRemoteDataSource = OrderRemoteDataSource(networkClient);
    final orderLocalDataSource = OrderLocalDataSource();
    final orderRepository = OrderRepositoryImpl(
      remoteDataSource: orderRemoteDataSource,
      localDataSource: orderLocalDataSource,
    );
    final fetchOrdersUseCase = FetchOrdersUseCase(orderRepository);
    final createOrderUseCase = CreateOrderUseCase(orderRepository);
    final orderQueryService = OrderQueryServiceImpl(fetchOrdersUseCase);
    final scope = AppScope(
      logger: logger,
      eventBus: eventBus,
      router: router,
      storage: storage,
      authSessionService: authSessionService,
      orderQueryService: orderQueryService,
      loginUseCase: loginUseCase,
      logoutUseCase: logoutUseCase,
      fetchOrdersUseCase: fetchOrdersUseCase,
      createOrderUseCase: createOrderUseCase,
    );
    scope.logger.info('app_scope initialized', tag: 'app');
    return scope;
  }
}

final appScopeProvider = Provider<AppScope>(
  (ref) => throw UnimplementedError(),
);

final appLoggerProvider = Provider<AppLogger>((ref) {
  return ref.watch(appScopeProvider).logger;
});

final eventBusProvider = Provider<ModuleEventBus>((ref) {
  return ref.watch(appScopeProvider).eventBus;
});

final routerProvider = Provider<CoreRouter>((ref) {
  return ref.watch(appScopeProvider).router;
});

final storageProvider = Provider<CoreStorage>((ref) {
  return ref.watch(appScopeProvider).storage;
});

final authSessionServiceProvider = Provider<AuthSessionService>((ref) {
  return ref.watch(appScopeProvider).authSessionService;
});

final orderQueryServiceProvider = Provider<OrderQueryService>((ref) {
  return ref.watch(appScopeProvider).orderQueryService;
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return ref.watch(appScopeProvider).loginUseCase;
});

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  return ref.watch(appScopeProvider).logoutUseCase;
});

final fetchOrdersUseCaseProvider = Provider<FetchOrdersUseCase>((ref) {
  return ref.watch(appScopeProvider).fetchOrdersUseCase;
});

final createOrderUseCaseProvider = Provider<CreateOrderUseCase>((ref) {
  return ref.watch(appScopeProvider).createOrderUseCase;
});
