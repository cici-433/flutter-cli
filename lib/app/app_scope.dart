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
import 'package:flutter_scaffold_demo/feature/home/presentation/viewmodels/home_view_model.dart';
import 'package:flutter_scaffold_demo/feature/login/presentation/viewmodels/login_view_model.dart';
import 'package:flutter_scaffold_demo/feature/mine/presentation/viewmodels/mine_view_model.dart';
import 'package:flutter_scaffold_demo/feature/order/presentation/viewmodels/order_view_model.dart';

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

  LoginViewModel createLoginViewModel() {
    return LoginViewModel(
      loginUseCase: loginUseCase,
      eventBus: eventBus,
    );
  }

  HomeViewModel createHomeViewModel() {
    return HomeViewModel(
      authSessionService: authSessionService,
      orderQueryService: orderQueryService,
      eventBus: eventBus,
    );
  }

  MineViewModel createMineViewModel() {
    return MineViewModel(
      authSessionService: authSessionService,
      logoutUseCase: logoutUseCase,
      orderQueryService: orderQueryService,
      eventBus: eventBus,
    );
  }

  OrderViewModel createOrderViewModel() {
    return OrderViewModel(
      fetchOrdersUseCase: fetchOrdersUseCase,
      createOrderUseCase: createOrderUseCase,
      eventBus: eventBus,
    );
  }
}
