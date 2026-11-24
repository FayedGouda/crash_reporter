import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'crash_reporter_backend.dart';
import 'crash_reporter_config.dart';
import 'firebase_crashlytics_backend.dart';
import 'noop_crash_reporter_backend.dart';

/// Shared facade for initializing and reporting errors across Flutter apps.
///
/// Call [CrashReporter.init] once right after `Firebase.initializeApp(...)`:
/// ```dart
/// await CrashReporter.init(
///   config: CrashReporterConfig(
///     enabled: !kDebugMode,
///     appName: 'psselfservice',
///     environment: 'production',
///   ),
/// );
/// ```
class CrashReporter {
  CrashReporter._();

  static CrashReporterBackend _backend = const NoopCrashReporterBackend();
  static bool _isInitialized = false;
  static bool _isEnabled = false;

  static FlutterExceptionHandler? _previousFlutterErrorHandler;
  static bool Function(Object, StackTrace)? _previousPlatformErrorHandler;
  static bool _flutterHandlerInstalled = false;
  static bool _platformHandlerInstalled = false;

  /// Whether [init] has completed.
  static bool get isInitialized => _isInitialized;

  /// Whether crash reporting is currently active.
  static bool get isEnabled => _isEnabled;

  /// Whether the current platform is supported by Firebase Crashlytics.
  static bool get isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Initializes crash reporting and registers global Flutter & platform error
  /// handlers.
  ///
  /// Must be called after `Firebase.initializeApp(...)` when using the default
  /// [FirebaseCrashlyticsBackend]. If Firebase is not initialized or the
  /// platform is unsupported, safely falls back to [NoopCrashReporterBackend]
  /// so app startup is never disrupted.
  static Future<void> init({
    CrashReporterConfig config = const CrashReporterConfig(),
    CrashReporterBackend? backend,
  }) async {
    _backend = _resolveBackend(backend);
    _isEnabled = config.enabled;

    await _safeRun(() => _backend.setCollectionEnabled(config.enabled));

    final initialKeys = <String, Object>{
      if (config.appName != null && config.appName!.isNotEmpty)
        'app_name': config.appName!,
      if (config.environment != null && config.environment!.isNotEmpty)
        'environment': config.environment!,
      ...config.customKeys,
    };

    if (initialKeys.isNotEmpty) {
      await setCustomKeys(initialKeys);
    }

    if (config.catchFlutterErrors) {
      _installFlutterErrorHandler(
        fatal: config.fatalFlutterErrors,
        chainPrevious: config.chainPreviousHandlers,
      );
    }

    if (config.catchPlatformErrors) {
      _installPlatformErrorHandler(
        chainPrevious: config.chainPreviousHandlers,
      );
    }

    _isInitialized = true;
  }

  /// Dynamically enables or disables crash collection at runtime.
  static Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    await _safeRun(() => _backend.setCollectionEnabled(enabled));
  }

  /// Records a handled or unhandled error with an optional stack trace.
  static Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
    Iterable<Object> information = const [],
  }) async {
    if (!_isEnabled) return;
    await _safeRun(
      () => _backend.recordError(
        error,
        stackTrace ?? StackTrace.current,
        reason: reason,
        fatal: fatal,
        information: information,
      ),
    );
  }

  /// Records a [FlutterErrorDetails] report directly.
  static Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {
    if (!_isEnabled) return;
    await _safeRun(
      () => _backend.recordFlutterError(details, fatal: fatal),
    );
  }

  /// Adds a breadcrumb log message included in the next crash report.
  static Future<void> log(String message) async {
    if (!_isEnabled || message.isEmpty) return;
    await _safeRun(() => _backend.log(message));
  }

  /// Attaches a user identifier (avoid raw PII like passwords/tokens; prefer
  /// internal employee/user IDs) and optional user attributes.
  static Future<void> setUser({
    required String id,
    Map<String, Object>? attributes,
  }) async {
    await _safeRun(() => _backend.setUserIdentifier(id));
    if (attributes != null && attributes.isNotEmpty) {
      await setCustomKeys(attributes);
    }
  }

  /// Clears the associated user identifier (call on logout).
  static Future<void> clearUser() async {
    await _safeRun(() => _backend.setUserIdentifier(''));
  }

  /// Attaches a single custom key-value pair to crash reports.
  static Future<void> setCustomKey(String key, Object value) async {
    if (key.isEmpty) return;
    await _safeRun(() => _backend.setCustomKey(key, _sanitizeValue(value)));
  }

  /// Attaches multiple custom key-value pairs to crash reports.
  static Future<void> setCustomKeys(Map<String, Object> keys) async {
    for (final entry in keys.entries) {
      await setCustomKey(entry.key, entry.value);
    }
  }

  /// Runs [action], records any thrown error to Crashlytics, and rethrows it
  /// so calling code can still handle it normally.
  static Future<T> guard<T>(
    Future<T> Function() action, {
    String? reason,
    bool fatal = false,
    Iterable<Object> information = const [],
  }) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      await recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: fatal,
        information: information,
      );
      rethrow;
    }
  }

  /// Triggers an immediate native test crash to verify Firebase Console setup.
  /// Only use temporarily during verification.
  static void forceTestCrash() {
    _backend.crash();
  }

  /// Resets internal state and restores previous global error handlers.
  @visibleForTesting
  static void reset() {
    if (_flutterHandlerInstalled) {
      FlutterError.onError = _previousFlutterErrorHandler;
      _previousFlutterErrorHandler = null;
      _flutterHandlerInstalled = false;
    }
    if (_platformHandlerInstalled) {
      PlatformDispatcher.instance.onError = _previousPlatformErrorHandler;
      _previousPlatformErrorHandler = null;
      _platformHandlerInstalled = false;
    }
    _backend = const NoopCrashReporterBackend();
    _isInitialized = false;
    _isEnabled = false;
  }

  static CrashReporterBackend _resolveBackend(CrashReporterBackend? custom) {
    if (custom != null) return custom;

    if (!isSupportedPlatform) {
      debugPrint(
        '[CrashReporter] Platform not supported by Crashlytics. '
        'Using no-op backend.',
      );
      return const NoopCrashReporterBackend();
    }

    if (Firebase.apps.isEmpty) {
      debugPrint(
        '[CrashReporter] Firebase has not been initialized before '
        'CrashReporter.init(). Using no-op backend.',
      );
      return const NoopCrashReporterBackend();
    }

    return FirebaseCrashlyticsBackend();
  }

  static void _installFlutterErrorHandler({
    required bool fatal,
    required bool chainPrevious,
  }) {
    if (!_flutterHandlerInstalled) {
      _previousFlutterErrorHandler = FlutterError.onError;
      _flutterHandlerInstalled = true;
    }
    final previous = _previousFlutterErrorHandler;

    FlutterError.onError = (FlutterErrorDetails details) {
      if (_isEnabled) {
        unawaited(_safeRun(() => _backend.recordFlutterError(details, fatal: fatal)));
      }
      if (chainPrevious && previous != null) {
        previous(details);
      } else {
        FlutterError.presentError(details);
      }
    };
  }

  static void _installPlatformErrorHandler({required bool chainPrevious}) {
    if (!_platformHandlerInstalled) {
      _previousPlatformErrorHandler = PlatformDispatcher.instance.onError;
      _platformHandlerInstalled = true;
    }
    final previous = _previousPlatformErrorHandler;

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (_isEnabled) {
        unawaited(
          _safeRun(
            () => _backend.recordError(
              error,
              stack,
              reason: 'Uncaught platform/async error',
              fatal: true,
            ),
          ),
        );
      }
      if (chainPrevious && previous != null) {
        return previous(error, stack);
      }
      return true;
    };
  }

  static Object _sanitizeValue(Object value) {
    if (value is String || value is num || value is bool) {
      return value;
    }
    return value.toString();
  }

  static Future<void> _safeRun(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('[CrashReporter] Internal error: $e');
    }
  }
}
