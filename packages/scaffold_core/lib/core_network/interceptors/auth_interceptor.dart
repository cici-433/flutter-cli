import 'dart:async';

import 'package:dio/dio.dart';

/// 鉴权令牌集合
///
/// - accessToken：用于业务请求的访问令牌
/// - refreshToken：用于刷新访问令牌的刷新令牌（可选）
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    this.refreshToken,
  });

  final String accessToken;
  final String? refreshToken;
}

/// Dio 鉴权拦截器（应用无关）
///
/// 职责：
/// - 在请求发出前为请求注入 Authorization 头
/// - 当响应返回 401 时触发刷新流程，并在刷新成功后重放原请求
/// - 刷新失败统一触发登出回调（确保只触发一次）
///
/// 关键行为约定：
/// - 单飞刷新：并发多个 401 只会触发一次刷新请求，其他请求等待同一个刷新 Future
/// - 防重放死循环：重放的请求会标记 `__auth_replayed__ = true`，再次 401 不再重试刷新
/// - 可跳过：通过 [shouldSkip] 或 `options.extra['__skip_auth__'] = true` 跳过鉴权注入
/// - 可跳过刷新：通过 [shouldSkipRefresh] 或 `options.extra['__skip_auth_refresh__'] = true` 直接登出
///
/// 注意：
/// - 重放使用注入的 [_dio] 执行 `fetch`，以便复用同一套 Dio 配置与拦截器链
/// - 建议在应用层对“刷新接口”设置 `__skip_auth_refresh__`，避免递归刷新
class DioAuthInterceptor extends Interceptor {
  DioAuthInterceptor({
    required Dio dio,
    required FutureOr<String?> Function() getAccessToken,
    FutureOr<String?> Function()? getRefreshToken,
    required Future<AuthTokens?> Function(String? refreshToken) refreshTokens,
    required FutureOr<void> Function(AuthTokens tokens) onTokenUpdated,
    required FutureOr<void> Function() onLogout,
    this.authorizationHeader = 'Authorization',
    this.tokenPrefix = 'Bearer ',
    bool Function(RequestOptions options)? shouldSkip,
    bool Function(RequestOptions options)? shouldSkipRefresh,
  })  : _dio = dio,
        _getAccessToken = getAccessToken,
        _getRefreshToken = getRefreshToken,
        _refreshTokens = refreshTokens,
        _onTokenUpdated = onTokenUpdated,
        _onLogout = onLogout,
        _shouldSkip = shouldSkip,
        _shouldSkipRefresh = shouldSkipRefresh;

  final Dio _dio;
  final FutureOr<String?> Function() _getAccessToken;
  final FutureOr<String?> Function()? _getRefreshToken;
  final Future<AuthTokens?> Function(String? refreshToken) _refreshTokens;
  final FutureOr<void> Function(AuthTokens tokens) _onTokenUpdated;
  final FutureOr<void> Function() _onLogout;
  final bool Function(RequestOptions options)? _shouldSkip;
  final bool Function(RequestOptions options)? _shouldSkipRefresh;

  final String authorizationHeader;
  final String tokenPrefix;

  Future<AuthTokens?>? _refreshFuture;
  Future<void>? _logoutFuture;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (_shouldSkip?.call(options) == true) {
      handler.next(options);
      return;
    }
    if (options.extra['__skip_auth__'] == true) {
      handler.next(options);
      return;
    }

    final token = await _getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers[authorizationHeader] = '$tokenPrefix$token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (_shouldSkip?.call(options) == true ||
        options.extra['__skip_auth__'] == true) {
      handler.next(err);
      return;
    }

    final status = err.response?.statusCode;
    if (status != 401) {
      handler.next(err);
      return;
    }

    if (options.extra['__auth_replayed__'] == true) {
      handler.next(err);
      return;
    }

    if (_shouldSkipRefresh?.call(options) == true ||
        options.extra['__skip_auth_refresh__'] == true) {
      await _logoutOnce();
      handler.next(err);
      return;
    }

    final tokens = await _ensureRefresh();
    if (tokens == null) {
      handler.next(err);
      return;
    }

    options.headers[authorizationHeader] = '$tokenPrefix${tokens.accessToken}';
    options.extra['__auth_replayed__'] = true;

    try {
      final resp = await _dio.fetch(options);
      handler.resolve(resp);
    } on DioException catch (e) {
      handler.next(e);
    } catch (_) {
      handler.next(err);
    }
  }

  Future<AuthTokens?> _ensureRefresh() {
    final current = _refreshFuture;
    if (current != null) return current;

    final future = _runRefresh();
    _refreshFuture = future;
    future.whenComplete(() {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
      }
    });
    return future;
  }

  Future<AuthTokens?> _runRefresh() async {
    try {
      final refreshTokenGetter = _getRefreshToken;
      final refreshToken =
          refreshTokenGetter == null ? null : await refreshTokenGetter();
      final tokens = await _refreshTokens(refreshToken);
      if (tokens == null || tokens.accessToken.isEmpty) {
        await _logoutOnce();
        return null;
      }
      await _onTokenUpdated(tokens);
      return tokens;
    } catch (_) {
      await _logoutOnce();
      return null;
    }
  }

  Future<void> _logoutOnce() {
    final current = _logoutFuture;
    if (current != null) return current;
    final future = Future<void>.sync(_onLogout);
    _logoutFuture = future;
    future.whenComplete(() {
      if (identical(_logoutFuture, future)) {
        _logoutFuture = null;
      }
    });
    return future;
  }
}
