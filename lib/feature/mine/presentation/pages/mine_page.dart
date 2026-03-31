import 'package:flutter/material.dart';
import 'package:scaffold_core/core_router/core_router.dart';
import 'package:flutter_scaffold_demo/app/router/app_router.dart';
import 'package:flutter_scaffold_demo/feature/mine/presentation/viewmodels/mine_view_model.dart';

class MinePage extends StatefulWidget {
  const MinePage({
    super.key,
    required this.viewModel,
    required this.router,
  });

  final MineViewModel viewModel;
  final CoreRouter router;

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onChanged);
    widget.viewModel.refreshOrderCount();
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
          const Text('Mine 模块'),
          const SizedBox(height: 8),
          Text(vm.session == null ? '当前未登录' : '账号: ${vm.session!.userName}'),
          const SizedBox(height: 8),
          Text('通过 OrderQueryService 获取的订单总数: ${vm.orderCount}'),
          const SizedBox(height: 8),
          Text('最近认证事件: ${vm.lastAuthEvent}'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: <Widget>[
              ElevatedButton(
                onPressed: () => widget.router.push(AppRouter.loginRoute),
                child: const Text('登录/切换'),
              ),
              OutlinedButton(
                onPressed: vm.session == null ? null : vm.logout,
                child: const Text('退出登录'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
