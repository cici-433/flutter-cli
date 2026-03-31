import 'package:mmkv/mmkv.dart';
import 'key_value_store.dart';

/// MMKV 的 driver 实现。
///
/// 设计点：
/// - `initialize()` 会调用 `MMKV.initialize(...)`，并做 Future 复用，避免重复初始化
/// - `openStore(storeId)` 使用 `MMKV(storeId, ...)` 创建/打开对应的实例
///
/// 说明：
/// - `storeId` 会映射到 MMKV 的 `mmapID`，因此不同 storeId 数据天然隔离（不同文件）
/// - 可通过 `defaultCryptKey/cryptKeyForStore` 为不同 store 配置加密 key
class MmkvKeyValueStoreDriver implements KeyValueStoreDriver {
  MmkvKeyValueStoreDriver({
    this.rootDir,
    this.groupDir,
    this.logLevel = MMKVLogLevel.Info,
    this.handler,
    this.defaultCryptKey,
    this.cryptKeyForStore,
    this.aes256 = false,
  });

  final String? rootDir;
  final String? groupDir;
  final MMKVLogLevel logLevel;
  final MMKVHandler? handler;
  final String? defaultCryptKey;
  final String? Function(String storeId)? cryptKeyForStore;
  final bool aes256;

  Future<void>? _initializeFuture;

  @override
  Future<void> initialize() {
    _initializeFuture ??= MMKV.initialize(
      rootDir: rootDir,
      groupDir: groupDir,
      logLevel: logLevel,
      handler: handler,
    );
    return _initializeFuture!;
  }

  @override
  Future<KeyValueStore> openStore(String storeId) async {
    final cryptKey = cryptKeyForStore?.call(storeId) ?? defaultCryptKey;
    return MmkvKeyValueStore(MMKV(storeId, cryptKey: cryptKey, aes256: aes256));
  }
}

/// 基于 MMKV 的 [KeyValueStore] 实现。
///
/// 注意：
/// - MMKV 的 bool/int/double decode API 有默认值参数，无法直接区分“未写入”和“写入默认值”。
///   因此这里通过 `containsKey` 来判断 key 是否存在，保证 `get*` 在 key 不存在时返回 null。
class MmkvKeyValueStore extends KeyValueStore {
  MmkvKeyValueStore(this._mmkv);

  final MMKV _mmkv;

  @override
  Future<bool?> getBool(String key) async {
    if (!_mmkv.containsKey(key)) return null;
    return _mmkv.decodeBool(key);
  }

  @override
  Future<int?> getInt(String key) async {
    if (!_mmkv.containsKey(key)) return null;
    return _mmkv.decodeInt(key);
  }

  @override
  Future<double?> getDouble(String key) async {
    if (!_mmkv.containsKey(key)) return null;
    return _mmkv.decodeDouble(key);
  }

  @override
  Future<String?> getString(String key) async {
    return _mmkv.decodeString(key);
  }

  @override
  Future<List<int>?> getBytes(String key) async {
    final buffer = _mmkv.decodeBytes(key);
    if (buffer == null) return null;
    final list = buffer.asList();
    buffer.destroy();
    return list?.toList();
  }

  @override
  Future<void> setBool(String key, bool value) async {
    _mmkv.encodeBool(key, value);
  }

  @override
  Future<void> setInt(String key, int value) async {
    _mmkv.encodeInt(key, value);
  }

  @override
  Future<void> setDouble(String key, double value) async {
    _mmkv.encodeDouble(key, value);
  }

  @override
  Future<void> setString(String key, String value) async {
    _mmkv.encodeString(key, value);
  }

  @override
  Future<void> setBytes(String key, List<int> value) async {
    final buffer = MMBuffer.fromList(value);
    _mmkv.encodeBytes(key, buffer);
    buffer?.destroy();
  }

  @override
  Future<void> remove(String key) async {
    _mmkv.removeValue(key);
  }

  @override
  Future<void> removeMany(Iterable<String> keys) async {
    _mmkv.removeValues(keys.toList(growable: false));
  }

  @override
  Future<void> clear() async {
    _mmkv.clearAll();
  }

  @override
  Future<bool> containsKey(String key) async {
    return _mmkv.containsKey(key);
  }

  @override
  Future<List<String>> allKeys() async {
    return _mmkv.allKeys;
  }
}
