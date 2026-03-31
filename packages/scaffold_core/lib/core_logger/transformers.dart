import 'log_record.dart';

/// 日志记录转换器
///
/// 用于“结构化地修改日志内容”，常见用途：
/// - 增加全局字段（appVersion、deviceId、traceId 等）
/// - 脱敏敏感信息（token、手机号、身份证等）
/// - 统一 tag/模块名
abstract class LogTransformer {
  const LogTransformer();
  LogRecord transform(LogRecord record);
}

