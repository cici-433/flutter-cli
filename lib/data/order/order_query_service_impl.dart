import 'package:flutter_scaffold_demo/domain/order/fetch_orders_use_case.dart';
import 'package:flutter_scaffold_demo/domain/order/order_info.dart';
import 'package:flutter_scaffold_demo/domain/order/order_query_service.dart';

class OrderQueryServiceImpl implements OrderQueryService {
  const OrderQueryServiceImpl(this._fetchOrdersUseCase);

  final FetchOrdersUseCase _fetchOrdersUseCase;

  @override
  Future<List<OrderInfo>> fetchOrders({bool forceRefresh = false}) {
    return _fetchOrdersUseCase.execute(forceRefresh: forceRefresh);
  }

  @override
  Future<int> fetchOrderCount({bool forceRefresh = false}) async {
    final orders = await _fetchOrdersUseCase.execute(forceRefresh: forceRefresh);
    return orders.length;
  }

  @override
  Future<OrderInfo?> fetchLatestOrder({bool forceRefresh = false}) async {
    final orders = await _fetchOrdersUseCase.execute(forceRefresh: forceRefresh);
    if (orders.isEmpty) {
      return null;
    }
    return orders.first;
  }
}
