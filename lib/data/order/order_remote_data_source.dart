import 'package:scaffold_core/core_network/network_client.dart';
import 'package:flutter_scaffold_demo/domain/order/order_info.dart';

class OrderRemoteDataSource {
  const OrderRemoteDataSource(this._networkClient);

  final NetworkClient _networkClient;

  Future<List<OrderInfo>> fetchOrders() async {
    final list = await _networkClient.getList('/orders');
    return list
        .map(
          (Map<String, dynamic> item) => OrderInfo(
            id: item['id'] as String,
            title: item['title'] as String,
            amount: (item['amount'] as num).toDouble(),
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              item['createdAt'] as int,
            ),
          ),
        )
        .toList();
  }

  Future<OrderInfo> createOrder({
    required String title,
    required double amount,
  }) async {
    final response = await _networkClient.post(
      '/orders/create',
      body: <String, dynamic>{
        'title': title,
        'amount': amount,
      },
    );
    return OrderInfo(
      id: response['id'] as String,
      title: response['title'] as String,
      amount: (response['amount'] as num).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(response['createdAt'] as int),
    );
  }
}
