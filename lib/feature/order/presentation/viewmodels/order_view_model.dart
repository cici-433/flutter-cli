import 'package:scaffold_core/core_common/module_event_bus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scaffold_demo/app/app_scope.dart';
import 'package:flutter_scaffold_demo/domain/order/create_order_use_case.dart';
import 'package:flutter_scaffold_demo/domain/order/fetch_orders_use_case.dart';
import 'package:flutter_scaffold_demo/domain/order/order_info.dart';

final orderControllerProvider =
    AutoDisposeAsyncNotifierProvider<OrderController, List<OrderInfo>>(
  OrderController.new,
);

class OrderController extends AutoDisposeAsyncNotifier<List<OrderInfo>> {
  @override
  Future<List<OrderInfo>> build() async {
    return _fetchOrders(forceRefresh: false);
  }

  Future<List<OrderInfo>> _fetchOrders({required bool forceRefresh}) async {
    final FetchOrdersUseCase fetchOrdersUseCase =
        ref.read(fetchOrdersUseCaseProvider);
    final ModuleEventBus eventBus = ref.read(eventBusProvider);

    final orders = await fetchOrdersUseCase.execute(forceRefresh: forceRefresh);
    eventBus.publish(
      ModuleEvent(
        sourceModule: 'order',
        topic: 'orders_synced',
        message: '订单列表已同步，共 ${orders.length} 条',
        timestamp: DateTime.now(),
      ),
    );
    return orders;
  }

  Future<void> load({bool forceRefresh = false}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetchOrders(forceRefresh: forceRefresh),
    );
  }

  Future<void> createMockOrder() async {
    final CreateOrderUseCase createOrderUseCase =
        ref.read(createOrderUseCaseProvider);
    final ModuleEventBus eventBus = ref.read(eventBusProvider);

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final now = DateTime.now();
      final orders = await createOrderUseCase.execute(
        title: '演示订单 ${now.hour}:${now.minute}:${now.second}',
        amount: 88 + now.second.toDouble(),
      );
      final created = orders.first;
      eventBus.publish(
        ModuleEvent(
          sourceModule: 'order',
          topic: 'order_created',
          message: '新建订单 ${created.id}，金额 ${created.amount.toStringAsFixed(2)}',
          timestamp: DateTime.now(),
        ),
      );
      return orders;
    });
  }
}
