import 'dart:async';

import 'package:dio/dio.dart';

/// Dio Header 注入拦截器（应用无关）
///
/// 使用场景：
/// - 注入固定请求头（如 appVersion、platform）
/// - 动态生成请求头（如 locale、traceId、deviceId）
///
/// 合并策略：
/// - 先合并 [staticHeaders]
/// - 再合并 [headersBuilder] 动态生成的 headers（会覆盖同名静态 header）
/// - 最终写入到 [RequestOptions.headers]
///
/// 跳过策略：
/// - 通过 [shouldSkip] 返回 true 跳过注入
class DioHeaderInjectorInterceptor extends Interceptor {
  DioHeaderInjectorInterceptor({
    this.staticHeaders = const <String, String>{},
    FutureOr<Map<String, String>> Function(RequestOptions options)? headersBuilder,
    bool Function(RequestOptions options)? shouldSkip,
  })  : _headersBuilder = headersBuilder,
        _shouldSkip = shouldSkip;

  final Map<String, String> staticHeaders;
  final FutureOr<Map<String, String>> Function(RequestOptions options)?
      _headersBuilder;
  final bool Function(RequestOptions options)? _shouldSkip;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (_shouldSkip?.call(options) == true) {
      handler.next(options);
      return;
    }

    final merged = <String, String>{...staticHeaders};
    final dynamicHeaders = _headersBuilder == null
        ? const <String, String>{}
        : await _headersBuilder.call(options);
    merged.addAll(dynamicHeaders);

    merged.forEach((k, v) {
      options.headers[k] = v;
    });
    handler.next(options);
  }
}
