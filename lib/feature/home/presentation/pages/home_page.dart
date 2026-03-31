import 'package:flutter/material.dart';
import 'package:scaffold_core/core_common/module_event_bus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scaffold_demo/app/app_scope.dart';
import 'package:flutter_scaffold_demo/app/router/app_router.dart';
import 'package:flutter_scaffold_demo/feature/home/presentation/viewmodels/home_view_model.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(homeControllerProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Home 模块'),
          const SizedBox(height: 8),
          Text(vm.session == null ? '当前未登录' : '当前用户: ${vm.session!.userName}'),
          const SizedBox(height: 8),
          vm.orders.when(
            loading: () => const Text('订单加载中...'),
            error: (error, _) => Text('订单加载失败: $error'),
            data: (orders) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('通过 OrderQueryService 查询的订单数: ${orders.length}'),
                if (orders.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text('最新订单: ${orders.first.title}'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => ref.read(routerProvider).push(AppRouter.loginRoute),
            child: Text(vm.session == null ? '去登录' : '切换账号'),
          ),
          const SizedBox(height: 16),
          const Text('模块通信事件流'),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: vm.events.length,
              itemBuilder: (BuildContext context, int index) {
                final ModuleEvent event = vm.events[index];
                return ListTile(
                  dense: true,
                  title: Text('[${event.sourceModule}] ${event.topic}'),
                  subtitle: Text(event.message),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
