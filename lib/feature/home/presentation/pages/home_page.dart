import 'package:flutter/material.dart';
import 'package:scaffold_core/core_common/module_event_bus.dart';
import 'package:flutter_scaffold_demo/feature/home/presentation/viewmodels/home_view_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onChanged);
    widget.viewModel.refreshOrderData();
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
          const Text('Home 模块'),
          const SizedBox(height: 8),
          Text(vm.session == null ? '当前未登录' : '当前用户: ${vm.session!.userName}'),
          const SizedBox(height: 8),
          Text('通过 OrderQueryService 查询的订单数: ${vm.orderCount}'),
          if (vm.latestOrder != null) ...<Widget>[
            const SizedBox(height: 4),
            Text('最新订单: ${vm.latestOrder!.title}'),
          ],
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed('/login'),
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
