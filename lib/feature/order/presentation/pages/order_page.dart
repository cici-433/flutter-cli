import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scaffold_demo/domain/order/order_info.dart';
import 'package:flutter_scaffold_demo/feature/order/presentation/viewmodels/order_view_model.dart';

class OrderPage extends ConsumerWidget {
  const OrderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(orderControllerProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (List<OrderInfo> orders) {
          final busy = ref.watch(orderControllerProvider).isLoading;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Order 模块'),
              const SizedBox(height: 8),
              Text('订单数量: ${orders.length}'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: busy
                        ? null
                        : () => ref
                            .read(orderControllerProvider.notifier)
                            .load(forceRefresh: true),
                    child: const Text('刷新订单'),
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => ref
                            .read(orderControllerProvider.notifier)
                            .createMockOrder(),
                    child: const Text('创建订单'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (BuildContext context, int index) {
                    final OrderInfo order = orders[index];
                    return ListTile(
                      dense: true,
                      title: Text(order.title),
                      subtitle: Text(order.id),
                      trailing: Text('¥${order.amount.toStringAsFixed(2)}'),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
