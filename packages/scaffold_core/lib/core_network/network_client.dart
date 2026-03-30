import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'errors.dart';
import 'serializer.dart';
import 'types.dart';

/// 面向大型项目的网络客户端入口（应用无关）
///
/// 关键设计：
/// - 统一请求/响应/错误模型
/// - 固定使用 Dio 作为底层引擎（支持配置 BaseOptions/拦截器）
/// - 序列化策略可替换（默认 JSON）
class NetworkClient {
  NetworkClient({
    NetworkClientOptions options = const NetworkClientOptions(),
    NetworkSerializer serializer = const JsonNetworkSerializer(),
    Dio? dio,
    BaseOptions? baseOptions,
    List<Interceptor>? dioInterceptors,
  })  : _options = options,
        _serializer = serializer,
        _dio = dio ??
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
  final Dio _dio;

  /// 统一请求入口
  ///
  /// 流程：
  /// 1. 取消令牌检查
  /// 2. onRequest 链改写请求
  /// 3. 发送 + 组装响应
  /// 4. onResponse 链处理响应（逆序）
  /// 5. 错误归一化 + onError 链处理（逆序）
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

      final options = Options(
        method: current.method.name.toUpperCase(),
        headers: headers,
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
      final response = _decodeResponse<T>(current, resp);
      return response;
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


  /// 兼容型快捷方法：POST JSON Map
  Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, dynamic> body,
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
  Uri _resolveUri(String path, Map<String, String> queryParameters) {
    final isAbsolute = path.startsWith('http://') || path.startsWith('https://');
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
  NetworkResponse<T> _decodeResponse<T>(
    NetworkRequest request,
    Response<dynamic> resp,
  ) {
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
    List<int> bytes;
    final data = resp.data;
    if (data is List<int>) {
      bytes = List<int>.from(data);
    } else if (data is String) {
      bytes = utf8.encode(data);
    } else {
      bytes = utf8.encode(jsonEncode(data));
    }
    Object? decoded;
    try {
      switch (request.responseType) {
        case NetworkResponseType.bytes:
          decoded = bytes;
          break;
        case NetworkResponseType.text:
          decoded = utf8.decode(bytes);
          break;
        case NetworkResponseType.json:
          decoded = _serializer.decode(bytes);
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
      rawBytes: bytes,
    );
  }

  NetworkException _mapDioError(DioException e, NetworkRequest request) {
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
