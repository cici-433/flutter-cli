import 'dart:convert';
import 'dart:io';

import '../log_level.dart';
import '../log_record.dart';
import 'log_upload_store.dart';

/// 基于文件的待上传日志队列（JSONL + cursor）。
///
/// - 队列文件：每行一个 JSON（JSONL），追加写入
/// - 游标文件：记录已消费（已成功上传）的文件偏移量（cursor）
///
/// 上传流程：
/// - [add]：把日志追加到队列文件末尾
/// - [takeBatch]：从 cursor 开始读取最多 N 行，返回批次，并把“下一位置”作为 commitToken
/// - [commit]：写入新的 cursor，实现“逻辑删除”（下次从新 cursor 继续读）
/// - [rollback]：不推进 cursor（等价于批次可重试）
///
/// 压缩策略：
/// - 当 cursor 足够大时会触发压缩，把已消费部分从文件中物理移除，避免文件无限增长
class FileLogUploadStore extends LogUploadStore {
  /// 创建文件队列存储。
  ///
  /// - [queueFilePath]：队列文件路径（JSONL）
  /// - [cursorFilePath]：cursor 文件路径（不传则默认使用 `$queueFilePath.cursor`）
  /// - [compactionThresholdBytes]：cursor 超过该阈值后允许触发压缩
  FileLogUploadStore({
    required String queueFilePath,
    String? cursorFilePath,
    this.compactionThresholdBytes = 1024 * 1024,
  })  : _queueFile = File(queueFilePath),
        _cursorFile = File(cursorFilePath ?? '$queueFilePath.cursor');

  final File _queueFile;
  final File _cursorFile;

  /// 触发压缩的最小 cursor 大小（字节）。
  final int compactionThresholdBytes;

  /// 简单串行锁，避免并发读写导致 cursor/文件内容不一致。
  Future<void> _lock = Future<void>.value();

  Future<T> _withLock<T>(Future<T> Function() action) {
    final next = _lock.then((_) => action());
    _lock = next.then<void>((_) {}, onError: (_) {});
    return next;
  }
  @override
  /// 追加写入一条待上传日志到队列文件末尾。
  Future<void>? add(LogRecord record) {
    return _withLock(() async {
      try {
        await _queueFile.create(recursive: true);
        final line = _encodeRecord(record);
        await _queueFile.writeAsString('$line\n', mode: FileMode.append);
      } catch (_) {}
    });
  }

  @override
  /// 从 cursor 开始读取最多 [maxCount] 行，形成批次并返回。
  Future<LogUploadBatch?> takeBatch({required int maxCount}) {
    return _withLock(() async {
      try {
        final exists = await _queueFile.exists();
        if (!exists) return null;

        final cursor = await _readCursor();
        final raf = await _queueFile.open(mode: FileMode.read);
        try {
          final length = await raf.length();
          if (cursor >= length) return null;

          await raf.setPosition(cursor);
          final records = <LogRecord>[];
          while (records.length < maxCount) {
            final line = await _readLine(raf);
            if (line == null) break;
            if (line.trim().isEmpty) continue;
            final record = _tryDecodeRecord(line);
            if (record != null) {
              records.add(record);
            }
          }

          if (records.isEmpty) return null;
          final nextCursor = await raf.position();
          return LogUploadBatch(records: records, commitToken: nextCursor);
        } finally {
          await raf.close();
        }
      } catch (_) {
        return null;
      }
    });
  }

  @override
  /// 提交已上传批次：推进 cursor，并在满足条件时触发压缩。
  Future<void> commit(LogUploadBatch batch) {
    return _withLock(() async {
      final token = batch.commitToken;
      if (token is! int) return;
      try {
        await _writeCursor(token);
        await _compactIfNeeded();
      } catch (_) {}
    });
  }

  @override
  /// 回滚批次：文件队列模式下无需额外操作（不推进 cursor 即可重试）。
  Future<void> rollback(LogUploadBatch batch) async {}

  @override
  /// 清空队列文件与 cursor 文件。
  Future<void> clear() {
    return _withLock(() async {
      try {
        if (await _queueFile.exists()) {
          await _queueFile.delete();
        }
        if (await _cursorFile.exists()) {
          await _cursorFile.delete();
        }
      } catch (_) {}
    });
  }

  Future<int> _readCursor() async {
    try {
      final exists = await _cursorFile.exists();
      if (!exists) return 0;
      final text = await _cursorFile.readAsString();
      return int.tryParse(text.trim()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _writeCursor(int cursor) async {
    try {
      await _cursorFile.create(recursive: true);
      await _cursorFile.writeAsString('$cursor');
    } catch (_) {}
  }

  Future<void> _compactIfNeeded() async {
    final cursor = await _readCursor();
    if (cursor <= 0) return;
    if (cursor < compactionThresholdBytes) return;

    final exists = await _queueFile.exists();
    if (!exists) {
      await _writeCursor(0);
      return;
    }

    final length = await _queueFile.length();
    if (cursor >= length) {
      try {
        await _queueFile.writeAsString('', mode: FileMode.write);
      } catch (_) {}
      await _writeCursor(0);
      return;
    }

    if (cursor * 2 < length) return;

    final tmp = File('${_queueFile.path}.tmp');
    RandomAccessFile? src;
    RandomAccessFile? dst;
    try {
      await tmp.create(recursive: true);
      src = await _queueFile.open(mode: FileMode.read);
      dst = await tmp.open(mode: FileMode.write);
      await src.setPosition(cursor);

      while (true) {
        final chunk = await src.read(64 * 1024);
        if (chunk.isEmpty) break;
        await dst.writeFrom(chunk);
      }
    } catch (_) {
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      return;
    } finally {
      try {
        await src?.close();
      } catch (_) {}
      try {
        await dst?.close();
      } catch (_) {}
    }

    try {
      if (await _queueFile.exists()) {
        await _queueFile.delete();
      }
      await tmp.rename(_queueFile.path);
      await _writeCursor(0);
    } catch (_) {}
  }

  String _encodeRecord(LogRecord record) {
    final map = <String, Object?>{
      'ts': record.timestamp.toIso8601String(),
      'level': record.level.label,
      'tag': record.tag,
      'message': record.message?.toString(),
      'error': record.error?.toString(),
      'stackTrace': record.stackTrace?.toString(),
      'fields': record.fields,
    };

    try {
      return jsonEncode(map);
    } catch (_) {
      return jsonEncode(<String, Object?>{
        'ts': record.timestamp.toIso8601String(),
        'level': record.level.label,
        'tag': record.tag,
        'message': record.message?.toString(),
        'error': record.error?.toString(),
        'stackTrace': record.stackTrace?.toString(),
        'fields': record.fields?.toString(),
      });
    }
  }

  LogRecord? _tryDecodeRecord(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) return null;
      final map = decoded.cast<String, Object?>();
      final ts = map['ts'];
      final levelLabel = map['level'];
      final tag = map['tag'];
      final message = map['message'];
      final error = map['error'];
      final stackTrace = map['stackTrace'];
      final fields = map['fields'];

      final level = _tryParseLevel(levelLabel?.toString());
      if (level == null) return null;

      return LogRecord(
        timestamp: ts is String ? DateTime.parse(ts) : DateTime.now(),
        level: level,
        message: message,
        tag: tag is String ? tag : null,
        error: error,
        stackTrace: stackTrace is String ? StackTrace.fromString(stackTrace) : null,
        fields: fields is Map ? fields.cast<String, Object?>() : null,
      );
    } catch (_) {
      return null;
    }
  }

  LogLevel? _tryParseLevel(String? label) {
    if (label == null) return null;
    switch (label.toUpperCase()) {
      case 'TRACE':
        return LogLevel.trace;
      case 'DEBUG':
        return LogLevel.debug;
      case 'INFO':
        return LogLevel.info;
      case 'WARN':
      case 'WARNING':
        return LogLevel.warning;
      case 'ERROR':
        return LogLevel.error;
      case 'FATAL':
        return LogLevel.fatal;
    }
    return null;
  }

  Future<String?> _readLine(RandomAccessFile raf) async {
    final buffer = <int>[];
    while (true) {
      final chunk = await raf.read(1024);
      if (chunk.isEmpty) {
        if (buffer.isEmpty) return null;
        break;
      }

      final newLineIndex = chunk.indexOf(0x0A);
      if (newLineIndex == -1) {
        buffer.addAll(chunk);
        continue;
      }

      buffer.addAll(chunk.sublist(0, newLineIndex));
      final currentPos = await raf.position();
      final unreadBytes = chunk.length - newLineIndex - 1;
      if (unreadBytes > 0) {
        await raf.setPosition(currentPos - unreadBytes);
      }
      break;
    }

    if (buffer.isNotEmpty && buffer.last == 0x0D) {
      buffer.removeLast();
    }
    return utf8.decode(buffer, allowMalformed: true);
  }
}
