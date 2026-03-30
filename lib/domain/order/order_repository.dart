import 'package:flutter_scaffold_demo/domain/order/order_info.dart';

abstract class OrderRepository {
  Future<List<OrderInfo>> fetchOrders({bool forceRefresh = false});
  Future<OrderInfo> createOrder({
    required String title,
    required double amount,
  });
  Future<void> saveOrders(List<OrderInfo> orders);
  List<OrderInfo> readCachedOrders();
}
