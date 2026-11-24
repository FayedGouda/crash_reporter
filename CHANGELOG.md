## 1.0.0

* Initial independent release wrapping `firebase_crashlytics`.
* Global Flutter and platform/async error handlers via `CrashReporter.init`.
* Support for non-fatal errors, `CrashReporter.guard`, breadcrumbs, custom keys, and user identity.
* Swappable `CrashReporterBackend` abstraction with `FirebaseCrashlyticsBackend` and `NoopCrashReporterBackend`.
