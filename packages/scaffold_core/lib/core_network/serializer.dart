import 'dart:convert';

/// 请求/响应序列化协议
///
/// 通过策略替换适配不同编解码格式（JSON/ProtoBuf/MsgPack 等）。
abstract class NetworkSerializer {
  const NetworkSerializer();
  String contentType();
  List<int> encode(Object body);
  Object? decode(List<int> bytes);
}

/// 默认 JSON 序列化器
///
/// - contentType：application/json; charset=utf-8
/// - encode：对象转 UTF-8 字节
/// - decode：字节转对象
class JsonNetworkSerializer extends NetworkSerializer {
  const JsonNetworkSerializer();
  @override
  String contentType() => 'application/json; charset=utf-8';
  @override
  List<int> encode(Object body) => utf8.encode(jsonEncode(body));
  @override
  Object? decode(List<int> bytes) {
    if (bytes.isEmpty) return null;
    return jsonDecode(utf8.decode(bytes));
  }
}

/// 纯文本序列化器（UTF-8）
class TextNetworkSerializer extends NetworkSerializer {
  const TextNetworkSerializer();
  @override
  String contentType() => 'text/plain; charset=utf-8';
  @override
  List<int> encode(Object body) {
    if (body is String) return utf8.encode(body);
    return utf8.encode('$body');
  }
  @override
  Object? decode(List<int> bytes) {
    if (bytes.isEmpty) return '';
    return utf8.decode(bytes, allowMalformed: true);
  }
}

/// 二进制序列化器（原样传递字节）
class BytesNetworkSerializer extends NetworkSerializer {
  const BytesNetworkSerializer();
  @override
  String contentType() => 'application/octet-stream';
  @override
  List<int> encode(Object body) {
    if (body is List<int>) return List<int>.from(body);
    if (body is String) return utf8.encode(body);
    return utf8.encode(jsonEncode(body));
  }
  @override
  Object? decode(List<int> bytes) {
    return List<int>.from(bytes);
  }
}
