import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';

/// Dio 日志拦截器（应用无关）
///
/// 功能：
/// - 请求/响应/错误的关键信息打印
/// - 可选打印 headers 与 body，支持长度截断
/// - 统计单次请求耗时
///
/// 安全建议：
/// - 生产环境谨慎开启 [logHeaders]/[logRequestBody]/[logResponseBody]，避免泄露 Token/隐私数据
/// - 可在上层通过自定义 [logger] 做脱敏与采样
class DioLoggingInterceptor extends Interceptor {
  DioLoggingInterceptor({
    this.logHeaders = false,
    this.logRequestBody = false,
    this.logResponseBody = false,
    this.logCurl = false,
    this.maxBodyLength = 1 << 12, // 4KB
    void Function(String message)? logger,
  }) : _logger = logger ?? _defaultLogger;

  final bool logHeaders;
  final bool logRequestBody;
  final bool logResponseBody;
  final bool logCurl;
  final int maxBodyLength;
  final void Function(String message) _logger;

  static void _defaultLogger(String message) {
    developer.log(message, name: 'NET');
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['__start_ts__'] = DateTime.now().microsecondsSinceEpoch;
    final b = StringBuffer();
    b.write('➡️ ${options.method} ${options.uri}');
    if (logHeaders && options.headers.isNotEmpty) {
      b.write('\n  headers: ${_truncate(jsonEncode(options.headers))}');
    }
    if (logRequestBody && options.data != null) {
      b.write('\n  body: ${_formatBody(options.data)}');
    }
    _logger(b.toString());
    if (logCurl) {
      final curl = _buildCurl(options);
      _logger('curl $curl');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final start = response.requestOptions.extra['__start_ts__'] as int?;
    final elapsed = start == null
        ? null
        : Duration(
            microseconds:
                DateTime.now().microsecondsSinceEpoch - start,
          );
    final b = StringBuffer();
    b.write('✅ ${response.requestOptions.method} ${response.requestOptions.uri} '
        '(${response.statusCode})');
    if (elapsed != null) {
      b.write(' in ${elapsed.inMilliseconds}ms');
    }
    if (logHeaders && response.headers.map.isNotEmpty) {
      b.write('\n  headers: ${_truncate(jsonEncode(response.headers.map))}');
    }
    if (logResponseBody && response.data != null) {
      b.write('\n  body: ${_formatBody(response.data)}');
    }
    _logger(b.toString());
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final req = err.requestOptions;
    final start = req.extra['__start_ts__'] as int?;
    final elapsed = start == null
        ? null
        : Duration(
            microseconds:
                DateTime.now().microsecondsSinceEpoch - start,
          );
    final code = err.response?.statusCode;
    final b = StringBuffer();
    b.write('❌ ${req.method} ${req.uri} '
        '${code == null ? '' : '($code) '}'
        '${err.type.name}: ${err.message}');
    if (elapsed != null) {
      b.write(' in ${elapsed.inMilliseconds}ms');
    }
    if (logHeaders && err.response?.headers.map.isNotEmpty == true) {
      b.write(
        '\n  headers: ${_truncate(jsonEncode(err.response!.headers.map))}',
      );
    }
    if (logResponseBody && err.response?.data != null) {
      b.write('\n  body: ${_formatBody(err.response!.data)}');
    }
    _logger(b.toString());
    handler.next(err);
  }

  String _formatBody(Object? data) {
    if (data == null) return 'null';
    try {
      if (data is List<int>) {
        final text = utf8.decode(data, allowMalformed: true);
        return _truncate(text);
      }
      if (data is String) {
        return _truncate(data);
      }
      return _truncate(jsonEncode(data));
    } catch (_) {
      return _truncate('$data');
    }
  }

  String _truncate(String s) {
    if (s.length <= maxBodyLength) return s;
    return '${s.substring(0, maxBodyLength)}...(${s.length} bytes)';
  }

  String _buildCurl(RequestOptions options) {
    final sb = StringBuffer();
    sb.write("-X ${options.method} '${options.uri}'");
    options.headers.forEach((k, v) {
      sb.write(" -H '${_shell("$k: ${v.toString()}")}'");
    });
    final data = options.data;
    if (data != null) {
      if (data is FormData) {
        for (final field in data.fields) {
          sb.write(" -F '${_shell("${field.key}=${field.value}")}'");
        }
        for (final file in data.files) {
          final key = file.key;
          final filename = file.value.filename ?? 'file';
          sb.write(" -F '${_shell("$key=@$filename")}'");
        }
      } else {
        String bodyStr;
        try {
          if (data is List<int>) {
            bodyStr = utf8.decode(data, allowMalformed: true);
          } else if (data is String) {
            bodyStr = data;
          } else {
            bodyStr = jsonEncode(data);
          }
        } catch (_) {
          bodyStr = '$data';
        }
        sb.write(" --data '${_shell(_truncate(bodyStr))}'");
      }
    }
    return sb.toString();
  }

  String _shell(String s) {
    return s.replaceAll("'", "'\"'\"'");
  }
}
