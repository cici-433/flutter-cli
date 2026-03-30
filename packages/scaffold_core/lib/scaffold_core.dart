/// Scaffold Core
///
/// 一个与具体应用无关的基础框架库，提供“可插拔”的通用技术能力：
/// - 事件总线（core_common）
/// - 日志（core_logger）
/// - 网络客户端（core_network）
///
/// 设计原则：
/// - 不依赖 Flutter/App 代码，只使用 Dart
/// - 暴露最小 API，方便在不同应用中复用与二次封装
library scaffold_core;
export 'core_common/module_event_bus.dart';
export 'core_logger/logger.dart';
export 'core_network/network_client.dart';
export 'core_network/types.dart';
export 'core_network/errors.dart';
export 'core_network/serializer.dart';
export 'core_network/interceptors/logging_interceptor.dart';
export 'core_network/interceptors/retry_interceptor.dart';
export 'core_network/interceptors/retry_interceptor.dart';
