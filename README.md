# crash_reporter

Independent, lightweight Flutter package wrapping **Firebase Crashlytics** so any Flutter app can add consistent crash reporting in a few lines with zero extra state-management or HTTP dependencies.

Each host app keeps its own separate Firebase project and calls `Firebase.initializeApp(...)` as usual — `crash_reporter` automatically attaches to that app's Firebase instance.

---

## Features

- **Zero extra dependencies** — only `firebase_core` and `firebase_crashlytics` (works with any state management or HTTP library)
- **One-call setup** (`CrashReporter.init(...)`) wiring both `FlutterError.onError` and `PlatformDispatcher.instance.onError`
- **Debug-safe by default** (`enabled: !kDebugMode`) so local development crashes don't pollute production dashboards
- **Graceful fallback** to a no-op backend on unsupported platforms (Web/Windows/Linux) or if Firebase hasn't been initialized
- **Preserves existing error handlers** (`chainPreviousHandlers: true`)
- **Swappable backend interface** (`CrashReporterBackend`) for easy unit testing and future provider migration

---

## 1. Add to Any Flutter App (via Git)

Add this repository to your app's `pubspec.yaml`:

```yaml
dependencies:
  crash_reporter:
    git:
      url: https://github.com/<your-org>/crash_reporter.git
      ref: main # or pin to a release tag like v1.0.0
```

Then run:

```bash
flutter pub get
```

---

## 2. One-Time Native Setup Per App

Because each app has its own Firebase project:

1. In that app's **Firebase Console**, go to **Release & Monitor → Crashlytics** and click **Enable Crashlytics**.
2. Run `flutterfire configure` in the app root (this registers the app, generates `firebase_options.dart`, adds the Android Crashlytics Gradle plugin, and configures the iOS dSYM upload Build Phase).
3. On iOS, run `cd ios && pod install`.

---

## 3. Initialize in Dart

Call `CrashReporter.init()` right after `Firebase.initializeApp(...)`:

```dart
import 'package:crash_reporter/crash_reporter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future<void> initializeFirebaseServices() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await CrashReporter.init(
    config: CrashReporterConfig(
      enabled: !kDebugMode,
      appName: 'my_app_name',
      environment: kReleaseMode ? 'production' : 'development',
    ),
  );
}
```

---

## 4. Common Usage

### User Context & Breadcrumbs

```dart
// On login (prefer internal employee/user ID over sensitive PII)
await CrashReporter.setUser(
  id: employeeId,
  attributes: {'role': 'manager'},
);

// Breadcrumbs leading up to a crash
await CrashReporter.log('Opened payslip details');

// On logout
await CrashReporter.clearUser();
```

### Reporting Handled (Non-Fatal) Errors

```dart
try {
  await loadPayslip();
} catch (e, st) {
  await CrashReporter.recordError(e, st, reason: 'Failed to load payslip');
}

// Or using CrashReporter.guard (records and rethrows automatically):
final payslip = await CrashReporter.guard(
  () => fetchPayslip(),
  reason: 'Failed to fetch payslip',
);
```

### Optional Snippets (Copy Only Into Apps That Use Bloc or Dio)

**Bloc / Cubit:**
```dart
class AppBlocObserver extends BlocObserver {
  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    CrashReporter.recordError(error, stackTrace, reason: 'Bloc error: ${bloc.runtimeType}');
    super.onError(bloc, error, stackTrace);
  }
}
```

**Dio (5xx & unexpected errors):**
```dart
dio.interceptors.add(
  InterceptorsWrapper(
    onError: (err, handler) {
      if (err.type != DioExceptionType.cancel && (err.response?.statusCode ?? 500) >= 500) {
        CrashReporter.recordError(err, err.stackTrace, reason: 'HTTP ${err.requestOptions.path}');
      }
      handler.next(err);
    },
  ),
);
```

### Verify Setup

Temporarily call `CrashReporter.forceTestCrash()` in a profile/release build (or with `enabled: true`), reopen the app once, and confirm the crash appears in your Firebase Console.
