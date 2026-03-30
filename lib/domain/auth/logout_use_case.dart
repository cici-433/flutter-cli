import 'package:flutter_scaffold_demo/domain/auth/auth_session_service.dart';
import 'package:flutter_scaffold_demo/domain/user/user_session.dart';

class LogoutUseCase {
  const LogoutUseCase(this._authSessionService);

  final AuthSessionService _authSessionService;

  UserSession? execute() {
    final current = _authSessionService.currentSession;
    if (current == null) {
      return null;
    }
    _authSessionService.updateSession(null);
    return current;
  }
}
