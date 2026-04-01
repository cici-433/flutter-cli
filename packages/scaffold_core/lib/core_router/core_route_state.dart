/// 当前匹配路由的运行时状态。
///
/// 一个 [CoreRouteState] 会在路由匹配成功后生成，并在页面构建、守卫判断、
/// 参数解析等环节中复用，避免每一层重复解析 `Uri`。
class CoreRouteState {
  const CoreRouteState({
    required this.uri,
    required this.pathParameters,
    this.extra,
  });

  /// 标准化后的 URI。
  final Uri uri;

  /// 动态路径参数，例如 `/orders/:id` 中的 `id`。
  final Map<String, String> pathParameters;

  /// 导航时透传的附加对象。
  final Object? extra;

  /// 当前完整 location，通常等于 `path + query + fragment`。
  String get location => uri.toString();

  /// 当前路径部分。
  String get path => uri.path.isEmpty ? '/' : uri.path;

  /// 当前 query 参数。
  Map<String, String> get queryParameters => uri.queryParameters;

  /// 按类型安全方式读取 [extra]。
  ///
  /// 如果运行时类型与 [T] 不匹配，则返回 `null`，避免强制转换异常。
  T? extraAs<T>() {
    final value = extra;
    if (value is T) {
      return value;
    }
    return null;
  }

  /// 读取单个 query 参数并交由 [parser] 转为目标类型。
  ///
  /// 适合处理枚举、整数、时间等需要自定义解析的参数。
  T? queryAs<T>(String key, T Function(String rawValue) parser) {
    final value = queryParameters[key];
    if (value == null) {
      return null;
    }
    return parser(value);
  }
}
