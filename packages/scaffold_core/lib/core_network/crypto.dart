import 'dart:async';

import 'types.dart';

/// 网络加解密上下文：请求侧入参。
///
/// 说明：
/// - [bodyBytes] 来自 core 内部的序列化器（例如 JSON -> UTF-8 bytes）
/// - 加密实现由应用层提供（core 只定义抽象接口，不内置算法与密钥）
/// - [headers] 为请求最终将要发送的 header 集合（包含 defaultHeaders 与 request.headers）
/// - 若加密协议需要签名/nonce/timestamp 等，可通过返回 [NetworkCryptoResult.headers] 注入
class NetworkCryptoRequest {
  const NetworkCryptoRequest({
    required this.uri,
    required this.request,
    required this.headers,
    required this.bodyBytes,
  });

  /// 实际请求 URI（已合并 baseUrl 与 queryParameters）。
  final Uri uri;

  /// 业务侧构造的请求模型。
  final NetworkRequest request;

  /// 当前请求将携带的 headers（可用于参与签名计算）。
  final Map<String, String> headers;

  /// 序列化后的请求体字节（可能为 null，表示无 body）。
  final List<int>? bodyBytes;
}

/// 网络加解密上下文：请求侧返回值。
///
/// - 可返回新的 [bodyBytes] 作为最终发送载荷（例如加密后的 bytes）
/// - 可返回额外的 [headers]（例如 `x-sign`、`x-nonce`、`content-type` 等）
class NetworkCryptoResult {
  const NetworkCryptoResult({this.headers, this.bodyBytes});

  /// 需要追加/覆盖的请求头。
  final Map<String, String>? headers;

  /// 最终要发送的请求体字节。
  final List<int>? bodyBytes;
}

/// 网络加解密上下文：响应侧入参。
///
/// 说明：
/// - [bodyBytes] 是网络层拿到的原始字节（wire bytes，通常为“加密后的”响应体）
/// - 解密实现由应用层提供，返回“明文字节”（例如 JSON UTF-8 bytes）

class NetworkCryptoResponse {
  const NetworkCryptoResponse({
    required this.uri,
    required this.request,
    required this.statusCode,
    required this.headers,
    required this.bodyBytes,
  });

  /// 实际请求 URI（Dio RequestOptions.uri）。
  final Uri uri;

  /// 业务侧构造的请求模型（用于决定是否解密/选择算法等）。
  final NetworkRequest request;

  /// HTTP 状态码（仅当 2xx 时会进入解密流程）。
  final int statusCode;

  /// 响应 headers（已扁平化为 key -> joined values）。
  final Map<String, String> headers;

  /// 响应原始字节（wire bytes）。
  final List<int> bodyBytes;
}

/// 网络加解密接口（由应用层实现，core 负责串联调用时机）。
///
/// 触发时机（在 [NetworkClient] 内部）：
/// - 请求：序列化后（得到 bytes）-> [encrypt] -> 交给 Dio 发送
/// - 响应：拿到 bytes -> [decrypt] -> 交给序列化器按 json/text/bytes 解码
///
/// 注意：
/// - core 不负责密钥管理、证书钉扎、算法实现；这些必须由应用层提供
/// - 建议在应用层实现中按 path/headers/extra 等维度选择性加密（避免影响下载等非 JSON 接口）

abstract class NetworkCrypto {
  const NetworkCrypto();

  /// 是否对该请求进行加密。

  bool shouldEncrypt(NetworkRequest request) => true;

  /// 是否对该请求对应的响应进行解密。

  bool shouldDecrypt(NetworkRequest request) => true;

  /// 对请求体进行加密/签名，并可注入额外 headers。

  FutureOr<NetworkCryptoResult> encrypt(NetworkCryptoRequest request);

  /// 对响应体进行解密，返回明文字节。

  FutureOr<List<int>> decrypt(NetworkCryptoResponse response);
}
