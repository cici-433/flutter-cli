import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'crypto.dart';
import 'errors.dart';
import 'serializer.dart';
import 'types.dart';

/// 面向大型项目的网络客户端入口（应用无关）
///
/// 关键设计：
/// - 统一请求/响应/错误模型
/// - 固定使用 Dio 作为底层引擎（支持配置 BaseOptions/拦截器）
/// - 序列化策略可替换（默认 JSON）
/// - 支持可插拔的请求/响应加解密（由应用层实现，core 负责调用时机）
///
/// 与 Dio 的关系：
/// - 本类将 [NetworkRequest] 映射为 Dio 的 [RequestOptions] 并发起请求
/// - Dio 拦截器链照常生效（Header/鉴权/日志/重试/超时等建议通过 Dio Interceptor 注入）
/// - 响应统一以 bytes 形式取回，再由 [NetworkSerializer] 按 [NetworkResponseType] 解码
class NetworkClient {
  NetworkClient({
    NetworkClientOptions options = const NetworkClientOptions(),
    NetworkSerializer serializer = const JsonNetworkSerializer(),

    /// 应用层提供的加解密实现（可选）。
    ///
    /// 若为 null，则不启用加解密流程。
    NetworkCrypto? crypto,
    Dio? dio,
    BaseOptions? baseOptions,
    List<Interceptor>? dioInterceptors,
  }) : _options = options,
       _serializer = serializer,
       _crypto = crypto,
       _dio =
           dio ??
           Dio(
             baseOptions ??
                 BaseOptions(
                   baseUrl: options.baseUrl ?? '',
                   connectTimeout: options.connectTimeout,
                   receiveTimeout: options.receiveTimeout,
                   headers: options.defaultHeaders,
                   responseType: ResponseType.bytes,
                 ),
           ) {
    if (dioInterceptors != null && dioInterceptors.isNotEmpty) {
      _dio.interceptors.addAll(dioInterceptors);
    }
  }

  final NetworkClientOptions _options;
  final NetworkSerializer _serializer;
  final NetworkCrypto? _crypto;
  final Dio _dio;

  /// 统一请求入口
  ///
  /// 流程：
  /// 1. 取消令牌检查
  /// 2. 解析 URL + 合并 headers
  /// 3. 使用 [NetworkSerializer] 序列化请求体（得到 bytes）
  /// 4. 可选：使用 [NetworkCrypto.encrypt] 对请求体加密/签名（由应用层提供）
  /// 5. 通过 Dio 发送请求（拦截器链在 Dio 内部执行）
  /// 6. 可选：使用 [NetworkCrypto.decrypt] 解密响应 bytes（由应用层提供）
  /// 7. 按 responseType 解码为 [NetworkResponse]
  /// 8. 将底层异常归一化为 [NetworkException]
  Future<NetworkResponse<T>> request<T>(
    NetworkRequest request, {
    CancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled ?? false) {
      throw NetworkException(
        type: NetworkErrorType.cancelled,
        message: 'Request cancelled',
        request: request,
      );
    }

    final NetworkRequest current = request;

    try {
      final uri = _resolveUri(current.path, current.queryParameters);
      final headers = <String, String>{
        'accept': '*/*',
        ..._options.defaultHeaders,
        ...current.headers,
      };
      List<int>? bodyBytes;
      if (current.body != null) {
        try {
          headers.putIfAbsent('content-type', () => _serializer.contentType());
          bodyBytes = _serializer.encode(current.body!);
        } catch (e) {
          throw NetworkException(
            type: NetworkErrorType.serialization,
            message: 'Request serialization failed: ${e.toString()}',
            request: current,
            cause: e,
          );
        }
      }

      final crypto = _crypto;
      if (crypto != null && crypto.shouldEncrypt(current)) {
        NetworkCryptoResult result;
        try {
          result = await crypto.encrypt(
            NetworkCryptoRequest(
              uri: uri,
              request: current,
              headers: Map<String, String>.from(headers),
              bodyBytes: bodyBytes,
            ),
          );
        } catch (e) {
          throw NetworkException(
            type: NetworkErrorType.serialization,
            message: 'Request encryption failed: ${e.toString()}',
            request: current,
            cause: e,
          );
        }
        if (result.headers != null && result.headers!.isNotEmpty) {
          headers.addAll(result.headers!);
        }
        bodyBytes = result.bodyBytes ?? bodyBytes;
      }

      final options = Options(
        method: current.method.name.toUpperCase(),
        headers: headers,
        connectTimeout: _options.connectTimeout,
        sendTimeout: _options.connectTimeout,
        receiveTimeout: current.timeout ?? _options.receiveTimeout,
        responseType: ResponseType.bytes,
      );

      final resp = await _dio.requestUri(
        uri,
        data: bodyBytes,
        options: options,
        cancelToken: cancelToken,
      );
      return await _decodeResponse<T>(current, resp);
    } on TimeoutException catch (e) {
      throw NetworkException(
        type: NetworkErrorType.timeout,
        message: 'Network timeout',
        request: current,
        cause: e,
      );
    } on DioException catch (e) {
      throw _mapDioError(e, current);
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw NetworkException(
        type: NetworkErrorType.unknown,
        message: e.toString(),
        request: current,
        cause: e,
      );
    }
  }

  /// 业务协议请求入口（JSON object）
  ///
  /// 适配常见后端返回形态：`{ code, message/msg, data }`。
  ///
  /// - 本方法会强制以 [NetworkResponseType.json] 解析响应
  /// - 如果 JSON 不是 object（Map），会抛出 [NetworkException]（serialization）
  /// - 如果业务码不等于 [successCode]，会抛出 [NetworkException]（business）
  /// - 可通过 [mapper] 完全接管解析（用于复杂协议或字段变体）
  Future<NetworkResponse<ApiResponse<T>>> requestApi<T>(
    NetworkRequest request, {
    CancelToken? cancelToken,
    ApiResponse<T> Function(Map<String, dynamic> json)? mapper,
    int successCode = 0,
    String codeKey = 'code',
    List<String> messageKeys = const <String>['message', 'msg'],
    String dataKey = 'data',
  }) async {
    final resp = await this.request<Object?>(
      request.copyWith(responseType: NetworkResponseType.json),
      cancelToken: cancelToken,
    );

    final data = resp.data;
    if (data is! Map) {
      throw NetworkException(
        type: NetworkErrorType.serialization,
        message: 'Expected JSON object but got ${data.runtimeType}',
        request: resp.request,
        statusCode: resp.statusCode,
        responseHeaders: resp.headers,
      );
    }

    final json = Map<String, dynamic>.from(data);
    final api = mapper != null
        ? mapper(json)
        : ApiResponse<T>(
            code: (json[codeKey] as num?)?.toInt() ?? 0,
            message: _firstString(json, messageKeys) ?? '',
            data: json[dataKey] as T?,
            raw: json,
          );

    if (api.code != successCode) {
      throw NetworkException(
        type: NetworkErrorType.business,
        message: api.message,
        request: resp.request,
        code: api.code,
        statusCode: resp.statusCode,
        responseHeaders: resp.headers,
        businessCode: api.code,
        businessPayload: api.raw,
      );
    }

    return NetworkResponse<ApiResponse<T>>(
      request: resp.request,
      statusCode: resp.statusCode,
      headers: resp.headers,
      data: api,
      rawBytes: resp.rawBytes,
    );
  }

  String? _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v is String) return v;
    }
    return null;
  }

  /// 兼容型快捷方法：POST JSON Map
  ///
  /// - 适合快速接入 legacy 接口
  /// - 默认以 JSON 解码并要求返回为 Map
  /// - 若返回不是 Map，将抛出 [NetworkException]（serialization）
  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Map<String, String> headers = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Duration? timeout,
  }) async {
    final response = await request<Object?>(
      NetworkRequest(
        method: NetworkMethod.post,
        path: path,
        headers: headers,
        queryParameters: queryParameters,
        body: body,
        timeout: timeout,
        responseType: NetworkResponseType.json,
      ),
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw NetworkException(
      type: NetworkErrorType.serialization,
      message: 'Expected JSON object but got ${data.runtimeType}',
      request: response.request,
      statusCode: response.statusCode,
      responseHeaders: response.headers,
    );
  }

  /// 兼容型快捷方法：GET JSON List<Map>
  ///
  /// - 默认以 JSON 解码并要求返回为 List
  /// - 会将 List 中的每个元素尝试转换为 `Map<String, dynamic>`
  /// - 若返回不是 List，将抛出 [NetworkException]（serialization）
  Future<List<Map<String, dynamic>>> getList(
    String path, {
    Map<String, String> headers = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Duration? timeout,
  }) async {
    final response = await request<Object?>(
      NetworkRequest(
        method: NetworkMethod.get,
        path: path,
        headers: headers,
        queryParameters: queryParameters,
        timeout: timeout,
        responseType: NetworkResponseType.json,
      ),
    );
    final data = response.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    throw NetworkException(
      type: NetworkErrorType.serialization,
      message: 'Expected JSON array but got ${data.runtimeType}',
      request: response.request,
      statusCode: response.statusCode,
      responseHeaders: response.headers,
    );
  }

  /// 解析 URL（支持相对路径 + baseUrl）
  ///
  /// - 当 [path] 为绝对 URL（http/https）时直接使用
  /// - 否则将 [NetworkClientOptions.baseUrl] 与 path 直接拼接
  /// - queryParameters 会与 URL 自带 query 合并，同名参数以后者覆盖前者
  Uri _resolveUri(String path, Map<String, String> queryParameters) {
    final isAbsolute =
        path.startsWith('http://') || path.startsWith('https://');
    final base = _options.baseUrl ?? '';
    final raw = isAbsolute ? path : (base + path);
    final uri = Uri.parse(raw);
    if (queryParameters.isEmpty) {
      return uri;
    }
    return uri.replace(
      queryParameters: <String, String>{
        ...uri.queryParameters,
        ...queryParameters,
      },
    );
  }

  /// 组装统一响应并进行解码（基于 Dio Response）
  ///
  /// 约定：
  /// - 仅将 2xx 视为成功响应，否则抛出 [NetworkException]（badResponse）
  /// - 底层以 bytes 读取响应，再由 [NetworkSerializer] 解码
  /// - 始终保留原始字节到 [NetworkResponse.rawBytes]，便于调试/二次解析
  Future<NetworkResponse<T>> _decodeResponse<T>(
    NetworkRequest request,
    Response<dynamic> resp,
  ) async {
    final statusCode = resp.statusCode ?? 0;
    final headers = <String, String>{};
    resp.headers.forEach((String name, List<String> values) {
      if (values.isEmpty) return;
      headers[name] = values.join(',');
    });
    if (statusCode < 200 || statusCode >= 300) {
      throw NetworkException(
        type: NetworkErrorType.badResponse,
        message: 'Bad response',
        request: request,
        statusCode: statusCode,
        responseHeaders: headers,
      );
    }
    final wireBytes = _extractWireBytes(resp.data);
    var payloadBytes = wireBytes;
    final crypto = _crypto;
    if (crypto != null && crypto.shouldDecrypt(request)) {
      try {
        payloadBytes = await crypto.decrypt(
          NetworkCryptoResponse(
            uri: resp.requestOptions.uri,
            request: request,
            statusCode: statusCode,
            headers: headers,
            bodyBytes: wireBytes,
          ),
        );
      } catch (e) {
        throw NetworkException(
          type: NetworkErrorType.serialization,
          message: 'Response decryption failed: ${e.toString()}',
          request: request,
          statusCode: statusCode,
          responseHeaders: headers,
          cause: e,
        );
      }
    }
    Object? decoded;
    try {
      switch (request.responseType) {
        case NetworkResponseType.bytes:
          decoded = payloadBytes;
          break;
        case NetworkResponseType.text:
          decoded = utf8.decode(payloadBytes);
          break;
        case NetworkResponseType.json:
          decoded = _serializer.decode(payloadBytes);
          break;
      }
    } catch (e) {
      throw NetworkException(
        type: NetworkErrorType.serialization,
        message: 'Response deserialization failed: ${e.toString()}',
        request: request,
        statusCode: statusCode,
        responseHeaders: headers,
        cause: e,
      );
    }
    return NetworkResponse<T>(
      request: request,
      statusCode: statusCode,
      headers: headers,
      data: decoded as T,
      rawBytes: wireBytes,
    );
  }

  /// 将 Dio 返回的 response.data 统一抽取为 bytes（wire bytes）。
  ///
  /// 约定：
  /// - Dio 在 ResponseType.bytes 模式下通常返回 List<int>
  /// - 若 data 为 String 或其它类型，按 UTF-8 文本处理或 JSON 编码后转 bytes
  List<int> _extractWireBytes(dynamic data) {
    if (data == null) return const <int>[];
    if (data is List<int>) return List<int>.from(data);
    if (data is String) return utf8.encode(data);
    return utf8.encode(jsonEncode(data));
  }

  NetworkException _mapDioError(DioException e, NetworkRequest request) {
    // Dio 的 error type 在不同平台/版本下可能有所差异，这里做最小可用的归一化映射。
    final type = e.type;
    switch (type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException(
          type: NetworkErrorType.timeout,
          message: e.message ?? 'Timeout',
          request: request,
          cause: e,
        );
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        final headers = <String, String>{};
        e.response?.headers.forEach((String name, List<String> values) {
          if (values.isEmpty) return;
          headers[name] = values.join(',');
        });
        return NetworkException(
          type: NetworkErrorType.badResponse,
          message: 'Bad response',
          request: request,
          statusCode: status,
          responseHeaders: headers.isEmpty ? null : headers,
          cause: e,
        );
      case DioExceptionType.cancel:
        return NetworkException(
          type: NetworkErrorType.cancelled,
          message: 'Cancelled',
          request: request,
          cause: e,
        );
      case DioExceptionType.connectionError:
        return NetworkException(
          type: NetworkErrorType.network,
          message: e.message ?? 'Connection error',
          request: request,
          cause: e,
        );
      case DioExceptionType.unknown:
      default:
        return NetworkException(
          type: NetworkErrorType.unknown,
          message: e.message ?? 'Unknown error',
          request: request,
          cause: e,
        );
    }
  }
}
