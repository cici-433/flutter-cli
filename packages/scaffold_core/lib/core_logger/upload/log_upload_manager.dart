import 'dart:async';

import '../log_level.dart';
import '../log_record.dart';
import 'file_log_upload_store.dart';
import 'log_upload_store.dart';
import 'log_uploader.dart';

/// 日志上传管理器（主动触发）。
///
/// 特点：
/// - 只负责“收集待上传日志 + 主动触发上传”，不会在每次写日志时自动发网络请求
/// - 支持选择不同的上传存储实现（例如文件队列）
/// - 同一时间只允许一个上传在进行，避免并发上传导致重复/乱序
class LogUploadManager {
  /// 创建上传管理器。
  ///
  /// - [store] 为待上传日志的存储实现（推荐使用 [FileLogUploadStore]）
  /// - [minLevel] 控制进入上传存储的最低等级
  /// - [batchSize] 控制单次上传的最大条数
  LogUploadManager({
    required LogUploader uploader,
    required LogUploadStore store,
    this.minLevel = LogLevel.error,
    this.batchSize = 50,
  })  : _uploader = uploader,
        _store = store;

  /// 使用文件队列作为上传存储的便捷构造。
  ///
  /// - [queueFilePath]：JSONL 队列文件路径（每行一个 JSON）
  /// - [cursorFilePath]：cursor 文件路径（记录已消费偏移量）
  LogUploadManager.file({
    required LogUploader uploader,
    required String queueFilePath,
    String? cursorFilePath,
    int compactionThresholdBytes = 1024 * 1024,
    this.minLevel = LogLevel.error,
    this.batchSize = 50,
  })  : _uploader = uploader,
        _store = FileLogUploadStore(
          queueFilePath: queueFilePath,
          cursorFilePath: cursorFilePath,
          compactionThresholdBytes: compactionThresholdBytes,
        );

  final LogUploader _uploader;
  final LogUploadStore _store;

  final LogLevel minLevel;
  final int batchSize;

  Future<void>? _uploading;

  /// 待上传条数（如果存储实现无法快速计算可能为 -1）。
  int get pendingCount => _store.pendingCount;

  /// 添加一条日志到待上传存储（会按 [minLevel] 过滤）。
  Future<void>? add(LogRecord record) {
    if (record.level.priority < minLevel.priority) return null;
    return _store.add(record);
  }

  /// 清空所有待上传日志。
  void clear() {
    unawaited(_store.clear());
  }

  /// 主动触发上传。
  ///
  /// - [maxBatchSize]：本次上传的最大条数；不传则使用 [batchSize]
  /// - 上传失败会调用存储的回滚逻辑，确保后续仍可重试
  Future<void> upload({int? maxBatchSize}) async {
    if (_uploading != null) return _uploading;

    final size =
        (maxBatchSize ?? batchSize) <= 0 ? batchSize : (maxBatchSize ?? batchSize);
    final batch = await _store.takeBatch(maxCount: size);
    if (batch == null || batch.records.isEmpty) return;

    final task = _uploader.upload(batch.records).then((_) async {
      await _store.commit(batch);
    }).catchError((Object e, StackTrace s) async {
      await _store.rollback(batch);
      Error.throwWithStackTrace(e, s);
    }).whenComplete(() {
      _uploading = null;
    });

    _uploading = task;
    return task;
  }
}
