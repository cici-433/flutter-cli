import 'package:flutter/material.dart';

import 'core_route_definition.dart';
import 'core_route_state.dart';

/// 未命中路由时的页面构建器。
typedef CoreUnknownRouteBuilder =
    Widget Function(BuildContext context, String location);

/// 路由匹配结果。
class CoreRouteMatch {
  const CoreRouteMatch({required this.definition, required this.state});

  /// 命中的路由定义。
  final CoreRouteDefinition definition;

  /// 命中后解析出的路由状态。
  final CoreRouteState state;
}

/// 路由注册中心。
///
/// 负责维护全量路由定义，并提供：
/// - location 标准化
/// - 路由匹配
/// - MaterialApp 可直接接入的 onGenerateRoute/onUnknownRoute
class CoreRouteRegistry {
  const CoreRouteRegistry({required this.routes, this.unknownRouteBuilder});

  /// 当前应用注册的全部路由。
  final List<CoreRouteDefinition> routes;

  /// 未匹配到路由时的兜底页面构建器。
  final CoreUnknownRouteBuilder? unknownRouteBuilder;

  /// 规范化字符串形式的 location。
  String normalizeLocation(String location) {
    final uri = Uri.parse(location.isEmpty ? '/' : location);
    return Uri(
      path: uri.path.isEmpty ? '/' : uri.path,
      queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
      fragment: uri.fragment.isEmpty ? null : uri.fragment,
    ).toString();
  }

  /// 规范化 [Uri] 为统一字符串。
  String normalizeUri(Uri uri) {
    return Uri(
      path: uri.path.isEmpty ? '/' : uri.path,
      queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
      fragment: uri.fragment.isEmpty ? null : uri.fragment,
    ).toString();
  }

  /// 按注册顺序匹配路由。
  CoreRouteMatch? match(String location, {Object? extra}) {
    final normalizedLocation = normalizeLocation(location);
    for (final route in routes) {
      final state = route.match(normalizedLocation, extra: extra);
      if (state != null) {
        return CoreRouteMatch(definition: route, state: state);
      }
    }
    return null;
  }

  /// 供 `MaterialApp.onGenerateRoute` 直接使用的路由生成函数。
  Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final location = settings.name ?? '/';
    final routeMatch = match(location, extra: settings.arguments);
    if (routeMatch == null) {
      return onUnknownRoute(settings);
    }

    return MaterialPageRoute<dynamic>(
      settings: RouteSettings(
        name: routeMatch.state.location,
        arguments: settings.arguments,
      ),
      builder: (context) {
        return routeMatch.definition.pageBuilder(context, routeMatch.state);
      },
    );
  }

  /// 供 `MaterialApp.onUnknownRoute` 使用的未知路由兜底函数。
  Route<dynamic>? onUnknownRoute(RouteSettings settings) {
    final builder = unknownRouteBuilder;
    if (builder == null) {
      return null;
    }

    final location = normalizeLocation(settings.name ?? '/');
    return MaterialPageRoute<dynamic>(
      settings: RouteSettings(name: location, arguments: settings.arguments),
      builder: (context) => builder(context, location),
    );
  }
}
