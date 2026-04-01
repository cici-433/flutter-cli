# scaffold_core 异常兜底（core_error）设计与使用说明

## 目标与原则

- 提供与具体应用无关的“异常兜底能力”：收敛未处理异常，并统一写入日志
- 不直接依赖任何三方 APM SDK（Sentry/Crashlytics 等）
- 兜底逻辑“尽力而为”：兜底自身不应成为新的崩溃点，也不阻塞主线程

## 模块结构

- 兜底入口与实现：[error_guard.dart](error_guard.dart)
  - ErrorGuard：安装全局兜底钩子 + 统一处理入口
  - ErrorContextProvider：公共上下文提供者

## 捕获范围

ErrorGuard 通过三条链路覆盖不同来源的未处理异常：

1. Flutter 框架错误：FlutterError.onError
   - 常见：build/layout/paint 期间的异常
2. 引擎/平台回调错误：PlatformDispatcher.instance.onError
   - 常见：平台回调、引擎调度链路上的未处理异常
3. Zone 内未处理异步错误：runZonedGuarded
   - 常见：Future/Timer/Stream 链路中漏处理的异常

说明：

- 兜底机制的职责是“记录与上报”，不负责业务恢复策略（弹窗、重试、跳转登录等）
- 业务恢复建议在应用层或状态管理层完成（例如 Riverpod controller 统一处理）

## 快速使用

在应用入口 main() 中包裹 runApp：

```dart
import 'package:scaffold_core/scaffold_core.dart';

void main() {
  ErrorGuard.runGuarded(
    () {
      // WidgetsFlutterBinding.ensureInitialized();
      // runApp(const App());
    },
    logger: AppLogger(),
    contextProvider: () => <String, Object?>{
      'env': 'prod',
      'appVersion': '1.0.0',
      'network': 'wifi',
    },
  );
}
```

## 上报上下文（context）建议

context 用于提升可定位性，但需要控制体积并做好脱敏：

- 推荐字段：
  - route：当前页面路由
  - api：接口名/路径（不要包含敏感 query）
  - traceId/requestId：链路追踪 id
  - userId：业务用户 id（不要上报 token、手机号明文、密码等）
  - network：wifi/4g/none
  - appVersion/buildNumber：版本信息
- 不建议字段：
  - 完整 request/response body（体积大且可能包含敏感信息）
  - token、密码、身份证号、手机号明文等敏感信息

## 如何对接 APM

core_error 本身只负责“收敛异常并写日志”。如果需要上报到 APM，推荐通过 core_logger 的机制统一实现：

- 在 AppLogger 中配置 uploadManager/sink，把 error 日志上传到你的日志服务
- 或在自定义 sink 中将 error 日志转发到 APM SDK（Sentry/Crashlytics 等）

## 常见误区

- 误区 1：在业务里用空 try-catch 吞错
  - 结果：线上问题变成“静默失败”，既不崩溃也不上报，难以定位
  - 建议：要么处理并降级（返回兜底值），要么记录并向上抛出让状态层/兜底可见
- 误区 2：把业务恢复逻辑写进兜底
  - 结果：兜底变得不可控，容易引入循环跳转/重复弹窗
  - 建议：兜底只做记录，上层按场景做恢复策略
