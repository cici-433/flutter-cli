import 'package:scaffold_core/core_logger/logger.dart';
import 'package:scaffold_core/scaffold_core.dart' show AppLogger;

/// 应用层日志封装（二次封装示例）
///
/// 目的：
/// - 为具体应用加入统一前缀/打点/过滤等
/// - 对外仍暴露最小能力，避免模块直接依赖第三方实现
class AppCoreLogger {
  final AppLogger _delegate = AppLogger();

  void info(String message) {
    _delegate.info('[app] $message');
  }
}
