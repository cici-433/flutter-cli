import 'package:flutter_scaffold_demo/domain/order/order_info.dart';

abstract class OrderQueryService {
  Future<List<OrderInfo>> fetchOrders({bool forceRefresh = false});
  Future<int> fetchOrderCount({bool forceRefresh = false});
  Future<OrderInfo?> fetchLatestOrder({bool forceRefresh = false});
}
