import 'package:flutter/foundation.dart';

/// Abstraction over the underlying crash reporting SDK.
///
/// Implementing this interface keeps apps decoupled from Firebase Crashlytics
/// (making unit testing straightforward and allowing a future provider swap in
/// one place).
abstract class CrashReporterBackend {
  /// Enables or disables crash data collection.
  Future<void> setCollectionEnabled(bool enabled);

  /// Records a Flutter framework error.
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  });

  /// Records an error and optional stack trace.
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
    Iterable<Object> information = const [],
  });

  /// Adds a breadcrumb log message attached to subsequent crash reports.
  Future<void> log(String message);

  /// Associates subsequent crash reports with a user identifier.
  /// Pass an empty string to clear the user identifier on logout.
  Future<void> setUserIdentifier(String identifier);

  /// Sets a custom key-value pair attached to subsequent crash reports.
  Future<void> setCustomKey(String key, Object value);

  /// Forces a native crash to verify end-to-end crash reporting setup.
  void crash();
}
