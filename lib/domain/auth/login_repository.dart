import 'package:flutter_scaffold_demo/domain/user/user_session.dart';

abstract class LoginRepository {
  Future<UserSession> login({
    required String account,
    required String password,
  });

  Future<void> saveSession(UserSession session);
}
