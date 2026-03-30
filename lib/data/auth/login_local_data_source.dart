import 'package:flutter_scaffold_demo/domain/user/user_session.dart';

class LoginLocalDataSource {
  UserSession? _cachedSession;

  Future<void> saveSession(UserSession session) async {
    _cachedSession = session;
  }

  UserSession? get currentSession => _cachedSession;
}
