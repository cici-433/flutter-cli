import 'package:flutter/foundation.dart';
import 'package:scaffold_core/core_common/module_event_bus.dart';
import 'package:flutter_scaffold_demo/domain/order/create_order_use_case.dart';
import 'package:flutter_scaffold_demo/domain/order/fetch_orders_use_case.dart';
import 'package:flutter_scaffold_demo/domain/order/order_info.dart';

class OrderViewModel extends ChangeNotifier {
  OrderViewModel({
    required FetchOrdersUseCase fetchOrdersUseCase,
    required CreateOrderUseCase createOrderUseCase,
    required ModuleEventBus eventBus,
  })  : _fetchOrdersUseCase = fetchOrdersUseCase,
        _createOrderUseCase = createOrderUseCase,
        _eventBus = eventBus;

  final FetchOrdersUseCase _fetchOrdersUseCase;
  final CreateOrderUseCase _createOrderUseCase;
  final ModuleEventBus _eventBus;

  bool _loading = false;
  String? _errorMessage;
  List<OrderInfo> _orders = <OrderInfo>[];

  bool get loading => _loading;
  String? get errorMessage => _errorMessage;
  List<OrderInfo> get orders => List<OrderInfo>.unmodifiable(_orders);

  Future<void> load({bool forceRefresh = false}) async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final orders = await _fetchOrdersUseCase.execute(forceRefresh: forceRefresh);
      _orders = orders;
      _eventBus.publish(
        ModuleEvent(
          sourceModule: 'order',
          topic: 'orders_synced',
          message: '订单列表已同步，共 ${orders.length} 条',
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

  Future<void> createMockOrder() async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final now = DateTime.now();
      final orders = await _createOrderUseCase.execute(
        title: '演示订单 ${now.hour}:${now.minute}:${now.second}',
        amount: 88 + now.second.toDouble(),
      );
      _orders = orders;
      final created = orders.first;
      _eventBus.publish(
        ModuleEvent(
          sourceModule: 'order',
          topic: 'order_created',
          message: '新建订单 ${created.id}，金额 ${created.amount.toStringAsFixed(2)}',
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
