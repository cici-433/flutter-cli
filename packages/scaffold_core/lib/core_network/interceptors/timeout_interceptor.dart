import 'package:dio/dio.dart';

/// Dio 超时配置拦截器（应用无关）
///
/// 作用：
/// - 在请求发出前统一设置 connect/send/receive 超时
/// - 支持“只在未配置时填默认值”或“强制覆盖已有超时”
///
/// 覆盖优先级：
/// - 如果 RequestOptions.extra 中存在 `connectTimeout/sendTimeout/receiveTimeout` 且为 Duration，则优先使用
/// - 否则使用拦截器构造参数
/// - 否则回退到 RequestOptions 上已有的超时配置
class DioTimeoutInterceptor extends Interceptor {
  DioTimeoutInterceptor({
    this.connectTimeout,
    this.sendTimeout,
    this.receiveTimeout,
    this.overrideExisting = false,
  });

  final Duration? connectTimeout;
  final Duration? sendTimeout;
  final Duration? receiveTimeout;
  final bool overrideExisting;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final connect = options.extra['connectTimeout'];
    final send = options.extra['sendTimeout'];
    final receive = options.extra['receiveTimeout'];

    final connectDuration =
        connect is Duration ? connect : (connectTimeout ?? options.connectTimeout);
    final sendDuration =
        send is Duration ? send : (sendTimeout ?? options.sendTimeout);
    final receiveDuration =
        receive is Duration ? receive : (receiveTimeout ?? options.receiveTimeout);

    if (overrideExisting || options.connectTimeout == null) {
      options.connectTimeout = connectDuration;
    }
    if (overrideExisting || options.sendTimeout == null) {
      options.sendTimeout = sendDuration;
    }
    if (overrideExisting || options.receiveTimeout == null) {
      options.receiveTimeout = receiveDuration;
    }

    handler.next(options);
  }
}
