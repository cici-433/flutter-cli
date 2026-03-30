import 'types.dart';

/// 网络错误类型归一化
///
/// 用于屏蔽底层库差异，统一在上层处理。
enum NetworkErrorType {
  timeout,
  network,
  badResponse,
  cancelled,
  serialization,
  unknown,
}

/// 统一网络异常
///
/// - request：触发异常的原始请求
/// - statusCode/responseHeaders：底层响应信息（如可用）
/// - cause：底层原始异常对象
class NetworkException implements Exception {
  const NetworkException({
    required this.type,
    required this.message,
    required this.request,
    this.statusCode,
    this.responseHeaders,
    this.cause,
  });

  final NetworkErrorType type;
  final String message;
  final NetworkRequest request;
  final int? statusCode;
  final Map<String, String>? responseHeaders;
  final Object? cause;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' (status=$statusCode)';
    return 'NetworkException(${type.name})$code: $message';
  }
}
