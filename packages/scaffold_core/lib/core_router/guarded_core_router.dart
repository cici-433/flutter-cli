import 'package:flutter/widgets.dart';

import 'core_route_definition.dart';
import 'core_route_guard.dart';
import 'core_route_registry.dart';
import 'core_router.dart';

/// 带守卫、节流、去重和深链分发能力的路由包装器。
///
/// 该类本身不绑定具体路由库，而是包装任意 [CoreRouter] 实现：
/// - 导航前执行全局守卫和路由级守卫
/// - 根据 [CoreNavigationPolicy] 控制防重入
/// - 提供基于 URI 的深链处理入口
class GuardedCoreRouter extends CoreRouter {
  GuardedCoreRouter({
    required CoreRouter delegate,
    required CoreRouteRegistry routeRegistry,
    this.globalGuards = const <CoreRouteGuard>[],
  }) : _delegate = delegate,
       _routeRegistry = routeRegistry;

  /// 真正负责执行导航的底层路由实现。
  final CoreRouter _delegate;

  /// 路由注册中心，用于匹配路由和获取策略。
  final CoreRouteRegistry _routeRegistry;

  /// 所有路由共享的全局守卫。
  final List<CoreRouteGuard> globalGuards;

  /// 每个去重 key 最近一次触发时间。
  final Map<String, DateTime> _lastTriggeredAt = <String, DateTime>{};

  /// 当前正在执行中的去重 key 集合。
  final Set<String> _inFlightKeys = <String>{};

  /// 最近一次成功完成导航的去重 key。
  String? _lastCompletedKey;

  @override
  GlobalKey<NavigatorState> get navigatorKey => _delegate.navigatorKey;

  @override
  Future<T?> push<T extends Object?>(String location, {Object? extra}) {
    return _navigate<T>(
      location: location,
      extra: extra,
      mode: CoreNavigationMode.push,
    );
  }

  @override
  Future<T?> replace<T extends Object?>(String location, {Object? extra}) {
    return _navigate<T>(
      location: location,
      extra: extra,
      mode: CoreNavigationMode.replace,
    );
  }

  @override
  Future<T?> go<T extends Object?>(String location, {Object? extra}) {
    return _navigate<T>(
      location: location,
      extra: extra,
      mode: CoreNavigationMode.go,
    );
  }

  @override
  bool canPop() {
    return _delegate.canPop();
  }

  @override
  void pop<T extends Object?>([T? result]) {
    _delegate.pop<T>(result);
  }

  @override
  void popUntil(String location) {
    _delegate.popUntil(_routeRegistry.normalizeLocation(location));
  }

  /// 处理来自深链、推送消息或外部唤起的 URI。
  ///
  /// 返回值表示该 URI 是否命中了已注册路由。
  Future<bool> handleUri(
    Uri uri, {
    Object? extra,
    CoreNavigationMode mode = CoreNavigationMode.go,
  }) async {
    final location = _routeRegistry.normalizeUri(uri);
    final match = _routeRegistry.match(location, extra: extra);
    if (match == null) {
      return false;
    }
    await _navigate<void>(location: location, extra: extra, mode: mode);
    return true;
  }

  /// 统一导航入口，负责标准化、策略校验、守卫执行和最终分发。
  Future<T?> _navigate<T extends Object?>({
    required String location,
    required Object? extra,
    required CoreNavigationMode mode,
    int depth = 0,
  }) async {
    final normalizedLocation = _routeRegistry.normalizeLocation(location);
    final match = _routeRegistry.match(normalizedLocation, extra: extra);
    final policy =
        match?.definition.navigationPolicy ?? const CoreNavigationPolicy();
    final dedupeKey = (policy.dedupeKeyBuilder ?? _defaultDedupeKeyBuilder)(
      normalizedLocation,
      extra,
    );

    if (!_canNavigateWithPolicy(policy, dedupeKey)) {
      return null;
    }

    if (policy.singleFlight) {
      _inFlightKeys.add(dedupeKey);
    }
    _lastTriggeredAt[dedupeKey] = DateTime.now();

    try {
      if (match != null) {
        final guardResult = await _runGuards(
          match: match,
          location: normalizedLocation,
          extra: extra,
          mode: mode,
        );
        if (!guardResult.isAllowed) {
          final redirectLocation = guardResult.redirectLocation;
          if (redirectLocation == null || depth >= 3) {
            return null;
          }
          return _navigate<T>(
            location: redirectLocation,
            extra: guardResult.redirectExtra,
            mode: guardResult.redirectMode ?? CoreNavigationMode.go,
            depth: depth + 1,
          );
        }
      }

      final result = await _dispatch<T>(
        location: normalizedLocation,
        extra: extra,
        mode: mode,
      );
      _lastCompletedKey = dedupeKey;
      return result;
    } finally {
      _inFlightKeys.remove(dedupeKey);
    }
  }

  /// 根据 [CoreNavigationPolicy] 判断当前导航是否允许继续。
  bool _canNavigateWithPolicy(CoreNavigationPolicy policy, String dedupeKey) {
    if (policy.singleFlight && _inFlightKeys.contains(dedupeKey)) {
      return false;
    }

    final lastTriggeredAt = _lastTriggeredAt[dedupeKey];
    final throttleDuration = policy.throttleDuration;
    if (throttleDuration != null &&
        lastTriggeredAt != null &&
        DateTime.now().difference(lastTriggeredAt) < throttleDuration) {
      return false;
    }

    if (policy.preventDuplicate && _lastCompletedKey == dedupeKey) {
      return false;
    }

    return true;
  }

  /// 依次执行全局守卫和路由守卫。
  Future<CoreRouteGuardResult> _runGuards({
    required CoreRouteMatch match,
    required String location,
    required Object? extra,
    required CoreNavigationMode mode,
  }) async {
    final guards = <CoreRouteGuard>[
      ...globalGuards,
      ...match.definition.guards,
    ];
    for (final guard in guards) {
      final result = await guard.canNavigate(
        CoreRouteGuardContext(
          location: location,
          pattern: match.definition.path,
          mode: mode,
          state: match.state,
          metadata: match.definition.metadata,
          extra: extra,
        ),
      );
      if (!result.isAllowed) {
        return result;
      }
    }
    return const CoreRouteGuardResult.allow();
  }

  /// 将统一导航模式分发到底层路由实现。
  Future<T?> _dispatch<T extends Object?>({
    required String location,
    required Object? extra,
    required CoreNavigationMode mode,
  }) {
    switch (mode) {
      case CoreNavigationMode.push:
        return _delegate.push<T>(location, extra: extra);
      case CoreNavigationMode.replace:
        return _delegate.replace<T>(location, extra: extra);
      case CoreNavigationMode.go:
        return _delegate.go<T>(location, extra: extra);
    }
  }

  /// 默认的导航去重 key 生成逻辑。
  static String _defaultDedupeKeyBuilder(String location, Object? extra) {
    return '$location::${extra.runtimeType}::${extra.hashCode}';
  }
}
