/// 标准 HTTP 方法集合（应用无关）
enum NetworkMethod { get, post, put, patch, delete }

/// 响应载荷类型
/// - json：按序列化器解析为对象/集合
/// - text：按 UTF-8 文本解码
/// - bytes：直接返回字节数组
enum NetworkResponseType { json, text, bytes }

/// 网络请求模型
///
/// 设计目标：
/// - path 可为相对路径或绝对 URL
/// - headers/query/timeout/responseType 可扩展
class NetworkRequest {
  const NetworkRequest({
    required this.method,
    required this.path,
    this.headers = const <String, String>{},
    this.queryParameters = const <String, String>{},
    this.body,
    this.timeout,
    this.responseType = NetworkResponseType.json,
  });

  final NetworkMethod method;
  final String path;
  final Map<String, String> headers;
  final Map<String, String> queryParameters;
  final Object? body;
  final Duration? timeout;
  final NetworkResponseType responseType;

  /// 派生一个新的请求（便于拦截器链修改）
  NetworkRequest copyWith({
    NetworkMethod? method,
    String? path,
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Object? body,
    Duration? timeout,
    NetworkResponseType? responseType,
  }) {
    return NetworkRequest(
      method: method ?? this.method,
      path: path ?? this.path,
      headers: headers ?? this.headers,
      queryParameters: queryParameters ?? this.queryParameters,
      body: body ?? this.body,
      timeout: timeout ?? this.timeout,
      responseType: responseType ?? this.responseType,
    );
  }
}

/// 网络响应模型
///
/// - data：按响应类型解析出的数据
/// - rawBytes：原始字节（用于调试或二次解析）
class NetworkResponse<T> {
  const NetworkResponse({
    required this.request,
    required this.statusCode,
    required this.headers,
    required this.data,
    required this.rawBytes,
  });

  final NetworkRequest request;
  final int statusCode;
  final Map<String, String> headers;
  final T data;
  final List<int> rawBytes;
}

/// 客户端配置
///
/// - baseUrl：相对路径拼接前缀
/// - defaultHeaders：默认请求头
/// - connectTimeout/receiveTimeout：连接与接收超时
class NetworkClientOptions {
  const NetworkClientOptions({
    this.baseUrl,
    this.defaultHeaders = const <String, String>{},
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 15),
  });

  final String? baseUrl;
  final Map<String, String> defaultHeaders;
  final Duration connectTimeout;
  final Duration receiveTimeout;
}
