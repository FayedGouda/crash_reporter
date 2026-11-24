import 'package:flutter/foundation.dart';

/// Configuration options for [CrashReporter.init].
class CrashReporterConfig {
  const CrashReporterConfig({
    this.enabled = !kDebugMode,
    this.appName,
    this.environment,
    this.customKeys = const {},
    this.catchFlutterErrors = true,
    this.catchPlatformErrors = true,
    this.fatalFlutterErrors = true,
    this.chainPreviousHandlers = true,
  });

  /// Whether crash collection is enabled. Defaults to `false` in debug builds
  /// so local development errors don't pollute production dashboards.
  final bool enabled;

  /// Optional app name tag attached as the `app_name` custom key.
  final String? appName;

  /// Optional environment label (e.g. `production`, `development`) attached as
  /// the `environment` custom key.
  final String? environment;

  /// Extra static key-value metadata attached to every report on init.
  final Map<String, Object> customKeys;

  /// Whether to attach to [FlutterError.onError].
  final bool catchFlutterErrors;

  /// Whether to attach to [PlatformDispatcher.instance.onError].
  final bool catchPlatformErrors;

  /// Whether uncaught Flutter framework errors are marked as fatal.
  final bool fatalFlutterErrors;

  /// If `true`, preserves and invokes any previously registered
  /// [FlutterError.onError] or [PlatformDispatcher.instance.onError] handler.
  final bool chainPreviousHandlers;
}
