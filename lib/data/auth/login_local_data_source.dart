import 'package:flutter_scaffold_demo/domain/user/user_session.dart';
import 'package:scaffold_core/core_storage/storage.dart';

class LoginLocalDataSource {
  LoginLocalDataSource(this._storage);

  final CoreStorage _storage;
  UserSession? _cachedSession;

  Future<void> saveSession(UserSession session) async {
    _cachedSession = session;
    final store = await _storage.user(session.userId);
    await store.setJson('session', {
      'userId': session.userId,
      'userName': session.userName,
      'token': session.token,
    });
  }

  UserSession? get currentSession => _cachedSession;
}
