import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:scaffold_core/core_logger/app_logger.dart';

/// 上报上下文的提供者。
///
/// 说明：
/// - 用于集中采集“每次上报都需要带的公共字段”，例如 appVersion、device、network、userId 等。
/// - 该 provider 可能抛异常（例如依赖尚未初始化），ErrorGuard 会吞掉异常并继续上报其它信息。
typedef ErrorContextProvider = Map<String, Object?> Function();

/// 异常兜底机制：捕获未处理异常并写入日志。
///
/// 捕获范围（覆盖面由外到内）：
/// - Flutter 框架错误：通过 [FlutterError.onError] 捕获（build/layout/paint 等）。
/// - 引擎/平台回调错误：通过 [PlatformDispatcher.instance.onError] 捕获。
/// - Zone 内未处理异步错误：通过 [runZonedGuarded] 捕获（Future/Timer/Stream 链）。
///
/// 核心原则：
/// - 兜底只做“收敛与记录”，不在 core 层做业务级恢复策略（如弹窗、强登出、重试等）。
/// - 兜底本身不能成为新的崩溃点：内部使用 try/catch 做“尽力而为”。
///
/// 推荐使用方式：
/// - 在应用入口 main() 里使用 [runGuarded] 包裹 runApp，并配置 logger/contextProvider。
///
/// 说明：
/// - scaffold_core 不直接对接三方 APM SDK。
/// - 若需要“上报到 APM”，推荐通过 core_logger 的 upload/sink 机制统一上传日志或转发异常事件。
final class ErrorGuard {
  const ErrorGuard({
    this.logger,
    this.contextProvider,
    this.tag = 'error_guard',
  });

  /// 可选：写日志的入口（建议使用 scaffold_core 的 [AppLogger]）。
  final AppLogger? logger;

  /// 可选：提供公共上下文信息（每次上报都会带上）。
  final ErrorContextProvider? contextProvider;

  /// 写日志时使用的 tag（便于过滤与聚合）。
  final String tag;

  /// 以兜底模式运行应用入口。
  ///
  /// 典型用法：
  /// - 初始化绑定与依赖
  /// - runApp
  ///
  /// 该方法会：
  /// 1. 安装全局兜底（[install]）
  /// 2. 在 Zone 内运行 [body]，捕获未处理异步异常并交给 [handle]
  static void runGuarded(
    void Function() body, {
    AppLogger? logger,
    ErrorContextProvider? contextProvider,
    String tag = 'error_guard',
  }) {
    final guard = ErrorGuard(
      logger: logger,
      contextProvider: contextProvider,
      tag: tag,
    );

    runZonedGuarded(() {
      guard.install();
      body();
    }, (error, stackTrace) => guard.handle(error, stackTrace, fatal: true));
  }

  /// 安装全局异常兜底钩子。
  ///
  /// 注意：
  /// - 该方法会覆盖当前的 [FlutterError.onError]。
  /// - 若业务侧需要额外处理（例如把错误转发到自定义处理链），建议在应用层包装 ErrorGuard，
  ///   或在 logger/apmReporter 中完成扩展。
  void install() {
    FlutterError.onError = (FlutterErrorDetails details) {
      handle(
        details.exception,
        details.stack ?? StackTrace.current,
        fatal: false,
      );
      FlutterError.presentError(details);
    };

    PlatformDispatcher.instance.onError =
        (Object error, StackTrace stackTrace) {
          handle(error, stackTrace, fatal: true);
          return true;
        };
  }

  /// 统一异常处理入口（兜底收敛点）。
  ///
  /// 处理顺序：
  /// 1. 合并上下文（contextProvider + 调用方 context）
  /// 2. 写入日志（如果配置了 logger）
  ///
  /// 约束建议（由应用层遵守）：
  /// - context 不应包含敏感信息（token、密码、手机号明文等）。
  /// - 大字段（完整 response/body）建议采样或截断，避免上报量暴涨。
  void handle(
    Object error,
    StackTrace stackTrace, {
    required bool fatal,
    Map<String, Object?>? context,
  }) {
    final mergedContext = <String, Object?>{
      if (contextProvider != null)
        ..._safeCallContextProvider(contextProvider!),
      if (context != null) ...context,
      'fatal': fatal,
    };

    try {
      logger?.error(
        'unhandled_error',
        tag: tag,
        error: error,
        stackTrace: stackTrace,
        fields: mergedContext.isEmpty ? null : mergedContext,
      );
    } catch (_) {}
  }

  /// 安全调用 contextProvider，避免 provider 本身异常导致兜底链路中断。
  Map<String, Object?> _safeCallContextProvider(ErrorContextProvider provider) {
    try {
      return provider();
    } catch (_) {
      return const <String, Object?>{};
    }
  }
}
