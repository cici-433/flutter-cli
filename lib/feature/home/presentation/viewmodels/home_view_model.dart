import 'dart:async';

import 'package:scaffold_core/core_common/module_event_bus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scaffold_demo/app/app_scope.dart';
import 'package:flutter_scaffold_demo/domain/auth/auth_session_service.dart';
import 'package:flutter_scaffold_demo/domain/order/order_info.dart';
import 'package:flutter_scaffold_demo/domain/order/order_query_service.dart';
import 'package:flutter_scaffold_demo/domain/user/user_session.dart';

final homeControllerProvider =
    AutoDisposeNotifierProvider<HomeController, HomeState>(HomeController.new);

final authSessionProvider = StreamProvider<UserSession?>((ref) async* {
  final AuthSessionService authSessionService =
      ref.read(authSessionServiceProvider);
  yield authSessionService.currentSession;
  yield* authSessionService.sessionStream;
});

final moduleEventProvider = StreamProvider<ModuleEvent>((ref) {
  return ref.read(eventBusProvider).stream;
});

class HomeState {
  const HomeState({
    required this.session,
    required this.orders,
    required this.events,
  });

  final UserSession? session;
  final AsyncValue<List<OrderInfo>> orders;
  final List<ModuleEvent> events;

  HomeState copyWith({
    UserSession? session,
    AsyncValue<List<OrderInfo>>? orders,
    List<ModuleEvent>? events,
  }) {
    return HomeState(
      session: session ?? this.session,
      orders: orders ?? this.orders,
      events: events ?? this.events,
    );
  }
}

class HomeController extends AutoDisposeNotifier<HomeState> {
  @override
  HomeState build() {
    ref.listen(authSessionProvider, (_, next) {
      state = state.copyWith(session: next.valueOrNull);
    });
    ref.listen(moduleEventProvider, (_, next) {
      final event = next.valueOrNull;
      if (event == null) return;
      final events = <ModuleEvent>[event, ...state.events];
      if (events.length > 8) {
        events.removeRange(8, events.length);
      }
      state = state.copyWith(events: events);
      if (event.sourceModule == 'order') {
        refreshOrderData(forceRefresh: true);
      }
    });

    final initial = HomeState(
      session: ref.read(authSessionServiceProvider).currentSession,
      orders: const AsyncValue.data(<OrderInfo>[]),
      events: const <ModuleEvent>[],
    );

    Future<void>(() => refreshOrderData(forceRefresh: false));
    return initial;
  }

  Future<void> refreshOrderData({required bool forceRefresh}) async {
    state = state.copyWith(orders: const AsyncLoading());
    final OrderQueryService orderQueryService =
        ref.read(orderQueryServiceProvider);
    final orders = await AsyncValue.guard(
      () => orderQueryService.fetchOrders(forceRefresh: forceRefresh),
    );
    state = state.copyWith(orders: orders);
  }
}
