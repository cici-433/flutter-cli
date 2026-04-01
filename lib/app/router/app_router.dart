import 'package:scaffold_core/scaffold_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_scaffold_demo/domain/auth/auth_session_service.dart';
import 'package:flutter_scaffold_demo/feature/login/presentation/pages/login_page.dart';
import 'package:flutter_scaffold_demo/feature/shell/presentation/pages/shell_page.dart';

/// 应用层路由声明入口。
///
/// 职责：
/// - 集中声明页面与路由模式的映射关系
/// - 绑定登录态守卫、防重入策略等业务路由规则
/// - 提供统一的 location 构建能力，避免业务散落拼接路径和 query
class AppRouter {
  /// 壳页面路由。
  static const String shellRoute = '/';

  /// 登录页面路由。
  static const String loginRoute = '/login';

  /// 构建应用级路由注册中心。
  ///
  /// 当前示例中：
  /// - 首页开启导航节流、去重和单飞控制
  /// - 登录页只允许未登录用户访问，已登录用户会被重定向回首页
  static CoreRouteRegistry buildRegistry(
    AuthSessionService authSessionService,
  ) {
    return CoreRouteRegistry(
      routes: <CoreRouteDefinition>[
        CoreRouteDefinition(
          path: shellRoute,
          pageBuilder: (BuildContext context, CoreRouteState state) {
            return const ShellPage();
          },
          navigationPolicy: const CoreNavigationPolicy(
            preventDuplicate: true,
            singleFlight: true,
            throttleDuration: Duration(milliseconds: 500),
          ),
        ),
        CoreRouteDefinition(
          path: loginRoute,
          pageBuilder: (BuildContext context, CoreRouteState state) {
            return const LoginPage();
          },
          guards: <CoreRouteGuard>[
            CoreAuthGuard(
              isAuthenticated: () => authSessionService.currentSession != null,
              redirectLocation: shellRoute,
              mustBeAuthenticated: false,
            ),
          ],
          navigationPolicy: const CoreNavigationPolicy(
            preventDuplicate: true,
            singleFlight: true,
            throttleDuration: Duration(milliseconds: 500),
          ),
        ),
      ],
      unknownRouteBuilder: (BuildContext context, String location) {
        return Scaffold(body: Center(child: Text('未找到路由: $location')));
      },
    );
  }

  /// 根据路径模板、路径参数和 query 参数构建最终 location。
  ///
  /// 复杂对象 query 参数会交给 [CoreRouteCodec] 自动编码。
  static String buildLocation(
    String path, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, Object?> queryParameters = const <String, Object?>{},
  }) {
    var resolvedPath = path;
    pathParameters.forEach((key, value) {
      resolvedPath = resolvedPath.replaceAll(
        ':$key',
        Uri.encodeComponent(value),
      );
    });
    return Uri(
      path: resolvedPath,
      queryParameters: CoreRouteCodec.encodeQueryParameters(queryParameters),
    ).toString();
  }
}
