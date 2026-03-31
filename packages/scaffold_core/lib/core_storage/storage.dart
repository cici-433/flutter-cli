import 'key_value_store.dart';
import 'mmkv_store.dart';

/// 统一存储入口：提供应用级与用户级两套 store。
///
/// 为什么需要它：
/// - 统一收口“初始化时机”（如 MMKV 必须 initialize 后才能使用）
/// - 统一收口“隔离规则”（app/user 的 storeId 生成）
/// - 统一做 store 的缓存（避免重复打开/重复创建底层实例）
///
/// 默认行为：
/// - 使用 [MmkvKeyValueStoreDriver] 作为底层实现（即默认使用 MMKV）
/// - `appStoreId` 默认为 `app`
/// - 用户 storeId 默认为 `user_<userId>`
class CoreStorage {
  CoreStorage({
    KeyValueStoreDriver? driver,
    this.appStoreId = 'app',
    this.userStoreIdBuilder = _defaultUserStoreId,
  }) : _driver = driver ?? MmkvKeyValueStoreDriver();

  /// 底层实现适配器。
  final KeyValueStoreDriver _driver;

  /// 应用级 store 的 id。
  final String appStoreId;

  /// 用户级 store 的 id 生成规则。
  final String Function(String userId) userStoreIdBuilder;

  Future<void>? _initializeFuture;
  final Map<String, Future<KeyValueStore>> _stores = {};

  /// 初始化底层库（如 MMKV.initialize）。
  ///
  /// 多次调用会复用同一个 Future，避免重复初始化。
  Future<void> initialize() {
    _initializeFuture ??= _driver.initialize();
    return _initializeFuture!;
  }

  /// 获取应用级 store（与用户无关，跨登录态复用）。
  Future<KeyValueStore> app() {
    return _getOrOpen(appStoreId);
  }

  /// 获取用户级 store（按 userId 隔离）。
  Future<KeyValueStore> user(String userId) {
    return _getOrOpen(userStoreIdBuilder(userId));
  }

  /// 清空某个用户的 store。
  ///
  /// 说明：这里是“逻辑清空”。如果底层库支持删除文件级存储，也可以在自定义 driver 中实现更彻底的删除。
  Future<void> clearUser(String userId) async {
    final store = await user(userId);
    await store.clear();
  }

  Future<KeyValueStore> _getOrOpen(String storeId) {
    return _stores.putIfAbsent(storeId, () async {
      await initialize();
      return _driver.openStore(storeId);
    });
  }

  static String _defaultUserStoreId(String userId) => 'user_$userId';
}
