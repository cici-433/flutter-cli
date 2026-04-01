import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 自定义占位/错误构建器签名。
typedef CoreImageBuilder =
    Widget Function(BuildContext context, BoxConstraints constraints);

/// 通用图片组件。
///
/// 设计目标：
/// - 提供统一的图片加载、占位、错误与圆角能力
/// - 作为“轻量基座”稳定 API，后续可无感切换底层实现（如 CachedNetworkImage/ExtendedImage）
/// - 专注移动端实现

class CoreImage extends StatelessWidget {
  const CoreImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius,
    this.borderRadius,
    this.headers,
    this.placeholder,
    this.error,
    this.fade = true,
    this.fadeDuration = const Duration(milliseconds: 200),
    this.filterQuality = FilterQuality.low,
    this.clipBehavior = Clip.antiAlias,
  });

  final String? url;

  /// 目标宽度。
  final double? width;

  /// 目标高度。
  final double? height;

  /// 填充策略。
  final BoxFit fit;

  /// 圆角半径（与 [borderRadius] 二选一）。
  final double? radius;

  /// 圆角定义（与 [radius] 二选一）。
  final BorderRadiusGeometry? borderRadius;

  /// 额外网络请求头（如鉴权 Token）。
  final Map<String, String>? headers;

  /// 自定义占位构建器。
  final CoreImageBuilder? placeholder;

  /// 自定义错误视图构建器。
  final CoreImageBuilder? error;

  /// 是否启用淡入动画。
  final bool fade;

  /// 淡入动画时长。
  final Duration fadeDuration;

  /// 采样质量（兼顾性能与清晰度）。
  final FilterQuality filterQuality;

  /// 裁切行为（圆角时默认启用抗锯齿）。
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final target = url;
    final br =
        borderRadius ??
        (radius != null ? BorderRadius.circular(radius!) : null);
    Widget child;
    if (target == null || target.isEmpty) {
      child =
          _buildBuilder(placeholder, context) ?? _defaultPlaceholder(context);
    } else {
      child = _buildNetwork(target);
    }
    if (br != null) {
      child = ClipRRect(
        borderRadius: br,
        clipBehavior: clipBehavior,
        child: child,
      );
    }
    if (width != null || height != null) {
      child = SizedBox(width: width, height: height, child: child);
    }
    return child;
  }

  /// 构建网络图片。
  Widget _buildNetwork(String target) {
    return CachedNetworkImage(
      imageUrl: target,
      httpHeaders: headers,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: fade ? fadeDuration : Duration.zero,
      placeholder: (context, url) =>
          _buildBuilder(placeholder, context) ?? _defaultPlaceholder(context),
      errorWidget: (context, url, errorObj) =>
          _buildBuilder(error, context) ?? _defaultError(context),
      imageBuilder: (context, imageProvider) {
        Widget img = Image(
          image: imageProvider,
          width: width,
          height: height,
          fit: fit,
          filterQuality: filterQuality,
        );
        return img;
      },
    );
  }

  /// 运行构建器（带布局约束）。
  Widget? _buildBuilder(CoreImageBuilder? builder, BuildContext context) {
    if (builder == null) return null;
    return LayoutBuilder(
      builder: (ctx, constraints) => builder(ctx, constraints),
    );
  }

  /// 默认占位视图。
  Widget _defaultPlaceholder(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.6),
      ),
    );
  }

  /// 默认错误视图。
  Widget _defaultError(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 20,
        ),
      ),
    );
  }
}

/// 简单淡入动画封装。
class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.child, required this.duration});
  final Widget child;
  final Duration duration;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _animation, child: widget.child);
  }
}
