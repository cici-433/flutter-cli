import 'package:dio/dio.dart';
import 'package:scaffold_core/core_network/network_client.dart';
import 'package:scaffold_core/core_network/types.dart';
import 'package:scaffold_core/core_network/interceptors/header_injector_interceptor.dart';
import 'package:scaffold_core/core_network/interceptors/auth_interceptor.dart';
import 'package:scaffold_core/core_network/interceptors/logging_interceptor.dart';
import 'package:scaffold_core/core_network/interceptors/retry_interceptor.dart';
import 'package:scaffold_core/core_network/interceptors/timeout_interceptor.dart';
import 'package:flutter_scaffold_demo/domain/auth/auth_session_service.dart';

class AppNetwork {
  AppNetwork({AuthSessionService? auth}) : client = _createClient(auth);
  final NetworkClient client;
}

NetworkClient _createClient(AuthSessionService? auth) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.example.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      responseType: ResponseType.bytes,
    ),
  );

  dio.interceptors.add(
    DioHeaderInjectorInterceptor(
      staticHeaders: const {'x-app': 'demo'},
      headersBuilder: (options) async => {
        'x-trace-id': 'trace-${DateTime.now().millisecondsSinceEpoch}',
      },
    ),
  );

  dio.interceptors.add(
    DioAuthInterceptor(
      dio: dio,
      getAccessToken: () async => auth?.currentSession?.token,
      refreshTokens: (refreshToken) async => null,
      onTokenUpdated: (tokens) async {},
      onLogout: () async {},
    ),
  );

  dio.interceptors.add(
    DioLoggingInterceptor(
      logHeaders: false,
      logRequestBody: false,
      logResponseBody: false,
    ),
  );

  dio.interceptors.add(
    DioTimeoutInterceptor(
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  dio.interceptors.add(
    DioRetryInterceptor(
      dio,
      const DioRetryPolicy(maxAttempts: 3),
    ),
  );

  return NetworkClient(
    options: const NetworkClientOptions(baseUrl: 'https://api.example.com'),
    dio: dio,
  );
}
