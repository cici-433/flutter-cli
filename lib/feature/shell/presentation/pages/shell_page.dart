import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scaffold_demo/feature/home/presentation/pages/home_page.dart';
import 'package:flutter_scaffold_demo/feature/mine/presentation/pages/mine_page.dart';
import 'package:flutter_scaffold_demo/feature/order/presentation/pages/order_page.dart';

class ShellPage extends ConsumerStatefulWidget {
  const ShellPage({super.key});

  @override
  ConsumerState<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends ConsumerState<ShellPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomePage(),
      const MinePage(),
      const OrderPage(),
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
