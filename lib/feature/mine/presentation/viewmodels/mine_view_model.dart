import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:scaffold_core/core_common/module_event_bus.dart';
import 'package:flutter_scaffold_demo/domain/auth/auth_session_service.dart';
import 'package:flutter_scaffold_demo/domain/auth/logout_use_case.dart';
import 'package:flutter_scaffold_demo/domain/order/order_query_service.dart';
import 'package:flutter_scaffold_demo/domain/user/user_session.dart';

class MineViewModel extends ChangeNotifier {
  MineViewModel({
    required AuthSessionService authSessionService,
    required LogoutUseCase logoutUseCase,
    required OrderQueryService orderQueryService,
    required ModuleEventBus eventBus,
  })  : _authSessionService = authSessionService,
        _logoutUseCase = logoutUseCase,
        _orderQueryService = orderQueryService,
        _eventBus = eventBus {
    _session = _authSessionService.currentSession;
    _sessionSubscription =
        _authSessionService.sessionStream.listen((UserSession? session) {
      _session = session;
      notifyListeners();
    });
    _eventSubscription = _eventBus.stream.listen((ModuleEvent event) {
      if (event.topic == 'auth_changed') {
        _lastAuthEvent = event.message;
        notifyListeners();
      }
      if (event.sourceModule == 'order') {
        refreshOrderCount(forceRefresh: true);
      }
    });
  }

  final AuthSessionService _authSessionService;
  final LogoutUseCase _logoutUseCase;
  final OrderQueryService _orderQueryService;
  final ModuleEventBus _eventBus;

  UserSession? _session;
  int _orderCount = 0;
  String _lastAuthEvent = '暂无';
  StreamSubscription<ModuleEvent>? _eventSubscription;
  StreamSubscription<UserSession?>? _sessionSubscription;

  UserSession? get session => _session;
  int get orderCount => _orderCount;
  String get lastAuthEvent => _lastAuthEvent;

  Future<void> refreshOrderCount({bool forceRefresh = false}) async {
    try {
      _orderCount =
          await _orderQueryService.fetchOrderCount(forceRefresh: forceRefresh);
      notifyListeners();
    } catch (_) {}
  }

  void logout() {
    final current = _logoutUseCase.execute();
    if (current == null) {
      return;
    }
    _eventBus.publish(
      ModuleEvent(
        sourceModule: 'mine',
        topic: 'auth_changed',
        message: '用户 ${current.userName} 已退出登录',
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _sessionSubscription?.cancel();
    super.dispose();
  }
}
