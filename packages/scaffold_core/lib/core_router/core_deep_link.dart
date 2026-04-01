import 'dart:async';

import 'package:uni_links/uni_links.dart' as uni_links;

import 'core_route_guard.dart';
import 'guarded_core_router.dart';

/// 深链来源抽象。
///
/// 该接口把平台插件与核心路由协调逻辑解耦，便于替换实现或编写测试桩。
abstract class CoreDeepLinkSource {
  /// 获取应用首次启动时携带的 URI。
  Future<Uri?> getInitialUri();

  /// 获取应用运行过程中收到的 URI 流。
  Stream<Uri?> get uriStream;
}

/// 基于 `uni_links` 的默认深链来源实现。
class UniLinksDeepLinkSource extends CoreDeepLinkSource {
  @override
  Future<Uri?> getInitialUri() async {
    try {
      return await uni_links.getInitialUri();
    } on FormatException {
      return null;
    }
  }

  @override
  Stream<Uri?> get uriStream => uni_links.uriLinkStream.handleError((_) {});
}

/// 未命中站内路由时的回退处理器。
typedef CoreDeepLinkFallbackHandler =
    FutureOr<void> Function(Uri originalUri, Uri? fallbackUri);

/// 深链协调器。
///
/// 职责：
/// - 监听冷启动和运行中到达的深链
/// - 过滤 scheme/host
/// - 尝试分发到站内路由
/// - 失败时执行 H5 或其他自定义兜底逻辑
class CoreDeepLinkCoordinator {
  CoreDeepLinkCoordinator({
    required this.router,
    required this.source,
    this.mode = CoreNavigationMode.go,
    this.allowedSchemes = const <String>{},
    this.allowedHosts = const <String>{},
    this.fallbackUriBuilder,
    this.onUnhandledUri,
  });

  /// 支持守卫与防重入的路由实例。
  final GuardedCoreRouter router;

  /// 深链来源。
  final CoreDeepLinkSource source;

  /// 深链命中站内路由时采用的导航模式。
  final CoreNavigationMode mode;

  /// 允许进入深链处理流程的 scheme 白名单。
  final Set<String> allowedSchemes;

  /// 允许进入深链处理流程的 host 白名单。
  final Set<String> allowedHosts;

  /// 站内未命中时，用于生成 H5 兜底地址的构建器。
  final Uri? Function(Uri originalUri)? fallbackUriBuilder;

  /// 未命中站内路由时的最终兜底处理器。
  final CoreDeepLinkFallbackHandler? onUnhandledUri;

  StreamSubscription<Uri?>? _subscription;
  bool _started = false;

  /// 启动深链监听。
  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;

    await _handleUri(await source.getInitialUri());
    _subscription = source.uriStream.listen((uri) {
      unawaited(_handleUri(uri));
    });
  }

  /// 停止深链监听并释放订阅资源。
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }

  /// 处理单个 URI。
  Future<void> _handleUri(Uri? uri) async {
    if (uri == null || !_isAllowed(uri)) {
      return;
    }

    final handled = await router.handleUri(uri, mode: mode);
    if (handled) {
      return;
    }

    await onUnhandledUri?.call(uri, fallbackUriBuilder?.call(uri));
  }

  /// 判断当前 URI 是否满足白名单约束。
  bool _isAllowed(Uri uri) {
    if (allowedSchemes.isNotEmpty && !allowedSchemes.contains(uri.scheme)) {
      return false;
    }
    if (allowedHosts.isNotEmpty &&
        uri.host.isNotEmpty &&
        !allowedHosts.contains(uri.host)) {
      return false;
    }
    return true;
  }
}
