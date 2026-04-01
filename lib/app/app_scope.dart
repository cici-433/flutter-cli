import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scaffold_core/core_common/module_event_bus.dart';
import 'package:scaffold_core/core_logger/logger.dart';
import 'package:scaffold_core/core_router/core_deep_link.dart';
import 'package:scaffold_core/core_router/core_route_registry.dart';
import 'package:scaffold_core/core_router/core_router.dart';
import 'package:scaffold_core/core_router/guarded_core_router.dart';
import 'package:scaffold_core/core_router/navigator_core_router.dart';
import 'package:scaffold_core/core_storage/storage.dart';
import 'package:flutter_scaffold_demo/app/router/app_router.dart';
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
import 'package:url_launcher/url_launcher.dart';

/// 应用级依赖容器。
///
/// 该对象负责集中初始化跨模块基础设施，包括日志、路由、深链、存储、
/// 鉴权会话以及业务用例等。
class AppScope {
  AppScope({
    required this.logger,
    required this.eventBus,
    required this.router,
    required this.routeRegistry,
    required this.deepLinkCoordinator,
    required this.storage,
    required this.authSessionService,
    required this.orderQueryService,
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.fetchOrdersUseCase,
    required this.createOrderUseCase,
  });

  /// 全局日志实例。
  final AppLogger logger;

  /// 模块事件总线。
  final ModuleEventBus eventBus;

  /// 统一路由实例。
  final CoreRouter router;

  /// 中心化路由注册表。
  final CoreRouteRegistry routeRegistry;

  /// 深链协调器。
  final CoreDeepLinkCoordinator deepLinkCoordinator;

  /// 本地存储能力。
  final CoreStorage storage;

  /// 当前应用的登录态服务。
  final AuthSessionService authSessionService;

  /// 订单查询能力。
  final OrderQueryService orderQueryService;

  /// 登录用例。
  final LoginUseCase loginUseCase;

  /// 退出登录用例。
  final LogoutUseCase logoutUseCase;

  /// 获取订单列表用例。
  final FetchOrdersUseCase fetchOrdersUseCase;

  /// 创建订单用例。
  final CreateOrderUseCase createOrderUseCase;

  /// 初始化完整的应用作用域。
  ///
  /// 其中路由部分会完成：
  /// - 路由注册中心构建
  /// - 守卫型路由包装器组装
  /// - 深链来源、H5 兜底与外部唤起策略接入
  static Future<AppScope> create() async {
    final logger = AppLogger(
      minLevel: LogLevel.debug,
      formatter: const LineLogFormatter(includeStackTrace: false),
    );
    final eventBus = ModuleEventBus();
    final storage = CoreStorage();
    await storage.initialize();
    final authSessionService = InMemoryAuthSessionService();
    final routeRegistry = AppRouter.buildRegistry(authSessionService);
    final router = GuardedCoreRouter(
      delegate: NavigatorCoreRouter(),
      routeRegistry: routeRegistry,
    );
    // 深链优先尝试站内路由；若未命中，则回退到同 host 的 H5 页面。
    final deepLinkCoordinator = CoreDeepLinkCoordinator(
      router: router,
      source: UniLinksDeepLinkSource(),
      fallbackUriBuilder: (Uri uri) {
        if (uri.host.isEmpty) {
          return null;
        }
        return Uri(
          scheme: 'https',
          host: uri.host,
          path: uri.path,
          queryParameters: uri.queryParameters.isEmpty
              ? null
              : uri.queryParameters,
          fragment: uri.fragment.isEmpty ? null : uri.fragment,
        );
      },
      onUnhandledUri: (Uri originalUri, Uri? fallbackUri) async {
        if (fallbackUri == null) {
          logger.warning(
            'deep_link_unhandled_without_fallback',
            tag: 'router',
            error: originalUri.toString(),
          );
          return;
        }

        final launched = await launchUrl(
          fallbackUri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          logger.warning(
            'deep_link_fallback_launch_failed',
            tag: 'router',
            error: fallbackUri.toString(),
          );
        }
      },
    );
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
      routeRegistry: routeRegistry,
      deepLinkCoordinator: deepLinkCoordinator,
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

/// 应用级依赖容器 provider。
final appScopeProvider = Provider<AppScope>(
  (ref) => throw UnimplementedError(),
);

/// 日志 provider。
final appLoggerProvider = Provider<AppLogger>((ref) {
  return ref.watch(appScopeProvider).logger;
});

/// 事件总线 provider。
final eventBusProvider = Provider<ModuleEventBus>((ref) {
  return ref.watch(appScopeProvider).eventBus;
});

/// 路由 provider。
final routerProvider = Provider<CoreRouter>((ref) {
  return ref.watch(appScopeProvider).router;
});

/// 存储 provider。
final storageProvider = Provider<CoreStorage>((ref) {
  return ref.watch(appScopeProvider).storage;
});

/// 登录态服务 provider。
final authSessionServiceProvider = Provider<AuthSessionService>((ref) {
  return ref.watch(appScopeProvider).authSessionService;
});

/// 订单查询服务 provider。
final orderQueryServiceProvider = Provider<OrderQueryService>((ref) {
  return ref.watch(appScopeProvider).orderQueryService;
});

/// 登录用例 provider。
final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return ref.watch(appScopeProvider).loginUseCase;
});

/// 退出登录用例 provider。
final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  return ref.watch(appScopeProvider).logoutUseCase;
});

/// 获取订单用例 provider。
final fetchOrdersUseCaseProvider = Provider<FetchOrdersUseCase>((ref) {
  return ref.watch(appScopeProvider).fetchOrdersUseCase;
});

/// 创建订单用例 provider。
final createOrderUseCaseProvider = Provider<CreateOrderUseCase>((ref) {
  return ref.watch(appScopeProvider).createOrderUseCase;
});
