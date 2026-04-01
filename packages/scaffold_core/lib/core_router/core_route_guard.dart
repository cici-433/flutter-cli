import 'dart:async';

import 'core_route_state.dart';

/// 路由导航模式。
///
/// 该枚举用于在守卫、深链协调器和路由包装器之间传递统一的导航语义。
enum CoreNavigationMode { push, replace, go }

/// 路由守卫执行时的上下文信息。
class CoreRouteGuardContext {
  const CoreRouteGuardContext({
    required this.location,
    required this.pattern,
    required this.mode,
    required this.state,
    required this.metadata,
    this.extra,
  });

  /// 当前即将导航到的标准化 location。
  final String location;

  /// 当前匹配到的路由模式，例如 `/orders/:id`。
  final String pattern;

  /// 当前导航所使用的模式。
  final CoreNavigationMode mode;

  /// 当前匹配后的路由状态。
  final CoreRouteState state;

  /// 路由定义上声明的元数据。
  final Map<String, Object?> metadata;

  /// 导航附带的透传对象。
  final Object? extra;
}

/// 路由守卫的执行结果。
class CoreRouteGuardResult {
  const CoreRouteGuardResult._({
    required this.isAllowed,
    this.redirectLocation,
    this.redirectExtra,
    this.redirectMode,
  });

  /// 允许继续导航。
  const CoreRouteGuardResult.allow() : this._(isAllowed: true);

  /// 拦截导航且不做跳转。
  const CoreRouteGuardResult.block() : this._(isAllowed: false);

  /// 拦截当前导航并重定向到新位置。
  const CoreRouteGuardResult.redirect(
    String location, {
    Object? extra,
    CoreNavigationMode mode = CoreNavigationMode.go,
  }) : this._(
         isAllowed: false,
         redirectLocation: location,
         redirectExtra: extra,
         redirectMode: mode,
       );

  /// 是否允许当前导航继续执行。
  final bool isAllowed;

  /// 被重定向到的新 location。
  final String? redirectLocation;

  /// 重定向时透传的新参数。
  final Object? redirectExtra;

  /// 重定向时使用的导航模式。
  final CoreNavigationMode? redirectMode;
}

/// 路由守卫接口。
///
/// 业务可实现该接口，将登录态、权限、环境开关、实验分流等逻辑统一放到路由层。
abstract class CoreRouteGuard {
  const CoreRouteGuard();

  /// 在导航实际执行前判断是否允许继续。
  FutureOr<CoreRouteGuardResult> canNavigate(CoreRouteGuardContext context);
}

/// 基于登录态的守卫实现。
class CoreAuthGuard extends CoreRouteGuard {
  const CoreAuthGuard({
    required this.isAuthenticated,
    required this.redirectLocation,
    this.redirectMode = CoreNavigationMode.go,
    this.mustBeAuthenticated = true,
  });

  /// 异步或同步获取当前是否已登录。
  final FutureOr<bool> Function() isAuthenticated;

  /// 不满足条件时跳转到的目标路由。
  final String redirectLocation;

  /// 重定向所采用的导航模式。
  final CoreNavigationMode redirectMode;

  /// 是否要求用户必须为已登录状态。
  ///
  /// 默认为 `true`，可通过设置为 `false` 实现“登录页仅未登录用户可访问”的反向守卫。
  final bool mustBeAuthenticated;

  @override
  Future<CoreRouteGuardResult> canNavigate(
    CoreRouteGuardContext context,
  ) async {
    final authenticated = await isAuthenticated();
    if (authenticated == mustBeAuthenticated) {
      return const CoreRouteGuardResult.allow();
    }
    return CoreRouteGuardResult.redirect(redirectLocation, mode: redirectMode);
  }
}

/// 基于权限集合的守卫实现。
///
/// 约定从路由元数据中读取权限列表，并与运行时权限集合做包含关系校验。
class CorePermissionGuard extends CoreRouteGuard {
  const CorePermissionGuard({
    required this.resolvePermissions,
    this.metadataKey = 'requiredPermissions',
    this.redirectLocation,
    this.redirectMode = CoreNavigationMode.go,
  });

  /// 获取当前用户权限集合。
  final FutureOr<Set<String>> Function() resolvePermissions;

  /// 在路由元数据中读取权限列表时使用的 key。
  final String metadataKey;

  /// 校验失败时的跳转目标。
  final String? redirectLocation;

  /// 权限不足时的重定向模式。
  final CoreNavigationMode redirectMode;

  @override
  Future<CoreRouteGuardResult> canNavigate(
    CoreRouteGuardContext context,
  ) async {
    final rawPermissions = context.metadata[metadataKey];
    if (rawPermissions is! Iterable<Object?>) {
      return const CoreRouteGuardResult.allow();
    }

    final requiredPermissions = rawPermissions.whereType<String>().toSet();
    if (requiredPermissions.isEmpty) {
      return const CoreRouteGuardResult.allow();
    }

    final permissions = await resolvePermissions();
    final allowed = requiredPermissions.every(permissions.contains);
    if (allowed) {
      return const CoreRouteGuardResult.allow();
    }

    if (redirectLocation == null) {
      return const CoreRouteGuardResult.block();
    }

    return CoreRouteGuardResult.redirect(redirectLocation!, mode: redirectMode);
  }
}
