import 'dart:math';

import 'package:dio/dio.dart';

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
