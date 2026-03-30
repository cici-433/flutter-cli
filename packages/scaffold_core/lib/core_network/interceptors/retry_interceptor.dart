import 'dart:math';

import 'package:dio/dio.dart';

/// Dio 重试策略（应用无关）
///
/// 适用于“幂等请求”或“可接受重复提交”的场景。对于可能产生副作用的接口
/// （如下单/支付），建议在应用层通过额外标记或 [RequestOptions.method] 限制重试。
///
/// 特性：
/// - 指数退避：延迟随重试次数指数增长
/// - 最大延迟上限：避免无限增长
/// - 抖动（jitter）：在延迟上加入随机扰动，缓解雪崩重试
/// - 状态码/异常类型白名单：仅对指定错误进行重试
class DioRetryPolicy {
  const DioRetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 300),
    this.maxDelay = const Duration(seconds: 3),
    this.retryOnStatusCodes = const <int>{408, 429, 500, 502, 503, 504},
    this.retryOnTypes = const <DioExceptionType>{
      DioExceptionType.connectionError,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.connectionTimeout,
    },
    this.jitter = true,
  });

  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;
  final Set<int> retryOnStatusCodes;
  final Set<DioExceptionType> retryOnTypes;
  final bool jitter;

  Duration nextDelay(int attempt) {
    final exp = baseDelay * (1 << (attempt - 1));
    final capped = exp > maxDelay ? maxDelay : exp;
    if (!jitter) return capped;
    final ms = capped.inMilliseconds;
    final delta = (ms * 0.3).round();
    final r = Random().nextInt(delta * 2) - delta;
    return Duration(milliseconds: max(0, ms + r));
  }

  bool shouldRetry(DioException err, int attempt) {
    if (attempt >= maxAttempts) return false;
    final type = err.type;
    if (retryOnTypes.contains(type)) return true;
    final status = err.response?.statusCode;
    if (status != null && retryOnStatusCodes.contains(status)) return true;
    return false;
  }
}

/// Dio 重试拦截器（应用无关）
///
/// 工作方式：
/// - 在 [onError] 阶段判断是否满足重试条件
/// - 将当前重试次数写入 `RequestOptions.extra['__retry_attempt__']`
/// - 满足条件则延迟后使用 `_dio.fetch` 重放同一个 RequestOptions
///
/// 注意：
/// - 如果下游拦截器也会修改 RequestOptions，请确保其逻辑在重放时仍然成立
class DioRetryInterceptor extends Interceptor {
  DioRetryInterceptor(this._dio, this._policy);
  final Dio _dio;
  final DioRetryPolicy _policy;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final requestOptions = err.requestOptions;
    var attempt = (requestOptions.extra['__retry_attempt__'] as int?) ?? 0;
    attempt += 1;
    requestOptions.extra['__retry_attempt__'] = attempt;

    if (_policy.shouldRetry(err, attempt)) {
      final delay = _policy.nextDelay(attempt);
      await Future<void>.delayed(delay);
      try {
        final resp = await _dio.fetch(requestOptions);
        return handler.resolve(resp);
      } catch (e) {
        // 继续向下一个拦截器或最终错误
        return handler.next(err);
      }
    }

    return handler.next(err);
  }
}
