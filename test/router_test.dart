import 'package:flutter/widgets.dart';
import 'package:flutter_scaffold_demo/app/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scaffold_core/scaffold_core.dart';

void main() {
  test('AppRouter buildLocation supports complex query serialization', () {
    final location = AppRouter.buildLocation(
      '/orders/:id',
      pathParameters: const <String, String>{'id': 'A-100'},
      queryParameters: <String, Object?>{
        'filter': <String, Object?>{'status': 'paid', 'page': 2},
      },
    );

    final uri = Uri.parse(location);
    expect(uri.path, '/orders/A-100');
    expect(
      CoreRouteCodec.decodeObject<Map<String, dynamic>>(
        uri.queryParameters['filter']!,
        (json) => Map<String, dynamic>.from(json! as Map<Object?, Object?>),
      ),
      <String, dynamic>{'status': 'paid', 'page': 2},
    );
  });

  test('CoreRouteRegistry matches dynamic path parameters', () {
    final registry = CoreRouteRegistry(
      routes: <CoreRouteDefinition>[
        CoreRouteDefinition(
          path: '/orders/:id',
          pageBuilder: (_, __) => const SizedBox(),
        ),
      ],
    );

    final match = registry.match('/orders/A-100?tab=detail');

    expect(match, isNotNull);
    expect(match!.state.pathParameters['id'], 'A-100');
    expect(match.state.queryParameters['tab'], 'detail');
  });

  test('GuardedCoreRouter redirects blocked route to login', () async {
    final delegate = _FakeCoreRouter();
    final registry = CoreRouteRegistry(
      routes: <CoreRouteDefinition>[
        CoreRouteDefinition(
          path: '/orders',
          pageBuilder: (_, __) => const SizedBox(),
          guards: <CoreRouteGuard>[
            CoreAuthGuard(
              isAuthenticated: () => false,
              redirectLocation: '/login',
            ),
          ],
        ),
        CoreRouteDefinition(
          path: '/login',
          pageBuilder: (_, __) => const SizedBox(),
        ),
      ],
    );
    final router = GuardedCoreRouter(
      delegate: delegate,
      routeRegistry: registry,
    );

    await router.push('/orders');

    expect(delegate.lastMode, CoreNavigationMode.go);
    expect(delegate.lastLocation, '/login');
  });

  test('GuardedCoreRouter deduplicates repeated navigation', () async {
    final delegate = _FakeCoreRouter();
    final registry = CoreRouteRegistry(
      routes: <CoreRouteDefinition>[
        CoreRouteDefinition(
          path: '/orders',
          pageBuilder: (_, __) => const SizedBox(),
          navigationPolicy: const CoreNavigationPolicy(preventDuplicate: true),
        ),
      ],
    );
    final router = GuardedCoreRouter(
      delegate: delegate,
      routeRegistry: registry,
    );

    await router.push('/orders');
    await router.push('/orders');

    expect(delegate.callCount, 1);
  });
}

class _FakeCoreRouter extends CoreRouter {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  String? lastLocation;
  CoreNavigationMode? lastMode;
  int callCount = 0;

  @override
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  @override
  bool canPop() {
    return false;
  }

  @override
  Future<T?> go<T extends Object?>(String location, {Object? extra}) async {
    lastLocation = location;
    lastMode = CoreNavigationMode.go;
    callCount += 1;
    return null;
  }

  @override
  void pop<T extends Object?>([T? result]) {}

  @override
  void popUntil(String location) {}

  @override
  Future<T?> push<T extends Object?>(String location, {Object? extra}) async {
    lastLocation = location;
    lastMode = CoreNavigationMode.push;
    callCount += 1;
    return null;
  }

  @override
  Future<T?> replace<T extends Object?>(
    String location, {
    Object? extra,
  }) async {
    lastLocation = location;
    lastMode = CoreNavigationMode.replace;
    callCount += 1;
    return null;
  }
}
