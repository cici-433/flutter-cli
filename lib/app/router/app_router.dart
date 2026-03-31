import 'package:flutter/material.dart';
import 'package:flutter_scaffold_demo/feature/login/presentation/pages/login_page.dart';
import 'package:flutter_scaffold_demo/feature/shell/presentation/pages/shell_page.dart';

class AppRouter {
  static const String shellRoute = '/';
  static const String loginRoute = '/login';

  static Map<String, WidgetBuilder> buildRoutes() {
    return <String, WidgetBuilder>{
      shellRoute: (BuildContext context) => const ShellPage(),
      loginRoute: (BuildContext context) => const LoginPage(),
    };
  }
}
