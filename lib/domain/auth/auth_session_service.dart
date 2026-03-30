import 'package:flutter_scaffold_demo/domain/user/user_session.dart';

abstract class AuthSessionService {
  Stream<UserSession?> get sessionStream;
  UserSession? get currentSession;
  void updateSession(UserSession? session);
}
