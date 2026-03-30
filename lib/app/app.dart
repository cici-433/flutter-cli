import 'package:flutter/material.dart';
import 'package:flutter_scaffold_demo/app/app_scope.dart';
import 'package:flutter_scaffold_demo/app/router/app_router.dart';

class App extends StatelessWidget {
  const App({super.key, required this.scope});

  final AppScope scope;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Layered Modular Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      initialRoute: AppRouter.shellRoute,
      routes: AppRouter.buildRoutes(scope),
    );
  }
}
