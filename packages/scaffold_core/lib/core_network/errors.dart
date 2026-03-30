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
  business,
  unknown,
}

/// 统一错误码集合（应用无关）
///
/// 约定：
/// - 网络层错误使用负数区间，避免与业务码冲突
/// - 业务错误默认透传业务码（见 [fromType] 的 business 分支）
class NetworkErrorCodes {
  static const int timeout = -1001;
  static const int network = -1002;
  static const int cancelled = -1003;
  static const int badResponse = -1004;
  static const int serialization = -1005;
  static const int unknown = -1099;

  static int fromType(
    NetworkErrorType type, {
    int? businessCode,
  }) {
    switch (type) {
      case NetworkErrorType.timeout:
        return NetworkErrorCodes.timeout;
      case NetworkErrorType.network:
        return NetworkErrorCodes.network;
      case NetworkErrorType.cancelled:
        return NetworkErrorCodes.cancelled;
      case NetworkErrorType.badResponse:
        return NetworkErrorCodes.badResponse;
      case NetworkErrorType.serialization:
        return NetworkErrorCodes.serialization;
      case NetworkErrorType.business:
        return businessCode ?? NetworkErrorCodes.unknown;
      case NetworkErrorType.unknown:
        return NetworkErrorCodes.unknown;
    }
  }
}

/// 统一网络异常
///
/// - request：触发异常的原始请求
/// - statusCode/responseHeaders：底层响应信息（如可用）
/// - cause：底层原始异常对象
/// - businessCode/businessPayload：业务错误的补充信息（用于上层决策或埋点）
class NetworkException implements Exception {
  const NetworkException({
    required this.type,
    required this.message,
    required this.request,
    this.code,
    this.statusCode,
    this.responseHeaders,
    this.businessCode,
    this.businessPayload,
    this.cause,
  });

  final NetworkErrorType type;
  final String message;
  final NetworkRequest request;
  final int? code;
  final int? statusCode;
  final Map<String, String>? responseHeaders;
  final int? businessCode;
  final Object? businessPayload;
  final Object? cause;

  int get errorCode =>
      code ?? NetworkErrorCodes.fromType(type, businessCode: businessCode);

  @override
  String toString() {
    final code = statusCode == null ? '' : ' (status=$statusCode)';
    return 'NetworkException(${type.name}, code=$errorCode)$code: $message';
  }
}
