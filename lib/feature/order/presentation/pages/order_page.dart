import 'package:flutter/material.dart';
import 'package:flutter_scaffold_demo/domain/order/order_info.dart';
import 'package:flutter_scaffold_demo/feature/order/presentation/viewmodels/order_view_model.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key, required this.viewModel});

  final OrderViewModel viewModel;

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onChanged);
    widget.viewModel.load();
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Order 模块'),
          const SizedBox(height: 8),
          Text('订单数量: ${vm.orders.length}'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: <Widget>[
              ElevatedButton(
                onPressed: vm.loading ? null : () => vm.load(forceRefresh: true),
                child: const Text('刷新订单'),
              ),
              OutlinedButton(
                onPressed: vm.loading ? null : vm.createMockOrder,
                child: const Text('创建订单'),
              ),
            ],
          ),
          if (vm.errorMessage != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              vm.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: vm.orders.length,
              itemBuilder: (BuildContext context, int index) {
                final OrderInfo order = vm.orders[index];
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
      ),
    );
  }
}
