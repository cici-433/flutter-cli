import 'package:flutter_scaffold_demo/domain/order/order_info.dart';

class OrderLocalDataSource {
  List<OrderInfo> _orders = <OrderInfo>[];
  DateTime? _lastSavedAt;

  Future<void> saveOrders(List<OrderInfo> orders) async {
    _orders = List<OrderInfo>.from(orders);
    _lastSavedAt = DateTime.now();
  }

  List<OrderInfo> readOrders() {
    return List<OrderInfo>.unmodifiable(_orders);
  }

  DateTime? get lastSavedAt => _lastSavedAt;
}
