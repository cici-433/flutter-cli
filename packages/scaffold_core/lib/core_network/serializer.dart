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
