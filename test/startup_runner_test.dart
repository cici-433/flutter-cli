import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scaffold_core/scaffold_core.dart';

void main() {
  test('runs tasks with dependency order', () async {
    final events = <String>[];
    final release = Completer<void>();

    final runner = StartupRunner(
      tasks: <StartupTask>[
        StartupTask(
          id: 'a',
          phase: StartupPhase.main,
          run: (_) => events.add('a'),
        ),
        StartupTask(
          id: 'b',
          phase: StartupPhase.main,
          dependsOn: const <String>['a'],
          run: (_) async {
            events.add('b_start');
            await release.future;
            events.add('b_end');
          },
        ),
        StartupTask(
          id: 'c',
          phase: StartupPhase.main,
          dependsOn: const <String>['a'],
          run: (_) async {
            events.add('c_start');
            await release.future;
            events.add('c_end');
          },
        ),
      ],
    );

    final reportFuture = runner.run(phases: const <StartupPhase>[StartupPhase.main]);

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(events.first, 'a');
    expect(events.contains('b_start'), isTrue);
    expect(events.contains('c_start'), isTrue);

    release.complete();
    final report = await reportFuture;
    expect(report.hasFailure, isFalse);
  });

  test('non-critical failure does not stop runner', () async {
    final events = <String>[];

    final runner = StartupRunner(
      tasks: <StartupTask>[
        StartupTask(
          id: 'bad',
          critical: false,
          run: (_) => throw StateError('boom'),
        ),
        StartupTask(
          id: 'good',
          run: (_) => events.add('good'),
        ),
      ],
    );

    final report = await runner.run(phases: const <StartupPhase>[StartupPhase.main]);
    expect(events, <String>['good']);
    expect(report.hasFailure, isTrue);
  });

  test('critical failure throws StartupRunException', () async {
    final runner = StartupRunner(
      tasks: <StartupTask>[
        StartupTask(
          id: 'bad',
          critical: true,
          run: (_) => throw StateError('boom'),
        ),
        StartupTask(
          id: 'good',
          run: (_) {},
        ),
      ],
    );

    await expectLater(
      () => runner.run(phases: const <StartupPhase>[StartupPhase.main]),
      throwsA(isA<StartupRunException>()),
    );
  });
}

