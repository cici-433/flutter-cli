# CoreImage 设计说明

## 目标

- 提供跨页面统一的图片展示体验：占位、错误、圆角、淡入动画
- 在移动端使用 `CachedNetworkImage` 获取磁盘缓存与更稳定的加载表现
- 不支持 Web（仅移动端）

## 设计取舍

- 默认在移动端启用 `CachedNetworkImage`（含磁盘缓存）
- 保持组件 API 稳定：后续如需高级能力（裁切/手势/长图/GIF），可平滑切换到 ExtendedImage

## API 概览

```dart
class CoreImage extends StatelessWidget {
  const CoreImage({
    required String? url,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    double? radius,
    BorderRadiusGeometry? borderRadius,
    Map<String, String>? headers,
    CoreImageBuilder? placeholder,
    CoreImageBuilder? error,
    bool fade = true,
    Duration fadeDuration = const Duration(milliseconds: 200),
    FilterQuality filterQuality = FilterQuality.low,
    Clip clipBehavior = Clip.antiAlias,
  });
}
```

关键参数：
- `url`：图片地址（为空或空串时直接展示占位）
- `radius / borderRadius`：二选一，统一圆角风格
- `placeholder / error`：自定义占位与错误视图（接收 `BuildContext` 与 `BoxConstraints`）
- `headers`：支持私有资源的鉴权请求头
- `fade`/`fadeDuration`：渐显效果
- `filterQuality`：采样质量（兼顾性能与清晰度）

## 使用场景

### 基本使用

```dart
CoreImage(
  url: 'https://example.com/img.png',
  width: 120,
  height: 120,
)
```

### 统一圆角 + 自定义占位/错误

```dart
CoreImage(
  url: 'https://example.com/img.png',
  width: 120,
  height: 120,
  radius: 12,
  placeholder: (ctx, c) => const Center(
    child: SizedBox.square(
      dimension: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  ),
  error: (ctx, c) => const Center(
    child: Icon(Icons.broken_image_outlined, size: 20),
  ),
)
```

### 鉴权请求头

```dart
CoreImage(
  url: 'https://example.com/private/img.png',
  headers: {'Authorization': 'Bearer <token>'},
  fit: BoxFit.cover,
)
```

## 扩展与演进

- 磁盘缓存：当前已在移动端使用 CachedNetworkImage；如需自定义缓存策略，可注入自定义 CacheManager
- 高级能力：按需接入 ExtendedImage 实现裁切、双击缩放、长图优化与 GIF 控制（不破坏现有 API）
- 统一策略：在工程级别注入 CDN 参数构造器（宽高、格式、质量），或在组件外通过 URL 拼接实现

## 注意事项

- 避免将敏感信息写入 URL（即便启用了缓存库）
- 复杂需求（如占位骨架屏、Hero 动画）建议在外层组合而非塞进组件内部，保持单一职责
