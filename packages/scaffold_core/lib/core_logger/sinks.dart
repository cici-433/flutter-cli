import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'log_level.dart';
import 'log_record.dart';

/// 日志输出目标（Sink）
///
/// 一个 Logger 可以同时配置多个 Sink，例如：
/// - 开发期输出到控制台/DevTools
/// - 生产环境写入文件
///
/// 约定：
/// - [minLevel]：该 Sink 的最低输出等级（独立于 Logger 的 minLevel）
/// - [write]：写入一条日志
/// - [flush]/[close]：用于确保缓存写入完成或释放资源
abstract class LogSink {
  const LogSink();

  /// 该 Sink 接收的最低日志等级。
  LogLevel get minLevel => LogLevel.trace;

  /// 写入一条日志
  ///
  /// - [formatted]：由 [LogFormatter] 生成的输出对象
  /// - [record]：原始结构化日志记录
  FutureOr<void> write(Object formatted, LogRecord record);

  /// 刷新缓存（可选）
  FutureOr<void> flush() {}

  /// 关闭资源（可选）
  FutureOr<void> close() {}
}

/// 基于 `dart:developer.log` 的输出 Sink
///
/// 适用场景：
/// - Flutter 开发/调试期（DevTools、IDE Console、Android logcat 等）
class DeveloperLogSink extends LogSink {
  const DeveloperLogSink({this.tagName});

  /// 固定的日志通道名称；为空时使用日志级别标签。
  final String? tagName;

  @override
  FutureOr<void> write(Object formatted, LogRecord record) {
    developer.log(
      formatted.toString(),
      name: tagName ?? record.level.label,
      level: record.level.developerLevel,
      error: record.error,
      stackTrace: record.stackTrace,
      time: record.timestamp,
    );
  }
}

/// 输出到标准输出的 Sink
///
/// 适用场景：
/// - CLI 工具
/// - 测试环境
class ConsoleLogSink extends LogSink {
  const ConsoleLogSink();

  @override
  FutureOr<void> write(Object formatted, LogRecord record) {
    stdout.writeln(formatted.toString());
  }
}

/// 写入文件的 Sink（带简单轮转）
///
/// 轮转策略：
/// - 当前文件大小超过 [maxBytes] 时，会把旧文件重命名为 `filePath.<timestamp>`
/// - 保留最近 [maxFiles] 个轮转文件，超出的会删除
///
/// 注意：
/// - 该实现以“顺序写”保证多次写入不会相互覆盖（通过内部 Future 链串行化）
class FileLogSink extends LogSink {
  FileLogSink({
    required String filePath,
    this.maxBytes = 5 * 1024 * 1024,
    this.maxFiles = 3,
    this.minLevel = LogLevel.trace,
  })  : _filePath = filePath,
        _file = File(filePath);

  final String _filePath;
  final File _file;

  @override
  /// 文件 Sink 的最低输出等级。
  final LogLevel minLevel;

  /// 单文件最大字节数，超过后触发轮转。
  final int maxBytes;

  /// 轮转文件保留数量（不含当前文件）。
  final int maxFiles;

  Future<void>? _pending;

  @override
  Future<void> write(Object formatted, LogRecord record) {
    final text = '${formatted.toString()}\n';
    Future<void> action() async {
      try {
        await _rotateIfNeeded(text.length);
        await _file.create(recursive: true);
        await _file.writeAsString(text, mode: FileMode.append, flush: false);
      } catch (_) {}
    }

    final next = (_pending ?? Future<void>.value()).then((_) => action());
    _pending = next;
    return next;
  }

  Future<void> _rotateIfNeeded(int incomingBytes) async {
    try {
      final exists = await _file.exists();
      if (!exists) return;
      final length = await _file.length();
      if (length + incomingBytes <= maxBytes) return;

      final rotatedPath = '$_filePath.${DateTime.now().millisecondsSinceEpoch}';
      await _file.rename(rotatedPath);

      final dir = _file.parent;
      final baseName = _file.uri.pathSegments.last;
      final rotated = await dir
          .list()
          .where((e) => e is File)
          .cast<File>()
          .where((f) => f.uri.pathSegments.last.startsWith('$baseName.'))
          .toList();

      rotated.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );
      if (rotated.length <= maxFiles) return;
      for (final f in rotated.skip(maxFiles)) {
        try {
          await f.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  @override
  /// 等待所有挂起写入完成。
  Future<void> flush() async {
    await _pending;
  }

  @override
  /// 关闭文件 Sink（当前实现仅等待挂起写入完成）。
  Future<void> close() async {
    await _pending;
  }
}
