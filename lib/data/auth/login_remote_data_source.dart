import 'package:scaffold_core/core_network/network_client.dart';
import 'package:flutter_scaffold_demo/domain/user/user_session.dart';

class LoginRemoteDataSource {
  const LoginRemoteDataSource(this._networkClient);

  final NetworkClient _networkClient;

  Future<UserSession> login({
    required String account,
    required String password,
  }) async {
    final response = await _networkClient.post(
      '/login',
      body: <String, dynamic>{
        'account': account,
        'password': password,
      },
    );
    return UserSession(
      userId: response['userId'] as String,
      userName: response['userName'] as String,
      token: response['token'] as String,
    );
  }
}
