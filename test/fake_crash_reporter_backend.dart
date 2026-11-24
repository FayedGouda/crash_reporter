import 'package:crash_reporter/crash_reporter.dart';
import 'package:flutter/foundation.dart';

class RecordedError {
  const RecordedError({
    required this.error,
    required this.stackTrace,
    required this.reason,
    required this.fatal,
    required this.information,
  });

  final Object error;
  final StackTrace? stackTrace;
  final String? reason;
  final bool fatal;
  final List<Object> information;
}

class RecordedFlutterError {
  const RecordedFlutterError({
    required this.details,
    required this.fatal,
  });

  final FlutterErrorDetails details;
  final bool fatal;
}

class FakeCrashReporterBackend implements CrashReporterBackend {
  bool? collectionEnabled;
  String? userIdentifier;
  int crashCount = 0;

  final List<RecordedError> recordedErrors = [];
  final List<RecordedFlutterError> recordedFlutterErrors = [];
  final List<String> logs = [];
  final Map<String, Object> customKeys = {};

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    collectionEnabled = enabled;
  }

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {
    recordedFlutterErrors.add(
      RecordedFlutterError(details: details, fatal: fatal),
    );
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
    Iterable<Object> information = const [],
  }) async {
    recordedErrors.add(
      RecordedError(
        error: error,
        stackTrace: stackTrace,
        reason: reason,
        fatal: fatal,
        information: information.toList(),
      ),
    );
  }

  @override
  Future<void> log(String message) async {
    logs.add(message);
  }

  @override
  Future<void> setUserIdentifier(String identifier) async {
    userIdentifier = identifier;
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {
    customKeys[key] = value;
  }

  @override
  void crash() {
    crashCount++;
  }
}
