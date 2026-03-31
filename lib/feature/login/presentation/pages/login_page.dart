import 'package:flutter/material.dart';
import 'package:scaffold_core/core_router/core_router.dart';
import 'package:flutter_scaffold_demo/feature/login/presentation/viewmodels/login_view_model.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.viewModel,
    required this.router,
  });

  final LoginViewModel viewModel;
  final CoreRouter router;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _accountController = TextEditingController(
    text: 'demo_user',
  );
  final TextEditingController _passwordController = TextEditingController(
    text: '123456',
  );

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onViewModelChanged);
    widget.viewModel.dispose();
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    setState(() {});
    final session = widget.viewModel.session;
    if (session != null && mounted) {
      widget.router.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    return Scaffold(
      appBar: AppBar(title: const Text('Login 模块')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('UI 层只处理输入和展示'),
            const SizedBox(height: 12),
            TextField(
              controller: _accountController,
              decoration: const InputDecoration(labelText: '账号'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: '密码'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: vm.loading
                  ? null
                  : () {
                      vm.login(
                        account: _accountController.text,
                        password: _passwordController.text,
                      );
                    },
              child: Text(vm.loading ? '登录中...' : '登录'),
            ),
            if (vm.errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                vm.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
