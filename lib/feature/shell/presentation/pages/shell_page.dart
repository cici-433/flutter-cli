import 'package:flutter/material.dart';
import 'package:flutter_scaffold_demo/app/app_scope.dart';
import 'package:flutter_scaffold_demo/feature/home/presentation/pages/home_page.dart';
import 'package:flutter_scaffold_demo/feature/home/presentation/viewmodels/home_view_model.dart';
import 'package:flutter_scaffold_demo/feature/mine/presentation/pages/mine_page.dart';
import 'package:flutter_scaffold_demo/feature/mine/presentation/viewmodels/mine_view_model.dart';
import 'package:flutter_scaffold_demo/feature/order/presentation/pages/order_page.dart';
import 'package:flutter_scaffold_demo/feature/order/presentation/viewmodels/order_view_model.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key, required this.scope});

  final AppScope scope;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  late final HomeViewModel _homeViewModel = widget.scope.createHomeViewModel();
  late final MineViewModel _mineViewModel = widget.scope.createMineViewModel();
  late final OrderViewModel _orderViewModel = widget.scope.createOrderViewModel();
  int _index = 0;

  @override
  void dispose() {
    _homeViewModel.dispose();
    _mineViewModel.dispose();
    _orderViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(viewModel: _homeViewModel, router: widget.scope.router),
      MinePage(viewModel: _mineViewModel, router: widget.scope.router),
      OrderPage(viewModel: _orderViewModel),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('分层 + 模块化通信 Demo')),
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (int value) => setState(() => _index = value),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Mine'),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Order',
          ),
        ],
      ),
    );
  }
}
