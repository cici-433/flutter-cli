import 'dart:convert';

/// 路由参数编解码工具。
///
/// 设计目标：
/// - 为 query 参数提供统一的复杂对象序列化能力
/// - 避免业务层自行拼接 JSON、Base64 或 URL 编码逻辑
/// - 让不同路由实现共享同一套参数编码约定
class CoreRouteCodec {
  const CoreRouteCodec._();

  /// 将任意可 JSON 序列化对象编码为 Base64Url 字符串。
  ///
  /// 该格式适合放入 query 参数中，可避免直接传输 JSON 时出现的特殊字符问题。
  static String encodeJson(Object? value) {
    return base64Url.encode(utf8.encode(jsonEncode(value)));
  }

  /// 将 [encodeJson] 生成的字符串还原为 Dart 对象。
  static Object? decodeJson(String value) {
    return jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(value))),
    );
  }

  /// 将 query 参数映射为字符串字典。
  ///
  /// 编码策略：
  /// - `null`：忽略，不写入 query
  /// - `String`：原样写入
  /// - `num/bool`：转成字符串
  /// - 其余对象：按 JSON + Base64Url 编码
  static Map<String, String> encodeQueryParameters(
    Map<String, Object?> parameters,
  ) {
    final result = <String, String>{};
    parameters.forEach((key, value) {
      if (value == null) {
        return;
      }
      if (value is String) {
        result[key] = value;
        return;
      }
      if (value is num || value is bool) {
        result[key] = '$value';
        return;
      }
      result[key] = encodeJson(value);
    });
    return result;
  }

  /// 将复杂对象 query 参数解码为目标类型。
  ///
  /// [decoder] 负责把 JSON 结构映射为业务模型或具体的数据类型。
  static T decodeObject<T>(String value, T Function(Object? json) decoder) {
    return decoder(decodeJson(value));
  }
}
