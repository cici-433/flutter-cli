import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scaffold_demo/app/app_scope.dart';
import 'package:flutter_scaffold_demo/app/router/app_router.dart';

/// 应用根组件。
///
/// 使用有状态的 Consumer 组件，是为了在生命周期内启动和释放深链监听。
class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

/// 应用根组件状态。
class _AppState extends ConsumerState<App> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 等首帧完成后再启动深链监听，避免在 navigator 尚未挂载时抢先触发跳转。
      unawaited(ref.read(appScopeProvider).deepLinkCoordinator.start());
    });
  }

  @override
  void dispose() {
    // 页面销毁时释放深链订阅，避免重复监听。
    unawaited(ref.read(appScopeProvider).deepLinkCoordinator.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppScope scope = ref.watch(appScopeProvider);
    return MaterialApp(
      title: 'Layered Modular Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      navigatorKey: scope.router.navigatorKey,
      initialRoute: AppRouter.shellRoute,
      onGenerateRoute: scope.routeRegistry.onGenerateRoute,
      onUnknownRoute: scope.routeRegistry.onUnknownRoute,
    );
  }
}
