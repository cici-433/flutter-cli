import 'log_level.dart';

/// 单条日志记录的结构化表示
///
/// 该对象会按以下顺序被处理：
/// 1) 创建 [LogRecord]
/// 2) 依次通过多个 [LogTransformer] 做内容转换（脱敏/补字段/改 tag 等）
/// 3) 由 [LogFormatter] 格式化为输出载荷（字符串/JSON 等）
/// 4) 交给多个 [LogSink] 写到不同目标（控制台/文件/上传等）
class LogRecord {
  LogRecord({
    required this.timestamp,
    required this.level,
    required this.message,
    this.tag,
    this.error,
    this.stackTrace,
    this.fields,
  });

  final DateTime timestamp;
  final LogLevel level;
  final Object? message;
  final String? tag;
  final Object? error;
  final StackTrace? stackTrace;
  final Map<String, Object?>? fields;

  /// 返回一个复制对象，用于在 Transformer 链中以不可变方式修改字段。
  LogRecord copyWith({
    DateTime? timestamp,
    LogLevel? level,
    Object? message,
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? fields,
  }) {
    return LogRecord(
      timestamp: timestamp ?? this.timestamp,
      level: level ?? this.level,
      message: message ?? this.message,
      tag: tag ?? this.tag,
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
      fields: fields ?? this.fields,
    );
  }
}

