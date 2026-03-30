import 'package:flutter_scaffold_demo/domain/auth/auth_session_service.dart';
import 'package:flutter_scaffold_demo/domain/auth/login_repository.dart';
import 'package:flutter_scaffold_demo/domain/user/user_session.dart';

class LoginUseCase {
  const LoginUseCase(this._repository, this._authSessionService);

  final LoginRepository _repository;
  final AuthSessionService _authSessionService;

  Future<UserSession> execute({
    required String account,
    required String password,
  }) async {
    final session = await _repository.login(account: account, password: password);
    await _repository.saveSession(session);
    _authSessionService.updateSession(session);
    return session;
  }
}
