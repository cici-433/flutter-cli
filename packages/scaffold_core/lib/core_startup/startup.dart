import 'dart:async';

import 'package:scaffold_core/core_logger/app_logger.dart';

/// 启动阶段。
///
/// 用途：
/// - 将启动任务按“时机”分组：越早的任务越应保持轻量且稳定。
/// - 允许业务方在不同入口按需运行部分阶段（例如只跑 early/main）。
///
/// 推荐含义：
/// - [early]：启动最早期的基础设施初始化（例如 binding、存储、配置加载）。
/// - [main]：主要初始化阶段（例如鉴权态恢复、网络/路由装配、预热缓存）。
/// - [late]：非关键、可延后执行的任务（例如预取、埋点 warmup、资源预热）。
enum StartupPhase { early, main, late }

/// 启动上下文：用于任务之间共享少量状态与依赖。
///
/// 设计意图：
/// - core_startup 不负责 DI 容器实现，只提供一个简单的键值存储用于“任务间传递”。
/// - 鼓励只放“启动期确实需要共享”的对象，例如 logger、已初始化的 storage、配置快照等。
///
/// 注意：
/// - 建议避免在这里存放大对象/大量数据，避免启动阶段内存膨胀。
/// - key 建议使用稳定的字符串常量，避免拼写错误造成取不到值。
final class StartupContext {
  StartupContext({this.logger, Map<String, Object?>? values})
    : _values = values ?? <String, Object?>{};

  /// 可选：启动过程日志。
  ///
  /// StartupRunner 会输出 start/success/failure 三类事件，便于定位启动耗时与失败点。
  final AppLogger? logger;
  final Map<String, Object?> _values;

  /// 按 key 读取一个共享值（带泛型转换）。
  ///
  /// 约束：
  /// - 该方法不做运行时类型校验，调用方需保证写入/读取类型一致。
  T? get<T extends Object>(String key) => _values[key] as T?;

  /// 写入一个共享值。
  void set(String key, Object? value) {
    _values[key] = value;
  }

  /// 返回当前上下文的快照（只读）。
  Map<String, Object?> snapshot() => Map<String, Object?>.unmodifiable(_values);
}

/// 启动任务执行体签名。
///
/// 返回值允许是同步或异步（FutureOr），StartupRunner 会统一 await。
typedef StartupTaskAction = FutureOr<void> Function(StartupContext context);

/// 启动任务定义。
///
/// 设计要点：
/// - 用 [id] 做唯一标识与依赖引用。
/// - 用 [phase] 做“粗粒度时机”分组。
/// - 用 [dependsOn] 表达依赖关系（同阶段内支持拓扑调度并发执行）。
/// - 用 [critical] 区分“失败是否阻断启动”：关键任务失败会中断并抛出异常。
/// - 用 [timeout] 给单任务兜底，避免启动卡死。
/// - 用 [fields] 作为结构化日志字段，便于观测与排查。
final class StartupTask {
  const StartupTask({
    required this.id,
    required this.run,
    this.phase = StartupPhase.main,
    this.dependsOn = const <String>[],
    this.critical = true,
    this.timeout,
    this.fields,
  });

  final String id;
  final StartupPhase phase;
  final List<String> dependsOn;
  final bool critical;
  final Duration? timeout;
  final Map<String, Object?>? fields;
  final StartupTaskAction run;
}

/// 单个启动任务的执行结果。
///
/// 说明：
/// - 无论成功或失败，都会记录开始/结束时间，便于统计启动耗时。
/// - 失败时会携带 [error] 与 [stackTrace]。
final class StartupTaskResult {
  const StartupTaskResult({
    required this.id,
    required this.phase,
    required this.startedAt,
    required this.endedAt,
    this.error,
    this.stackTrace,
  });

  final String id;
  final StartupPhase phase;
  final DateTime startedAt;
  final DateTime endedAt;
  final Object? error;
  final StackTrace? stackTrace;

  Duration get duration => endedAt.difference(startedAt);

  bool get isSuccess => error == null;
}

/// 启动报告（一次 run 的汇总结果）。
///
/// 用途：
/// - 为上层提供可观测性：哪些任务耗时、哪些任务失败、总启动耗时等。
/// - 便于在应用层决定后续策略（例如上报启动指标、展示错误页）。
final class StartupReport {
  const StartupReport({
    required this.startedAt,
    required this.endedAt,
    required this.results,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final List<StartupTaskResult> results;

  Duration get duration => endedAt.difference(startedAt);

  bool get hasFailure => results.any((r) => !r.isSuccess);
}

/// 启动执行异常：关键任务失败时抛出。
///
/// 特点：
/// - 携带当次 [report]，即使失败也能看到“已完成/已失败”的任务列表。
/// - [cause]/[stackTrace] 指向触发失败的具体异常，便于定位根因。
final class StartupRunException implements Exception {
  const StartupRunException({
    required this.message,
    required this.report,
    this.cause,
    this.stackTrace,
  });

  final String message;
  final StartupReport report;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => 'StartupRunException: $message';
}

/// 启动定义异常：任务定义本身不合法时抛出。
///
/// 常见原因：
/// - 重复的 task id
/// - dependsOn 引用了不存在的任务
/// - dependsOn 指向“更晚阶段”的任务
/// - 同一阶段内存在依赖环导致无法调度
final class StartupDefinitionException implements Exception {
  const StartupDefinitionException(this.message);

  final String message;

  @override
  String toString() => 'StartupDefinitionException: $message';
}

/// 启动任务执行器。
///
/// 调度策略：
/// - 分阶段执行：按 [phases] 的顺序依次运行。
/// - 阶段内并发：同一阶段中，所有“依赖已满足”的任务会并发执行。
/// - 失败策略：
///   - critical=true：立刻中断并抛出 [StartupRunException]
///   - critical=false：记录失败但继续执行其它任务
///
/// 日志事件：
/// - startup_task_start
/// - startup_task_success
/// - startup_task_failure
final class StartupRunner {
  StartupRunner({
    List<StartupTask> tasks = const <StartupTask>[],
    StartupContext? context,
  }) : _tasks = tasks,
       _context = context ?? StartupContext();

  final List<StartupTask> _tasks;
  final StartupContext _context;

  /// 执行启动任务并返回报告。
  ///
  /// 默认执行 early/main/late 三阶段。
  ///
  /// 说明：
  /// - 会先做定义校验（_validate）。
  /// - 任务执行过程中会不断记录 [StartupTaskResult]。
  /// - 若出现关键任务失败，会抛出 [StartupRunException]（同时包含当前 report）。
  Future<StartupReport> run({
    List<StartupPhase> phases = const <StartupPhase>[
      StartupPhase.early,
      StartupPhase.main,
      StartupPhase.late,
    ],
  }) async {
    _validate(phases: phases);

    final startedAt = DateTime.now();
    final results = <StartupTaskResult>[];

    final completed = <String>{};
    for (final phase in phases) {
      final phaseTasks = _tasks.where((t) => t.phase == phase).toList();
      if (phaseTasks.isEmpty) continue;

      final remaining = <String, StartupTask>{
        for (final t in phaseTasks) t.id: t,
      };

      while (remaining.isNotEmpty) {
        final ready = remaining.values
            .where((t) => t.dependsOn.every(completed.contains))
            .toList();

        if (ready.isEmpty) {
          throw StartupDefinitionException(
            'No runnable tasks in phase "${phase.name}". Possible cycle or missing dependency.',
          );
        }

        final batch = ready.map((task) async {
          final taskStartedAt = DateTime.now();
          _context.logger?.info(
            'startup_task_start',
            tag: 'startup',
            fields: <String, Object?>{
              'id': task.id,
              'phase': task.phase.name,
              if (task.fields != null) ...task.fields!,
            },
          );

          try {
            final future = Future<void>.sync(() => task.run(_context));
            if (task.timeout != null) {
              await future.timeout(task.timeout!);
            } else {
              await future;
            }

            final taskEndedAt = DateTime.now();
            final result = StartupTaskResult(
              id: task.id,
              phase: task.phase,
              startedAt: taskStartedAt,
              endedAt: taskEndedAt,
            );
            results.add(result);
            completed.add(task.id);
            remaining.remove(task.id);
            _context.logger?.info(
              'startup_task_success',
              tag: 'startup',
              fields: <String, Object?>{
                'id': task.id,
                'phase': task.phase.name,
                'duration_ms': result.duration.inMilliseconds,
                if (task.fields != null) ...task.fields!,
              },
            );
          } catch (e, st) {
            final taskEndedAt = DateTime.now();
            final result = StartupTaskResult(
              id: task.id,
              phase: task.phase,
              startedAt: taskStartedAt,
              endedAt: taskEndedAt,
              error: e,
              stackTrace: st,
            );
            results.add(result);

            _context.logger?.error(
              'startup_task_failure',
              tag: 'startup',
              error: e,
              stackTrace: st,
              fields: <String, Object?>{
                'id': task.id,
                'phase': task.phase.name,
                'duration_ms': result.duration.inMilliseconds,
                'critical': task.critical,
                if (task.fields != null) ...task.fields!,
              },
            );

            if (task.critical) {
              final endedAt = DateTime.now();
              throw StartupRunException(
                message: 'Critical startup task failed: ${task.id}',
                report: StartupReport(
                  startedAt: startedAt,
                  endedAt: endedAt,
                  results: List<StartupTaskResult>.unmodifiable(results),
                ),
                cause: e,
                stackTrace: st,
              );
            } else {
              completed.add(task.id);
              remaining.remove(task.id);
            }
          }
        }).toList();

        await Future.wait(batch);
      }
    }

    final endedAt = DateTime.now();
    return StartupReport(
      startedAt: startedAt,
      endedAt: endedAt,
      results: List<StartupTaskResult>.unmodifiable(results),
    );
  }

  /// 校验任务定义的合法性。
  ///
  /// 规则：
  /// - phases 之外的任务会被忽略（允许应用只跑部分阶段）。
  /// - task id 必须唯一。
  /// - dependsOn 必须引用存在的任务。
  /// - dependsOn 不能指向“更晚阶段”的任务（避免跨阶段反向依赖）。
  void _validate({required List<StartupPhase> phases}) {
    final phaseOrder = <StartupPhase, int>{
      for (var i = 0; i < phases.length; i++) phases[i]: i,
    };

    final tasksById = <String, StartupTask>{};
    for (final task in _tasks) {
      if (!phaseOrder.containsKey(task.phase)) continue;
      final existing = tasksById[task.id];
      if (existing != null) {
        throw StartupDefinitionException('Duplicate task id: ${task.id}');
      }
      tasksById[task.id] = task;
    }

    for (final task in tasksById.values) {
      for (final dep in task.dependsOn) {
        final depTask = tasksById[dep];
        if (depTask == null) {
          throw StartupDefinitionException(
            'Task "${task.id}" depends on missing task "$dep".',
          );
        }
        final depOrder = phaseOrder[depTask.phase]!;
        final taskOrder = phaseOrder[task.phase]!;
        if (depOrder > taskOrder) {
          throw StartupDefinitionException(
            'Task "${task.id}" depends on "$dep" in a later phase.',
          );
        }
      }
    }
  }
}
