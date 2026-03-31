/// core_storage
///
/// 一个“可插拔”的 KV 存储抽象层：
/// - 默认使用 MMKV（高性能、同步读写）
/// - 可通过 [KeyValueStoreDriver] 替换底层 KV 库（如 shared_preferences/hive/isar 等）
/// - 提供“应用级存储”和“用户级存储”两套隔离的 Store
///
/// 对上层业务建议只依赖：
/// - [CoreStorage]
/// - [KeyValueStore]
///
/// 具体底层实现（如 MMKV）可以在应用层按需替换/配置。
library;

export 'key_value_store.dart';
export 'mmkv_store.dart';
export 'storage.dart';
