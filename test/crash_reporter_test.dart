import 'package:crash_reporter/crash_reporter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_crash_reporter_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCrashReporterBackend backend;

  setUp(() {
    backend = FakeCrashReporterBackend();
  });

  tearDown(() {
    CrashReporter.reset();
  });

  test('init configures collection flag and initial custom keys', () async {
    await CrashReporter.init(
      backend: backend,
      config: const CrashReporterConfig(
        enabled: true,
        appName: 'psselfservice',
        environment: 'production',
        customKeys: {'build_channel': 'store', 'retry_limit': 3},
      ),
    );

    expect(CrashReporter.isInitialized, isTrue);
    expect(CrashReporter.isEnabled, isTrue);
    expect(backend.collectionEnabled, isTrue);
    expect(backend.customKeys['app_name'], 'psselfservice');
    expect(backend.customKeys['environment'], 'production');
    expect(backend.customKeys['build_channel'], 'store');
    expect(backend.customKeys['retry_limit'], 3);
  });

  test('skips recording errors and logs when disabled', () async {
    await CrashReporter.init(
      backend: backend,
      config: const CrashReporterConfig(enabled: false),
    );

    await CrashReporter.log('Should be ignored');
    await CrashReporter.recordError(
      StateError('boom'),
      StackTrace.current,
      reason: 'test',
    );

    expect(backend.collectionEnabled, isFalse);
    expect(backend.logs, isEmpty);
    expect(backend.recordedErrors, isEmpty);
  });

  test('records errors, breadcrumbs, user identity, and test crash', () async {
    await CrashReporter.init(
      backend: backend,
      config: const CrashReporterConfig(enabled: true),
    );

    await CrashReporter.setUser(
      id: 'emp_1024',
      attributes: {'department': 'engineering'},
    );
    await CrashReporter.log('Opened approvals screen');
    await CrashReporter.recordError(
      FormatException('Invalid JSON'),
      StackTrace.current,
      reason: 'Payslip parsing failed',
      information: ['endpoint: /payslip'],
    );
    CrashReporter.forceTestCrash();
    await CrashReporter.clearUser();

    expect(backend.userIdentifier, isEmpty);
    expect(backend.customKeys['department'], 'engineering');
    expect(backend.logs, ['Opened approvals screen']);
    expect(backend.recordedErrors, hasLength(1));
    expect(backend.recordedErrors.first.reason, 'Payslip parsing failed');
    expect(backend.recordedErrors.first.fatal, isFalse);
    expect(backend.crashCount, 1);
  });

  test('guard records thrown errors and rethrows them', () async {
    await CrashReporter.init(
      backend: backend,
      config: const CrashReporterConfig(enabled: true),
    );

    final result = await CrashReporter.guard(() async => 42);
    expect(result, 42);
    expect(backend.recordedErrors, isEmpty);

    await expectLater(
      () => CrashReporter.guard<void>(
        () async => throw StateError('guard failure'),
        reason: 'Load dashboard failed',
      ),
      throwsA(isA<StateError>()),
    );

    expect(backend.recordedErrors, hasLength(1));
    expect(backend.recordedErrors.first.reason, 'Load dashboard failed');
    expect(backend.recordedErrors.first.fatal, isFalse);
  });

  test('installs FlutterError.onError and chains previous handler', () async {
    FlutterErrorDetails? chainedDetails;
    final originalHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      chainedDetails = details;
    };

    try {
      await CrashReporter.init(
        backend: backend,
        config: const CrashReporterConfig(
          enabled: true,
          catchFlutterErrors: true,
          catchPlatformErrors: false,
          fatalFlutterErrors: true,
          chainPreviousHandlers: true,
        ),
      );

      final details = FlutterErrorDetails(
        exception: Exception('Render overflow'),
        stack: StackTrace.current,
      );
      FlutterError.onError!(details);

      expect(backend.recordedFlutterErrors, hasLength(1));
      expect(backend.recordedFlutterErrors.first.fatal, isTrue);
      expect(backend.recordedFlutterErrors.first.details, same(details));
      expect(chainedDetails, same(details));
    } finally {
      CrashReporter.reset();
      FlutterError.onError = originalHandler;
    }
  });

  test('installs PlatformDispatcher.instance.onError and reports as fatal',
      () async {
    Object? chainedError;
    final originalHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      chainedError = error;
      return true;
    };

    try {
      await CrashReporter.init(
        backend: backend,
        config: const CrashReporterConfig(
          enabled: true,
          catchFlutterErrors: false,
          catchPlatformErrors: true,
          chainPreviousHandlers: true,
        ),
      );

      final asyncError = StateError('Uncaught isolate/async failure');
      final handled = PlatformDispatcher.instance.onError!(
        asyncError,
        StackTrace.current,
      );

      expect(handled, isTrue);
      expect(backend.recordedErrors, hasLength(1));
      expect(backend.recordedErrors.first.error, same(asyncError));
      expect(backend.recordedErrors.first.fatal, isTrue);
      expect(chainedError, same(asyncError));
    } finally {
      CrashReporter.reset();
      PlatformDispatcher.instance.onError = originalHandler;
    }
  });
}
