import 'package:scaffold_core/core_common/module_event_bus.dart';

/// 应用层事件总线封装（二次封装示例）
///
/// 可以在此添加：
/// - 事件过滤/限流
/// - 统一日志/打点
/// - 生命周期管理（与 AppScope 联动）
class AppEventBus extends ModuleEventBus {}
