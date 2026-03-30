import 'package:flutter_scaffold_demo/domain/order/order_info.dart';
import 'package:flutter_scaffold_demo/domain/order/order_repository.dart';

class CreateOrderUseCase {
  const CreateOrderUseCase(this._repository);

  final OrderRepository _repository;

  Future<List<OrderInfo>> execute({
    required String title,
    required double amount,
  }) async {
    final created = await _repository.createOrder(title: title, amount: amount);
    final latest = <OrderInfo>[created, ..._repository.readCachedOrders()];
    await _repository.saveOrders(latest);
    return latest;
  }
}
