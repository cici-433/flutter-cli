import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scaffold_demo/app/app.dart';
import 'package:flutter_scaffold_demo/app/app_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final scope = await AppScope.create();
  FlutterError.onError = (details) {
    scope.logger.error(
      'flutter_error',
      error: details.exception,
      stackTrace: details.stack,
      tag: 'flutter',
    );
  };
  runApp(
    ProviderScope(
      overrides: <Override>[
        appScopeProvider.overrideWithValue(scope),
      ],
      child: const App(),
    ),
  );
}
