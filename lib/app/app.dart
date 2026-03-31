import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scaffold_demo/app/app_scope.dart';
import 'package:flutter_scaffold_demo/app/router/app_router.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppScope scope = ref.watch(appScopeProvider);
    return MaterialApp(
      title: 'Layered Modular Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      navigatorKey: scope.router.navigatorKey,
      initialRoute: AppRouter.shellRoute,
      routes: AppRouter.buildRoutes(),
    );
  }
}
