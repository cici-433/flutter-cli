import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scaffold_core/scaffold_core.dart';
import 'package:flutter_scaffold_demo/app/app_scope.dart';
import 'package:flutter_scaffold_demo/domain/order/order_info.dart';

class OrderPage extends ConsumerStatefulWidget {
  const OrderPage({super.key});

  @override
  ConsumerState<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends ConsumerState<OrderPage> {
  late final CorePagedListController<OrderInfo> _controller;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _controller = CorePagedListController<OrderInfo>(
      pageSize: 10,
      fetcher: _fetchOrders,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<CorePagedListResult<OrderInfo>> _fetchOrders(
    CorePagedListQuery query,
  ) async {
    final fetchOrdersUseCase = ref.read(fetchOrdersUseCaseProvider);
    final eventBus = ref.read(eventBusProvider);
    final orders = await fetchOrdersUseCase.execute(forceRefresh: query.isRefresh);

    if (query.isRefresh || query.page == 1) {
      eventBus.publish(
        ModuleEvent(
          sourceModule: 'order',
          topic: 'orders_synced',
          message: '订单列表已同步，共 ${orders.length} 条',
          timestamp: DateTime.now(),
        ),
      );
    }

    final int start = (query.page - 1) * query.pageSize;
    if (start >= orders.length) {
      return const CorePagedListResult<OrderInfo>(
        items: <OrderInfo>[],
        hasMore: false,
      );
    }

    final List<OrderInfo> items = orders
        .skip(start)
        .take(query.pageSize)
        .toList(growable: false);

    return CorePagedListResult<OrderInfo>(
      items: items,
      hasMore: start + items.length < orders.length,
    );
  }

  Future<void> _createMockOrder() async {
    if (_creating) return;

    setState(() {
      _creating = true;
    });

    try {
      final createOrderUseCase = ref.read(createOrderUseCaseProvider);
      final eventBus = ref.read(eventBusProvider);
      final now = DateTime.now();
      final orders = await createOrderUseCase.execute(
        title: '演示订单 ${now.hour}:${now.minute}:${now.second}',
        amount: 88 + now.second.toDouble(),
      );
      final OrderInfo created = orders.first;
      eventBus.publish(
        ModuleEvent(
          sourceModule: 'order',
          topic: 'order_created',
          message: '新建订单 ${created.id}，金额 ${created.amount.toStringAsFixed(2)}',
          timestamp: DateTime.now(),
        ),
      );
      await _controller.refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建订单失败: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Order 模块'),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              return Text('已加载订单数: ${_controller.items.length}');
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: <Widget>[
              ElevatedButton(
                onPressed: _creating
                    ? null
                    : () {
                        unawaited(_controller.refresh());
                      },
                child: const Text('刷新订单'),
              ),
              OutlinedButton(
                onPressed: _creating ? null : _createMockOrder,
                child: Text(_creating ? '创建中...' : '创建订单'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: CorePagedListView<OrderInfo>(
              controller: _controller,
              showNoMoreFooter: true,
              itemBuilder: (BuildContext context, OrderInfo item, int index) {
                return ListTile(
                  dense: true,
                  title: Text(item.title),
                  subtitle: Text(item.id),
                  trailing: Text('¥${item.amount.toStringAsFixed(2)}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
