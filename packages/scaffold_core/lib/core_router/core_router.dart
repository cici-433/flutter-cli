import 'package:flutter/widgets.dart';

/// 核心路由抽象（应用无关）
///
/// 目标：
/// - 为不同路由库提供统一的最小能力集合（可插拔）
/// - 避免上层业务代码直接依赖具体路由库的 API（便于替换、测试、分层）
///
/// 设计说明：
/// - 使用 [location] 作为统一的“路由标识”，通常对应路由路径（如 `/login`）
/// - 使用 [extra] 作为透传参数（最终映射到不同路由库的 arguments/extra 等）
/// - 默认实现为 [NavigatorCoreRouter]（基于 Flutter 原生 Navigator 1.0）
/// - 应用可按需实现适配器（例如 go_router/auto_route），只要实现本接口即可
abstract class CoreRouter {
  const CoreRouter();

  /// 导航器 key，用于在无 BuildContext 场景执行导航。
  ///
  /// 默认实现通常会把它挂载到 MaterialApp/CupertinoApp 的 `navigatorKey`。
  GlobalKey<NavigatorState> get navigatorKey;

  /// 入栈导航（push）。
  Future<T?> push<T extends Object?>(
    String location, {
    Object? extra,
  });

  /// 替换当前页面（pushReplacement）。
  Future<T?> replace<T extends Object?>(
    String location, {
    Object? extra,
  });

  /// 清栈到目标页面（通常等价于“跳转并清空历史”）。
  Future<T?> go<T extends Object?>(
    String location, {
    Object? extra,
  });

  /// 是否可以返回（pop）。
  bool canPop();

  /// 返回上一页，并可携带结果。
  void pop<T extends Object?>([T? result]);

  /// 连续返回直到指定 [location] 的路由成为栈顶。
  void popUntil(String location);
}
