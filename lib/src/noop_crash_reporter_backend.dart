import 'package:flutter/foundation.dart';

import 'crash_reporter_backend.dart';

/// Safe no-op backend used on unsupported platforms (e.g. Web, Windows, Linux),
/// when Firebase has not been initialized, or during tests.
class NoopCrashReporterBackend implements CrashReporterBackend {
  const NoopCrashReporterBackend();

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
    Iterable<Object> information = const [],
  }) async {}

  @override
  Future<void> log(String message) async {}

  @override
  Future<void> setUserIdentifier(String identifier) async {}

  @override
  Future<void> setCustomKey(String key, Object value) async {}

  @override
  void crash() {}
}
