# core_storage（KV 存储抽象）

目标：把「业务对 KV 存储的使用」与「底层 KV 库选型/替换」解耦，并提供应用级与用户级两套隔离存储。

## 设计要点

### 1) 可插拔（Driver/Store 两层）

- `KeyValueStore`：对上层暴露的最小 KV 能力集合（读写基础类型、删除、清空、枚举 key）。
- `KeyValueStoreDriver`：对下层 KV 库的适配层，负责初始化与打开某个 store（通过 `storeId` 隔离）。

这样可以做到：

- 默认用 MMKV，但将来切换到 `shared_preferences` / `hive` / `isar` 等，只需要在应用层提供一个新的 `KeyValueStoreDriver` 实现。
- 上层业务、domain/data 模块不需要关心具体用的是哪种 KV 库。

### 2) 应用级 vs 用户级

`CoreStorage` 提供两类 store：

- `app()`：应用级存储（与用户无关），适合全局开关、首次启动标记、AB 实验分流、缓存版本号等。
- `user(userId)`：用户级存储（按 userId 隔离），适合登录态相关信息、用户偏好、用户缓存等。

默认隔离策略为：

- app storeId：`app`
- user storeId：`user_<userId>`

隔离方式是“不同 storeId 对应不同底层存储实例/文件”（MMKV 场景下就是不同的 mmapID）。

### 3) 默认使用 MMKV

默认 driver 为 `MmkvKeyValueStoreDriver`，并在 `initialize()` 时执行 `MMKV.initialize(...)`。

注意：在 Flutter 应用里通常应先执行 `WidgetsFlutterBinding.ensureInitialized()`，再调用 `CoreStorage.initialize()`。

## 使用示例

### 1) 默认（MMKV）

```dart
import 'package:scaffold_core/core_storage/core_storage.dart';

final storage = CoreStorage();

Future<void> bootstrap() async {
  await storage.initialize();

  final app = await storage.app();
  await app.setBool('first_launch', false);

  final user = await storage.user('uid_123');
  await user.setString('nickname', 'Alice');
}
```

### 2) JSON 便捷方法

`KeyValueStore` 提供了 `setJson/getJson`，底层仍然是存储一个 JSON 字符串：

```dart
await app.setJson('profile', {'name': 'Alice', 'age': 18});
final profile = await app.getJson<Map<String, Object?>>('profile');
```

## 如何接入其它 KV 库

实现一个 `KeyValueStoreDriver`：

1) `initialize()`：做底层库初始化（如果需要）。
2) `openStore(storeId)`：根据 `storeId` 返回一个 `KeyValueStore` 实例。

建议：

- `storeId` 用于隔离不同业务域/不同用户的数据；如果底层库不支持多实例，可退化为“key 前缀隔离”（例如把 key 变成 `"$storeId::$key"`）。
- `KeyValueStore` 的接口保持最小集合，避免引入底层库的特性到上层（例如事务、监听等），否则会降低可替换性。

## 文件结构

```
core_storage/
  core_storage.dart        # 对外入口（barrel export）
  key_value_store.dart     # Store/Driver 抽象
  storage.dart             # CoreStorage：app/user 两套 store + 缓存
  mmkv_store.dart          # MMKV driver + store 实现（默认）
```
