import 'package:flutter/material.dart';
import 'package:flutter_scaffold_demo/app/app.dart';
import 'package:flutter_scaffold_demo/app/app_scope.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final scope = AppScope.create();
  runApp(App(scope: scope));
}
