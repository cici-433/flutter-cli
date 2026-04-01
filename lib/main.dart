import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scaffold_core/scaffold_core.dart';
import 'package:flutter_scaffold_demo/app/app.dart';
import 'package:flutter_scaffold_demo/app/app_scope.dart';

/// 应用入口。
///
/// 本项目的启动流程包含两条“全局能力”：
/// 1) 依赖注入（AppScope + Riverpod ProviderScope）
/// 2) 异常兜底（scaffold_core 的 ErrorGuard）
///
/// 设计意图：
/// - main() 只负责“装配”：初始化必要依赖、安装兜底、启动 runApp
/// - 业务异常（例如接口失败、表单校验）不在这里处理，而是在各模块 Controller/UseCase 处理
/// - 兜底机制是最后一道网：捕获未处理异常并写日志，避免线上“静默失败”
void main() {
  /// 统一日志实例：
  /// - 兜底（ErrorGuard）会写日志
  /// - 应用依赖容器（AppScope）也需要 logger
  ///
  /// 这里显式复用同一份 logger，保证：
  /// - 日志格式/级别一致
  /// - 上下文/上传策略一致（如果后续配置上传）
  final logger = AppLogger(
    minLevel: LogLevel.debug,
    formatter: const LineLogFormatter(includeStackTrace: false),
  );

  /// 安装异常兜底并启动应用。
  ///
  /// ErrorGuard 会做三类捕获：
  /// - FlutterError.onError：框架错误（build/layout/paint 等）
  /// - PlatformDispatcher.instance.onError：引擎/平台回调错误
  /// - runZonedGuarded：Zone 内未处理异步异常（Future/Timer/Stream）
  ///
  /// 约束：
  /// - 兜底不应影响用户主流程：上报与写日志以“尽力而为”方式进行
  /// - contextProvider 只放“可上报的公共信息”，不要包含敏感字段（token/密码/手机号明文等）
  ErrorGuard.runGuarded(
    () {
      /// Flutter 绑定初始化必须在 runApp 之前。
      WidgetsFlutterBinding.ensureInitialized();

      /// 启动异步装配流程。
      ///
      /// 这里使用 unawaited 的原因：
      /// - main() 必须是同步返回（void main），否则需要改成 Future<void> main 并 await
      /// - 我们把所有未处理异常交给 ErrorGuard 的 Zone 兜底
      ///
      /// 注意：
      /// - _bootstrap 内部如果抛出未处理异常，会被 ErrorGuard 捕获并写日志
      unawaited(_bootstrap(logger));
    },
    logger: logger,

    /// 公共上下文字段（每次兜底上报都会携带）。
    ///
    /// 实际工程里常见的字段包括：
    /// - env/appVersion/buildNumber
    /// - userId（不含敏感凭证）
    /// - network（wifi/4g/none）
    /// - route（当前路由）
    contextProvider: () => <String, Object?>{'app': 'flutter_scaffold_demo'},
    tag: 'app',
  );
}

/// 启动装配流程（异步）。
///
/// 工作内容：
/// - 构建应用依赖容器 [AppScope]
/// - 以 ProviderScope 启动 Flutter App，并注入 appScopeProvider
///
/// 为什么要抽成方法：
/// - main() 保持“装配入口”清晰
/// - 便于未来扩展：例如读取远端配置、初始化 APM/埋点、预热缓存等
Future<void> _bootstrap(AppLogger logger) async {
  final context = StartupContext(logger: logger);
  final runner = StartupRunner(
    context: context,
    tasks: <StartupTask>[
      StartupTask(
        id: 'app_scope',
        phase: StartupPhase.main,
        run: (ctx) async {
          final scope = await AppScope.create(logger: logger);
          ctx.set('app_scope', scope);
        },
      ),
      StartupTask(
        id: 'run_app',
        phase: StartupPhase.main,
        dependsOn: const <String>['app_scope'],
        run: (ctx) {
          final scope = ctx.get<AppScope>('app_scope')!;
          runApp(
            ProviderScope(
              overrides: <Override>[appScopeProvider.overrideWithValue(scope)],
              child: const App(),
            ),
          );
        },
      ),
    ],
  );

  final report = await runner.run(
    phases: const <StartupPhase>[StartupPhase.main],
  );
  logger.info(
    'startup_report',
    tag: 'startup',
    fields: <String, Object?>{
      'duration_ms': report.duration.inMilliseconds,
      'has_failure': report.hasFailure,
      'tasks': report.results
          .map(
            (r) => <String, Object?>{
              'id': r.id,
              'phase': r.phase.name,
              'duration_ms': r.duration.inMilliseconds,
              'success': r.isSuccess,
            },
          )
          .toList(growable: false),
    },
  );
}
