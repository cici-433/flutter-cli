import 'dart:async';

/// 模块间事件模型（应用无关）
///
/// 用于在应用内不同模块之间传递轻量事件。事件载荷可以是文案或 ID，
/// 如需传递复杂对象，建议自定义字段或在应用层二次封装。
class ModuleEvent {
  /// 事件构造
  const ModuleEvent({
    required this.sourceModule,
    required this.topic,
    required this.message,
    required this.timestamp,
  });

  /// 事件来源模块标识（如 'login'、'order'）
  final String sourceModule;

  /// 事件主题（如 'auth_changed'、'orders_synced'）
  final String topic;

  /// 文本消息或简要说明
  final String message;

  /// 事件时间戳
  final DateTime timestamp;
}

/// 模块事件总线（发布-订阅）
///
/// - 广播模式：允许多个订阅者同时接收事件
/// - 与具体 UI/框架无关：可在任意 Dart 环境使用
class ModuleEventBus {
  final StreamController<ModuleEvent> _controller =
      StreamController<ModuleEvent>.broadcast();

  /// 事件流（订阅入口）
  Stream<ModuleEvent> get stream => _controller.stream;

  /// 发布事件
  void publish(ModuleEvent event) {
    _controller.add(event);
  }

  /// 释放资源（通常在应用退出或注入生命周期结束时调用）
  void dispose() {
    _controller.close();
  }
}
