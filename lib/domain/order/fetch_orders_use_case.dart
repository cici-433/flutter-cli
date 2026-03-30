import 'package:flutter_scaffold_demo/domain/order/order_info.dart';
import 'package:flutter_scaffold_demo/domain/order/order_repository.dart';

class FetchOrdersUseCase {
  const FetchOrdersUseCase(this._repository);

  final OrderRepository _repository;

  Future<List<OrderInfo>> execute({bool forceRefresh = false}) {
    return _repository.fetchOrders(forceRefresh: forceRefresh);
  }
}
