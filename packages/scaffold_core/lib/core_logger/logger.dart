import 'dart:developer' as developer;

/// 简单日志器（应用无关）
///
/// 在不同应用中可以：
/// - 直接复用（开发阶段）
/// - 在应用层二次封装（增加打点、过滤、采样）
///
/// 说明：
/// - 该实现基于 `dart:developer`，更适合调试与开发期日志
/// - 生产环境建议在应用层对接统一日志平台，并控制日志体积与敏感信息
class AppLogger {
  /// 信息级日志
  void info(String message) {
    developer.log(message, name: 'INFO');
  }
}
