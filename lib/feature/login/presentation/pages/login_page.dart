import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scaffold_demo/feature/login/presentation/viewmodels/login_view_model.dart';
import 'package:flutter_scaffold_demo/app/app_scope.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _accountController = TextEditingController(
    text: 'demo_user',
  );
  final TextEditingController _passwordController = TextEditingController(
    text: '123456',
  );

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final state = ref.watch(loginControllerProvider);

    ref.listen(loginControllerProvider, (previous, next) {
      final session = next.valueOrNull;
      if (session != null) {
        router.pop();
      }
    });

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
              onPressed: state.isLoading
                  ? null
                  : () {
                      ref.read(loginControllerProvider.notifier).login(
                        account: _accountController.text,
                        password: _passwordController.text,
                      );
                    },
              child: Text(state.isLoading ? '登录中...' : '登录'),
            ),
            if (state.hasError) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                state.error.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
