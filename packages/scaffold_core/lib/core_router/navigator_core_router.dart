import 'package:flutter/widgets.dart';

import 'core_router.dart';

/// 基于 Flutter 原生 Navigator 1.0 的默认路由实现（应用无关）
///
/// 适用场景：
/// - 使用 MaterialApp/CupertinoApp 的 `routes/onGenerateRoute` 体系
/// - 以 `pushNamed` / `pushReplacementNamed` / `pushNamedAndRemoveUntil` 完成跳转
///
/// 行为约定：
/// - [push] -> `NavigatorState.pushNamed`
/// - [replace] -> `NavigatorState.pushReplacementNamed`
/// - [go] -> `NavigatorState.pushNamedAndRemoveUntil` 并清空栈
/// - [extra] 会映射到 `RouteSettings.arguments`
/// - 当 `navigatorKey.currentState` 为空时返回一个已完成的 Future，避免抛异常
class NavigatorCoreRouter extends CoreRouter {
  NavigatorCoreRouter({
    GlobalKey<NavigatorState>? navigatorKey,
    bool Function(Route<dynamic> route)? popUntilPredicate,
  })  : _navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>(),
        _popUntilPredicate = popUntilPredicate;

  final GlobalKey<NavigatorState> _navigatorKey;
  final bool Function(Route<dynamic> route)? _popUntilPredicate;

  @override
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  @override
  Future<T?> push<T extends Object?>(
    String location, {
    Object? extra,
  }) {
    final state = _navigatorKey.currentState;
    if (state == null) return Future<T?>.value(null);
    return state.pushNamed<T>(location, arguments: extra);
  }

  @override
  Future<T?> replace<T extends Object?>(
    String location, {
    Object? extra,
  }) {
    final state = _navigatorKey.currentState;
    if (state == null) return Future<T?>.value(null);
    return state.pushReplacementNamed<T, T>(location, arguments: extra);
  }

  @override
  Future<T?> go<T extends Object?>(
    String location, {
    Object? extra,
  }) {
    final state = _navigatorKey.currentState;
    if (state == null) return Future<T?>.value(null);
    return state.pushNamedAndRemoveUntil<T>(
      location,
      (route) => false,
      arguments: extra,
    );
  }

  @override
  bool canPop() {
    return _navigatorKey.currentState?.canPop() ?? false;
  }

  @override
  void pop<T extends Object?>([T? result]) {
    _navigatorKey.currentState?.pop<T>(result);
  }

  @override
  void popUntil(String location) {
    final state = _navigatorKey.currentState;
    if (state == null) return;

    state.popUntil((route) {
      if (_popUntilPredicate?.call(route) == true) return true;
      return route.settings.name == location;
    });
  }
}
