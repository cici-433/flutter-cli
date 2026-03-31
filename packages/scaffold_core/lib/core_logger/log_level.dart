/// 日志级别
///
/// 级别从低到高：
/// - trace：最细粒度调试信息（默认不建议在生产环境开启）
/// - debug：调试信息
/// - info：业务关键路径信息（默认最低等级）
/// - warning：可恢复异常、降级、重试等告警信号
/// - error：错误（请求失败、解析失败等）
/// - fatal：致命错误（通常意味着需要立即上报/触发兜底）
enum LogLevel {
  trace,
  debug,
  info,
  warning,
  error,
  fatal;
}

/// [LogLevel] 的派生属性
///
/// - [priority]：用于过滤（数字越大越重要）
/// - [label]：用于格式化输出
/// - [developerLevel]：映射到 `dart:developer.log` 的 `level` 字段
extension LogLevelValue on LogLevel {
  int get priority => switch (this) {
        LogLevel.trace => 0,
        LogLevel.debug => 1,
        LogLevel.info => 2,
        LogLevel.warning => 3,
        LogLevel.error => 4,
        LogLevel.fatal => 5,
      };

  String get label => switch (this) {
        LogLevel.trace => 'TRACE',
        LogLevel.debug => 'DEBUG',
        LogLevel.info => 'INFO',
        LogLevel.warning => 'WARN',
        LogLevel.error => 'ERROR',
        LogLevel.fatal => 'FATAL',
      };

  int get developerLevel => switch (this) {
        LogLevel.trace => 400,
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
        LogLevel.fatal => 1200,
      };
}

