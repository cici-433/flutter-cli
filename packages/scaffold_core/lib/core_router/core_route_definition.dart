import 'package:flutter/widgets.dart';

import 'core_route_guard.dart';
import 'core_route_state.dart';

/// 路由页面构建器。
typedef CoreRoutePageBuilder =
    Widget Function(BuildContext context, CoreRouteState state);

/// 防重入去重 key 的构建器。
typedef CoreRouteDedupeKeyBuilder =
    String Function(String location, Object? extra);

/// 导航防重入策略。
///
/// 用于控制用户重复点击、异步跳转竞态、连续深链回调等常见问题。
class CoreNavigationPolicy {
  const CoreNavigationPolicy({
    this.preventDuplicate = false,
    this.singleFlight = false,
    this.throttleDuration,
    this.dedupeKeyBuilder,
  });

  /// 同一目标导航完成后，后续完全相同的导航是否直接忽略。
  final bool preventDuplicate;

  /// 相同导航是否只允许一个请求在飞行中执行。
  final bool singleFlight;

  /// 节流窗口，在该时间内重复触发相同导航将被忽略。
  final Duration? throttleDuration;

  /// 自定义去重 key 生成规则。
  final CoreRouteDedupeKeyBuilder? dedupeKeyBuilder;
}

/// 单个路由定义。
///
/// 该对象是中心化路由注册的最小单元，包含页面构建、守卫、元数据和导航策略。
class CoreRouteDefinition {
  const CoreRouteDefinition({
    required this.path,
    required this.pageBuilder,
    this.guards = const <CoreRouteGuard>[],
    this.metadata = const <String, Object?>{},
    this.navigationPolicy = const CoreNavigationPolicy(),
  });

  /// 路由模式，支持 `:id` 形式的动态段。
  final String path;

  /// 页面构建函数。
  final CoreRoutePageBuilder pageBuilder;

  /// 当前路由专属守卫列表。
  final List<CoreRouteGuard> guards;

  /// 路由元数据，可用于权限、埋点、实验等扩展能力。
  final Map<String, Object?> metadata;

  /// 当前路由的导航防重入策略。
  final CoreNavigationPolicy navigationPolicy;

  /// 尝试匹配 [location]，成功时返回 [CoreRouteState]。
  CoreRouteState? match(String location, {Object? extra}) {
    final uri = _normalizeUri(location);
    final pathParameters = _matchPath(uri.path.isEmpty ? '/' : uri.path);
    if (pathParameters == null) {
      return null;
    }
    return CoreRouteState(
      uri: uri,
      pathParameters: pathParameters,
      extra: extra,
    );
  }

  /// 将输入 location 规范化为统一的 URI 表达形式。
  static Uri _normalizeUri(String location) {
    final uri = Uri.parse(location.isEmpty ? '/' : location);
    return Uri(
      path: uri.path.isEmpty ? '/' : uri.path,
      queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
      fragment: uri.fragment.isEmpty ? null : uri.fragment,
    );
  }

  /// 根据路由模式匹配实际路径，并提取动态参数。
  Map<String, String>? _matchPath(String actualPath) {
    final routeSegments = _segmentsOf(path);
    final actualSegments = _segmentsOf(actualPath);
    if (routeSegments.length != actualSegments.length) {
      return null;
    }

    final parameters = <String, String>{};
    for (var index = 0; index < routeSegments.length; index++) {
      final routeSegment = routeSegments[index];
      final actualSegment = actualSegments[index];
      if (routeSegment.startsWith(':')) {
        parameters[routeSegment.substring(1)] = actualSegment;
        continue;
      }
      if (routeSegment != actualSegment) {
        return null;
      }
    }
    return parameters;
  }

  /// 将路径拆分为段列表。
  static List<String> _segmentsOf(String path) {
    if (path == '/') {
      return const <String>[];
    }
    return path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
  }
}
