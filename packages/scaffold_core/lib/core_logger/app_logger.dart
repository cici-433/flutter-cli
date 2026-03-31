import 'dart:async';

import 'formatters.dart';
import 'log_level.dart';
import 'log_record.dart';
import 'sinks.dart';
import 'transformers.dart';
import 'upload/upload_manager.dart';

/// 应用无关的日志门面（Logger）
///
/// 核心能力：
/// - 级别过滤：[minLevel]
/// - 内容转换：多个 [LogTransformer]
/// - 格式化输出：[LogFormatter]
/// - 多目标输出：多个 [LogSink]
///
/// 处理链路：
/// `LogRecord -> Transformer(s) -> Formatter -> Sink(s)`
class AppLogger {
  AppLogger({
    LogLevel minLevel = LogLevel.info,
    LogFormatter formatter = const LineLogFormatter(),
    List<LogTransformer> transformers = const <LogTransformer>[],
    List<LogSink>? sinks,
    LogUploadManager? uploadManager,
  })  : _minLevel = minLevel,
        _formatter = formatter,
        _transformers = transformers,
        _sinks = sinks ?? const <LogSink>[DeveloperLogSink()],
        _uploadManager = uploadManager;

  final LogLevel _minLevel;
  final LogFormatter _formatter;
  final List<LogTransformer> _transformers;
  final List<LogSink> _sinks;
  final LogUploadManager? _uploadManager;

  /// trace 级别日志。
  void trace(
    Object? message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? fields,
  }) {
    log(
      LogLevel.trace,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      fields: fields,
    );
  }

  /// debug 级别日志。
  void debug(
    Object? message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? fields,
  }) {
    log(
      LogLevel.debug,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      fields: fields,
    );
  }

  /// info 级别日志。
  void info(
    Object? message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? fields,
  }) {
    log(
      LogLevel.info,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      fields: fields,
    );
  }

  /// warning 级别日志。
  void warning(
    Object? message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? fields,
  }) {
    log(
      LogLevel.warning,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      fields: fields,
    );
  }

  /// error 级别日志。
  void error(
    Object? message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? fields,
  }) {
    log(
      LogLevel.error,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      fields: fields,
    );
  }

  /// fatal 级别日志。
  void fatal(
    Object? message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? fields,
  }) {
    log(
      LogLevel.fatal,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      fields: fields,
    );
  }

  /// 写入一条日志（通用入口）
  ///
  /// 参数约定：
  /// - [tag]：模块/业务域标识（会参与格式化输出）
  /// - [fields]：结构化字段（建议只放可 JSON 序列化数据）
  void log(
    LogLevel level,
    Object? message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? fields,
  }) {
    if (level.priority < _minLevel.priority) return;

    var record = LogRecord(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      fields: fields,
    );

    for (final transformer in _transformers) {
      record = transformer.transform(record);
    }

    final uploadResult = _uploadManager?.add(record);
    if (uploadResult is Future<void>) {
      unawaited(uploadResult);
    }

    final formatted = _formatter.format(record);
    for (final sink in _sinks) {
      if (record.level.priority < sink.minLevel.priority) continue;
      try {
        final result = sink.write(formatted, record);
        if (result is Future<void>) {
          unawaited(result);
        }
      } catch (_) {}
    }
  }

  /// 主动触发一次日志上传（如果配置了 uploadManager）。
  Future<void> uploadLogs({int? maxBatchSize}) async {
    await _uploadManager?.upload(maxBatchSize: maxBatchSize);
  }

  /// 清空待上传缓冲区（如果配置了 uploadManager）。
  void clearUploadBuffer() {
    _uploadManager?.clear();
  }

  /// 刷新所有 Sink。
  Future<void> flush() async {
    for (final sink in _sinks) {
      try {
        final result = sink.flush();
        if (result is Future<void>) await result;
      } catch (_) {}
    }
  }

  /// 关闭所有 Sink。
  Future<void> close() async {
    for (final sink in _sinks) {
      try {
        final result = sink.close();
        if (result is Future<void>) await result;
      } catch (_) {}
    }
  }
}
