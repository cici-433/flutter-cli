# scaffold_core 启动任务（core_startup）设计与使用说明

## 目标与原则

- 提供与具体应用无关的“启动任务编排”能力：统一管理启动时各种服务初始化
- 通过阶段与依赖关系，明确启动顺序与可并发部分，减少启动逻辑散落与耦合
- 以日志与报告输出启动过程，便于性能分析与问题定位
- core_startup 不做业务恢复策略，只提供调度与观测基础能力

## 适用场景

- 存储初始化（CoreStorage.initialize）
- 恢复登录态/会话（读取本地 token/刷新 session）
- 网络层初始化（配置 baseUrl、注入拦截器、预热 DNS 等）
- 路由/深链初始化（路由注册、守卫装配、deep link source）
- 启动配置拉取（remote config、灰度开关）
- 预热任务（预取必要数据、warmup 埋点、预缓存）

## 模块结构

- 启动任务定义与执行器：[startup.dart](startup.dart)
  - StartupPhase：启动阶段（early/main/late）
  - StartupTask：任务定义（id/phase/dependsOn/critical/timeout）
  - StartupRunner：执行器（阶段执行 + 阶段内依赖调度并发）
  - StartupContext：任务间共享上下文（可选 logger + key/value）
  - StartupReport / StartupTaskResult：执行报告与单任务结果

## 核心概念

### StartupPhase（阶段）

- early：尽量只放“必须且稳定”的基础设施初始化
- main：主要初始化（可包含并发任务）
- late：可延后、非关键的任务（不影响用户进入主流程）

应用可以选择只执行部分阶段，例如首屏只跑 early/main，进入首页后再跑 late。

### StartupTask（任务）

关键字段：

- id：唯一标识；同时用于被 dependsOn 引用
- phase：所属阶段
- dependsOn：依赖任务 id；同阶段内会根据依赖关系进行调度
- critical：是否关键任务
  - true：失败会抛 StartupRunException，中断启动
  - false：失败只记录，不阻断其它任务
- timeout：单任务超时兜底（避免启动卡死）

### StartupContext（上下文）

StartupContext 用于任务间共享少量对象与状态，典型用途：

- 注入 logger 供启动过程打点
- 保存已初始化的依赖，供后续任务复用（例如 storage、配置快照）

注意：建议避免存放大对象/大量数据。

## 调度与失败策略

- 分阶段执行：按 phases 顺序依次执行
- 阶段内并发：
  - 每一轮会选出“依赖已满足”的任务集合并发执行
  - 执行结束后标记完成，再继续下一轮
- 失败处理：
  - critical=true：立刻中断并抛 StartupRunException（异常中包含 report）
  - critical=false：记录失败但继续执行

## 日志与观测

若 StartupContext 配置了 logger，Runner 会输出三类结构化日志事件：

- startup_task_start：任务开始
- startup_task_success：任务成功（含 duration_ms）
- startup_task_failure：任务失败（含 duration_ms、critical、error/stackTrace）

这些日志适合作为：

- 启动耗时分析（按任务拆分）
- 启动失败定位（失败任务 id + 堆栈）

## 快速使用

```dart
import 'package:scaffold_core/scaffold_core.dart';

final logger = AppLogger();

final runner = StartupRunner(
  context: StartupContext(logger: logger),
  tasks: <StartupTask>[
    StartupTask(
      id: 'storage_init',
      phase: StartupPhase.early,
      run: (ctx) async {
        // 初始化存储
      },
    ),
    StartupTask(
      id: 'session_restore',
      phase: StartupPhase.main,
      dependsOn: const ['storage_init'],
      critical: false,
      timeout: const Duration(seconds: 2),
      run: (ctx) async {
        // 恢复登录态（失败不阻断）
      },
    ),
    StartupTask(
      id: 'warmup',
      phase: StartupPhase.late,
      critical: false,
      run: (ctx) async {
        // 预热任务（可延后）
      },
    ),
  ],
);

final report = await runner.run();
```

## 常见约定建议

- id 命名：使用稳定前缀（如 storage_init / auth_restore / router_init），便于日志搜索
- critical 默认 true：只有“明确可忽略”的任务才设为 false
- 任务超时：对外部依赖（磁盘/网络/平台回调）建议配置 timeout
- late 阶段：尽量不要阻塞首屏，适合放非关键预热

