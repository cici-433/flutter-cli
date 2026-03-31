# core_logger

## 目标

core_logger 提供一个与具体应用无关的日志基础能力，满足以下需求：

- 支持不同等级的日志输出
- 支持对日志内容进行转换（脱敏、补字段、统一 tag 等）
- 支持输出到不同目标（调试输出、控制台、文件、上传）
- 支持 flush/close，便于在应用退出或后台切前台时保证日志落盘/上传

## 核心设计

采用“流水线”式处理：

`LogRecord -> Transformer(s) -> Formatter -> Sink(s)`

对应类型：

- `LogRecord`：结构化日志记录（时间、级别、tag、message、error、stackTrace、fields）
- `LogTransformer`：内容转换器（输入/输出都是 LogRecord）
- `LogFormatter`：格式化器（将 LogRecord 转为最终输出载荷，例如字符串/JSON）
- `LogSink`：输出目标（写到某个平台/文件/上传）

## 日志级别

`LogLevel` 从低到高：

- trace / debug：调试信息
- info：业务关键路径信息（默认最低输出级别）
- warning：可恢复异常、降级、重试等告警
- error：错误
- fatal：致命错误

过滤规则：

- `AppLogger(minLevel: ...)` 控制 Logger 的最低输出等级
- 每个 `LogSink` 也有自己的 `minLevel`，用于二次过滤（例如：开发期全量输出，生产期仅 error 以上上传）

## 默认实现

### Formatter

- `LineLogFormatter`：一行文本，可读性好（默认）
- `JsonLogFormatter`：输出 JSON 字符串，便于写文件与上传

### Sink

- `DeveloperLogSink`：基于 `dart:developer.log`，适合调试期（Flutter 下可在控制台/Android logcat/DevTools 查看）
- `ConsoleLogSink`：写到 stdout，适合 CLI/测试环境
- `FileLogSink`：写入文件并做简单轮转（maxBytes/maxFiles），适合生产环境落盘

### Upload

- `LogUploadManager`：只负责“收集待上传日志 + 主动触发上传”，不会在写日志时自动发网络请求
- `LogUploader`：由应用层实现的上传器接口（对接后端/第三方日志平台）

#### 上传机制细节

上传能力被设计为“独立模块”，目的是避免：

- 每打印一条日志就触发一次网络请求
- 把“日志写入”和“网络上传”的职责耦合在一起

因此 `LogUploadManager` 的行为是：

1) **收集**：每次 `AppLogger.log(...)` 生成并完成 Transformer 链处理后，会把 `LogRecord` 交给 `uploadManager.add(record)`  
   - 只有 `record.level >= uploadManager.minLevel` 的日志会进入上传缓冲区
   - 缓冲区由 `LogUploadStore` 实现，当前推荐使用文件队列（见下文）

2) **出队成批**：当你调用 `await logger.uploadLogs()` 时  
   - 管理器会从上传存储中取出一批，形成 `batch`（快照）
   - 上传期间新写入的日志会继续进入队列，但不会影响正在上传的 `batch`

3) **单飞上传**：同一时间只会有一个上传任务在进行  
   - 如果上一次上传尚未完成，再次调用 `uploadLogs()` 会复用当前 Future，避免并发上传导致重复/乱序

4) **失败回滚**：上传失败不会丢日志  
   - `uploader.upload(batch)` 抛错时，会把该 `batch` 放回队列头部（prepend），便于后续重试

#### 上传存储（内存 vs 文件）

`LogUploadManager` 通过 `LogUploadStore` 抽象统一“待上传日志”的存储来源；当前推荐使用文件队列：

- **文件队列（推荐线上）**：`FileLogUploadStore`
  - 机制：把待上传日志以 JSONL（每行一个 JSON）追加写入 `queueFilePath`，并用 `cursorFilePath` 记录已上传的文件偏移量
  - 上传成功后：通过 **提交 cursor** 来“逻辑删除”已上传日志（下次从新 cursor 继续读取）；当 cursor 足够大时会触发压缩，把已上传部分从文件里物理移除
  - 优点：App 重启不丢；上传逻辑与落盘日志（FileLogSink）解耦
  - 缺点：需要少量文件 IO

说明：

- 上传队列文件（`upload_queue.jsonl`）与业务日志文件（`FileLogSink` 写的 `app.log`）是两套概念：前者只存“待上传的结构化日志”，后者用于本地排查/离线分析
- `uploadManager.add(record)` 在文件队列模式下会触发文件追加写入，为避免影响日志写入性能，这个写入是异步触发的（不会阻塞 `logger.info/error` 等调用）

文件队列的示例配置：

```dart
final logger = AppLogger(
  uploadManager: LogUploadManager(
    uploader: const ApiLogUploader(),
    minLevel: LogLevel.error,
    batchSize: 50,
    store: FileLogUploadStore(
      queueFilePath: 'logs/upload_queue.jsonl',
      cursorFilePath: 'logs/upload_queue.cursor',
    ),
  ),
);
```

也可以使用便捷构造：

```dart
final logger = AppLogger(
  uploadManager: LogUploadManager.file(
    uploader: const ApiLogUploader(),
    minLevel: LogLevel.error,
    batchSize: 50,
    queueFilePath: 'logs/upload_queue.jsonl',
    cursorFilePath: 'logs/upload_queue.cursor',
  ),
);
```

#### 何时触发上传（推荐）

由于上传是“主动触发”，触发时机由业务决定，例如：

- 用户在设置页点击“上传日志”
- 登录/支付等关键流程失败后，立即触发上传（只上传 error/fatal）
- App 切后台或即将退出前调用 `await logger.uploadLogs()` + `await logger.flush()`

#### 与文件落盘的配合

常见组合是：

- `FileLogSink`：全量或 info+ 落盘（便于离线排查、崩溃后仍可读取）
- `LogUploadManager`：仅 error/fatal 进入上传缓冲区（控制上传流量与隐私范围）

#### 上传成功后如何“删除”

上传成功后的删除语义取决于上传存储：

- 文件队列：上传成功后会提交 cursor，相当于把已上传部分标记为已消费；满足条件时会压缩文件做物理删除

如果你希望手动清空待上传日志（例如用户点击“清空待上传”），可以调用：

```dart
logger.clearUploadBuffer();
```

## 使用示例

### 1) 基础用法（默认调试输出）

```dart
final logger = AppLogger();
logger.info('app started', tag: 'app');
```

### 2) 写文件 + JSON + 错误上传

```dart
class ApiLogUploader extends LogUploader {
  const ApiLogUploader();
  @override
  Future<void> upload(List<LogRecord> batch) async {
    // 调用你的上传接口
  }
}

final logger = AppLogger(
  minLevel: LogLevel.debug,
  formatter: const JsonLogFormatter(),
  sinks: [
    const DeveloperLogSink(),
    FileLogSink(
      filePath: 'logs/app.log',
      maxBytes: 5 * 1024 * 1024,
      maxFiles: 3,
      minLevel: LogLevel.info,
    ),
  ],
  uploadManager: LogUploadManager.file(
    uploader: const ApiLogUploader(),
    minLevel: LogLevel.error,
    batchSize: 50,
    queueFilePath: 'logs/upload_queue.jsonl',
    cursorFilePath: 'logs/upload_queue.cursor',
  ),
);
```

在你希望的时机主动上传：

```dart
await logger.uploadLogs();
```

### 3) 日志内容转换（脱敏/补字段）

```dart
class MaskTokenTransformer extends LogTransformer {
  const MaskTokenTransformer();
  @override
  LogRecord transform(LogRecord record) {
    final msg = record.message?.toString().replaceAll(RegExp(r'token=\\S+'), 'token=***');
    return record.copyWith(message: msg);
  }
}
```

```dart
final logger = AppLogger(
  transformers: const [MaskTokenTransformer()],
);
```

## 平台输出说明（Android logcat）

`DeveloperLogSink` 使用 `dart:developer.log` 输出，在 Flutter/Android 下通常能在 logcat 中看到（取决于 IDE/运行方式）。如果需要严格对齐 Android 原生日志级别/Tag 格式，建议在应用层提供一个自定义 `LogSink`，将 `LogRecord` 映射到你期望的格式后再输出。
