import 'package:flutter_scaffold_demo/data/auth/login_local_data_source.dart';
import 'package:flutter_scaffold_demo/data/auth/login_remote_data_source.dart';
import 'package:flutter_scaffold_demo/domain/auth/login_repository.dart';
import 'package:flutter_scaffold_demo/domain/user/user_session.dart';

class LoginRepositoryImpl implements LoginRepository {
  const LoginRepositoryImpl({
    required LoginRemoteDataSource remoteDataSource,
    required LoginLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  final LoginRemoteDataSource _remoteDataSource;
  final LoginLocalDataSource _localDataSource;

  @override
  Future<UserSession> login({
    required String account,
    required String password,
  }) {
    return _remoteDataSource.login(account: account, password: password);
  }

  @override
  Future<void> saveSession(UserSession session) {
    return _localDataSource.saveSession(session);
  }
}
