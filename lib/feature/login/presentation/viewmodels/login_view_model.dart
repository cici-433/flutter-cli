import 'package:flutter/foundation.dart';
import 'package:scaffold_core/core_common/module_event_bus.dart';
import 'package:flutter_scaffold_demo/domain/auth/login_use_case.dart';
import 'package:flutter_scaffold_demo/domain/user/user_session.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel({
    required LoginUseCase loginUseCase,
    required ModuleEventBus eventBus,
  })  : _loginUseCase = loginUseCase,
        _eventBus = eventBus;

  final LoginUseCase _loginUseCase;
  final ModuleEventBus _eventBus;

  bool _loading = false;
  String? _errorMessage;
  UserSession? _session;

  bool get loading => _loading;
  String? get errorMessage => _errorMessage;
  UserSession? get session => _session;

  Future<void> login({
    required String account,
    required String password,
  }) async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final newSession =
          await _loginUseCase.execute(account: account, password: password);
      _session = newSession;
      _eventBus.publish(
        ModuleEvent(
          sourceModule: 'login',
          topic: 'auth_changed',
          message: '用户 ${newSession.userName} 已登录',
          timestamp: DateTime.now(),
        ),
      );
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
