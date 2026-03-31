import 'dart:async';

import '../log_record.dart';

/// 待上传日志的一个批次快照。
///
/// - [records] 是本次准备上传的结构化日志列表
/// - [commitToken] 是存储实现用于提交/回滚的上下文（例如文件 cursor）
class LogUploadBatch {
  LogUploadBatch({
    required this.records,
    required this.commitToken,
  });

  final List<LogRecord> records;
  final Object? commitToken;
}

/// 待上传日志的存储抽象。
///
/// 上传流程分为三个阶段：
/// 1) 写入：调用 [add] 把日志加入待上传集合
/// 2) 取批：调用 [takeBatch] 得到一个待上传批次（快照）
/// 3) 结束：成功则 [commit]，失败则 [rollback]
///
/// 约定：
/// - [takeBatch] 返回的批次应具备幂等的提交语义；已提交的数据不应再次出现在后续批次中
/// - [rollback] 应尽量保证该批次后续可重试（例如把批次重新标记为未消费）
abstract class LogUploadStore {
  const LogUploadStore();

  /// 待上传条数（如果实现无法快速计算可返回 -1）。
  int get pendingCount => -1;

  /// 添加一条待上传日志。
  ///
  /// 允许返回 `null` 表示同步完成（例如纯内存实现）。
  Future<void>? add(LogRecord record);

  /// 取出最多 [maxCount] 条日志形成上传批次。
  ///
  /// 如果当前没有可上传的数据，返回 `null`。
  Future<LogUploadBatch?> takeBatch({required int maxCount});

  /// 提交批次，表示该批次已上传成功，可从存储中移除/标记为已消费。
  Future<void> commit(LogUploadBatch batch);

  /// 回滚批次，表示该批次上传失败，应保证后续还能再次取到并重试。
  Future<void> rollback(LogUploadBatch batch);

  /// 清空所有待上传日志。
  Future<void> clear();
}
