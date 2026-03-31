import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scaffold_demo/app/router/app_router.dart';
import 'package:flutter_scaffold_demo/app/app_scope.dart';
import 'package:flutter_scaffold_demo/feature/mine/presentation/viewmodels/mine_view_model.dart';

class MinePage extends ConsumerWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(mineControllerProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Mine 模块'),
          const SizedBox(height: 8),
          Text(vm.session == null ? '当前未登录' : '账号: ${vm.session!.userName}'),
          const SizedBox(height: 8),
          vm.orderCount.when(
            loading: () => const Text('订单总数加载中...'),
            error: (error, _) => Text('订单总数加载失败: $error'),
            data: (count) => Text('通过 OrderQueryService 获取的订单总数: $count'),
          ),
          const SizedBox(height: 8),
          Text('最近认证事件: ${vm.lastAuthEvent}'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: <Widget>[
              ElevatedButton(
                onPressed: () => ref.read(routerProvider).push(AppRouter.loginRoute),
                child: const Text('登录/切换'),
              ),
              OutlinedButton(
                onPressed: vm.session == null
                    ? null
                    : () => ref.read(mineControllerProvider.notifier).logout(),
                child: const Text('退出登录'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
