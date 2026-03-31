import 'dart:convert';

/// KV 存储对上层暴露的最小能力集合。
///
/// 设计目标：
/// - 屏蔽底层 KV 库差异（MMKV/shared_preferences/hive/...）
/// - 上层业务只依赖这一层接口，便于替换与测试
/// - 能力保持“最小且通用”，避免把某个底层库的特性泄露到上层
///
/// 约定：
/// - `get*` 在 key 不存在时返回 `null`
/// - 写入方法均返回 `Future<void>`，便于兼容同步/异步两类底层实现
abstract class KeyValueStore {
  /// 获取 bool，key 不存在返回 null。
  Future<bool?> getBool(String key);

  /// 获取 int，key 不存在返回 null。
  Future<int?> getInt(String key);

  /// 获取 double，key 不存在返回 null。
  Future<double?> getDouble(String key);

  /// 获取 String，key 不存在返回 null。
  Future<String?> getString(String key);

  /// 获取 bytes，key 不存在返回 null。
  Future<List<int>?> getBytes(String key);

  /// 写入 bool。
  Future<void> setBool(String key, bool value);

  /// 写入 int。
  Future<void> setInt(String key, int value);

  /// 写入 double。
  Future<void> setDouble(String key, double value);

  /// 写入 String。
  Future<void> setString(String key, String value);

  /// 写入 bytes。
  Future<void> setBytes(String key, List<int> value);

  /// 删除单个 key。
  Future<void> remove(String key);

  /// 批量删除 keys。
  Future<void> removeMany(Iterable<String> keys);

  /// 清空当前 store 的所有数据。
  Future<void> clear();

  /// 判断 key 是否存在。
  Future<bool> containsKey(String key);

  /// 返回当前 store 的全部 key。
  Future<List<String>> allKeys();

  /// 以 JSON 字符串的形式写入任意可 JSON 序列化对象。
  Future<void> setJson(String key, Object? value) async {
    await setString(key, jsonEncode(value));
  }

  /// 读取 JSON 字符串并反序列化为目标类型。
  ///
  /// 注意：该方法会做一次 `jsonDecode`，并对返回值执行一次 `as T`。
  /// 如果 JSON 结构与 T 不匹配，会抛出类型转换异常。
  Future<T?> getJson<T>(String key) async {
    final raw = await getString(key);
    if (raw == null) return null;
    return jsonDecode(raw) as T;
  }
}

/// 底层 KV 库的适配层。
///
/// - `initialize()`：做一次性的初始化（如果底层库需要）。
/// - `openStore(storeId)`：打开一个逻辑隔离的 store。
///
/// `storeId` 的含义由 driver 决定，推荐用于：
/// - 应用级存储（如 `app`）
/// - 用户级存储（如 `user_<userId>`）
abstract interface class KeyValueStoreDriver {
  Future<void> initialize();
  Future<KeyValueStore> openStore(String storeId);
}
