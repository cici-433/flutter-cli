import 'dart:developer' as developer;

/// 简单日志器（应用无关）
///
/// 在不同应用中可以：
/// - 直接复用（开发阶段）
/// - 在应用层二次封装（增加打点、过滤、采样）
class AppLogger {
  /// 信息级日志
  void info(String message) {
    developer.log(message, name: 'INFO');
  }
}
