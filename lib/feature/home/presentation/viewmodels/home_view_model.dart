import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:scaffold_core/core_common/module_event_bus.dart';
import 'package:flutter_scaffold_demo/domain/auth/auth_session_service.dart';
import 'package:flutter_scaffold_demo/domain/order/order_info.dart';
import 'package:flutter_scaffold_demo/domain/order/order_query_service.dart';
import 'package:flutter_scaffold_demo/domain/user/user_session.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required AuthSessionService authSessionService,
    required OrderQueryService orderQueryService,
    required ModuleEventBus eventBus,
  })  : _authSessionService = authSessionService,
        _orderQueryService = orderQueryService,
        _eventBus = eventBus {
    _sessionSubscription =
        _authSessionService.sessionStream.listen((UserSession? session) {
      _session = session;
      notifyListeners();
    });
    _eventSubscription = _eventBus.stream.listen(_onEvent);
    _session = _authSessionService.currentSession;
  }

  final AuthSessionService _authSessionService;
  final OrderQueryService _orderQueryService;
  final ModuleEventBus _eventBus;

  UserSession? _session;
  List<OrderInfo> _orders = <OrderInfo>[];
  final List<ModuleEvent> _events = <ModuleEvent>[];
  StreamSubscription<ModuleEvent>? _eventSubscription;
  StreamSubscription<UserSession?>? _sessionSubscription;

  UserSession? get session => _session;
  int get orderCount => _orders.length;
  OrderInfo? get latestOrder => _orders.isEmpty ? null : _orders.first;
  List<ModuleEvent> get events => List<ModuleEvent>.unmodifiable(_events);

  Future<void> refreshOrderData({bool forceRefresh = false}) async {
    try {
      _orders = await _orderQueryService.fetchOrders(forceRefresh: forceRefresh);
      notifyListeners();
    } catch (_) {}
  }

  void _onEvent(ModuleEvent event) {
    _events.insert(0, event);
    if (_events.length > 8) {
      _events.removeLast();
    }
    if (event.sourceModule == 'order') {
      refreshOrderData(forceRefresh: true);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _sessionSubscription?.cancel();
    super.dispose();
  }
}
