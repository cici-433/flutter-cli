import 'dart:async';

import 'package:flutter_scaffold_demo/domain/auth/auth_session_service.dart';
import 'package:flutter_scaffold_demo/domain/user/user_session.dart';

class InMemoryAuthSessionService implements AuthSessionService {
  InMemoryAuthSessionService._internal();

  static final InMemoryAuthSessionService _instance =
      InMemoryAuthSessionService._internal();

  factory InMemoryAuthSessionService() => _instance;

  final StreamController<UserSession?> _controller =
      StreamController<UserSession?>.broadcast();

  UserSession? _currentSession;

  @override
  Stream<UserSession?> get sessionStream async* {
    yield _currentSession;
    yield* _controller.stream;
  }

  @override
  UserSession? get currentSession => _currentSession;

  @override
  void updateSession(UserSession? session) {
    _currentSession = session;
    _controller.add(session);
  }
}
