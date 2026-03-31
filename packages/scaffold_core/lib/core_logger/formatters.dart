import 'dart:convert';

import 'log_level.dart';
import 'log_record.dart';

/// 日志格式化器
///
/// 将 [LogRecord] 转换为最终输出对象，常见为：
/// - 一行文本（人类可读）
/// - JSON 字符串（机器可处理，便于写文件/上传）
abstract class LogFormatter {
  const LogFormatter();
  Object format(LogRecord record);
}

/// 行文本格式化器（默认）
///
/// 输出示例：
/// `2026-01-01T00:00:00.000Z INFO [auth] login ok fields={"uid":"1"}`
class LineLogFormatter extends LogFormatter {
  const LineLogFormatter({
    this.includeStackTrace = true,
    this.includeFields = true,
  });

  final bool includeStackTrace;
  final bool includeFields;

  @override
  Object format(LogRecord record) {
    final time = record.timestamp.toIso8601String();
    final tag =
        record.tag == null || record.tag!.isEmpty ? '' : '[${record.tag}] ';
    final msg = record.message?.toString() ?? '';

    final errorPart = record.error == null ? '' : ' error=${record.error}';
    final fieldsPart =
        !includeFields || record.fields == null || record.fields!.isEmpty
            ? ''
            : ' fields=${jsonEncode(record.fields)}';

    final base = '$time ${record.level.label} $tag$msg$errorPart$fieldsPart';
    if (!includeStackTrace || record.stackTrace == null) return base;
    return '$base\n${record.stackTrace}';
  }
}

/// JSON 格式化器
///
/// 输出为 JSON 字符串，便于：
/// - 写入日志文件
/// - 批量上传到日志平台
class JsonLogFormatter extends LogFormatter {
  const JsonLogFormatter({this.includeStackTrace = true});

  final bool includeStackTrace;

  @override
  Object format(LogRecord record) {
    final map = <String, Object?>{
      'ts': record.timestamp.toIso8601String(),
      'level': record.level.label,
      'tag': record.tag,
      'message': record.message?.toString(),
      'error': record.error?.toString(),
      'fields': record.fields,
    };
    if (includeStackTrace) {
      map['stackTrace'] = record.stackTrace?.toString();
    }
    return jsonEncode(map);
  }
}
