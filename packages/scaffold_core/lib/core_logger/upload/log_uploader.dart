import '../log_record.dart';

/// 日志上传器
///
/// 由应用层实现，负责把日志批量发送到后端或第三方日志平台。
abstract class LogUploader {
  const LogUploader();

  /// 上传一个批次的结构化日志。
  ///
  /// - 批次内日志的顺序由调用方维护
  /// - 上传失败应抛出异常以触发上层回滚/重试
  Future<void> upload(List<LogRecord> batch);
}
