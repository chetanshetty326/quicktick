import 'dart:async';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Global error reporting service.
/// Catches ALL unhandled errors across Flutter framework, async Dart, and platform channels,
/// and streams them directly into Firebase Crashlytics and Sentry.
class ErrorReportingService {
  ErrorReportingService._();
  static final _instance = ErrorReportingService._();
  static ErrorReportingService get instance => _instance;

  static const String sentryDsn = 'https://352ad2735fcfb6ce4de412d901f499d8@o4512315244019712.ingest.us.sentry.io/4512315275149312';

  bool _initialized = false;

  /// Global runner that starts Sentry with the appropriate appRole tag ('customer', 'retailer', 'delivery')
  static Future<void> initializeWithSentry({
    required String appRole,
    required FutureOr<void> Function() appRunner,
  }) async {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 1.0;
        options.environment = kReleaseMode ? 'production' : 'development';
        options.attachScreenshot = true;
        // Security Hardening: Redact sensitive credentials & financial data from telemetry
        options.beforeBreadcrumb = (breadcrumb, hint) {
          if (breadcrumb != null && breadcrumb.data != null) {
            final scrubbed = Map<String, dynamic>.from(breadcrumb.data!);
            const sensitiveKeys = ['authorization', 'accountnumber', 'pan', 'otp', 'password', 'token', 'refreshtoken', 'accesstoken'];
            for (final key in scrubbed.keys.toList()) {
              if (sensitiveKeys.any((s) => key.toLowerCase().contains(s))) {
                scrubbed[key] = '[REDACTED]';
              }
            }
            return breadcrumb.copyWith(data: scrubbed);
          }
          return breadcrumb;
        };
      },
      appRunner: () async {
        await Sentry.configureScope((scope) {
          scope.setTag('app_role', appRole);
        });
        unawaited(
          Sentry.captureMessage(
            'Quick Tick $appRole App Online & Connected',
            level: SentryLevel.info,
          ),
        );
        await appRunner();
      },
    );
  }

  bool get _isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Call once at app startup — before runApp().
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (_isFirebaseAvailable) {
      try {
        // Enable Crashlytics collection so the console detects the app immediately
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
        FirebaseCrashlytics.instance.log('Quick Tick Crashlytics initialized');
      } catch (e) {
        debugPrint('Firebase Crashlytics collection setup notice: $e');
      }
    }

    // 1. Flutter framework errors (widget build failures, layout errors)
    FlutterError.onError = (FlutterErrorDetails details) {
      if (_isFirebaseAvailable) {
        try {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        } catch (_) {}
      }
      if (kDebugMode) {
        // In debug mode: print full stack trace to console as normal
        FlutterError.presentError(details);
      }
      _report(
        error: details.exception,
        stackTrace: details.stack,
        context: 'FlutterError: ${details.library ?? 'unknown'}',
        summary: details.exceptionAsString(),
        fatal: !kDebugMode,
      );
    };

    // 2. Uncaught async Dart errors (Future.error, async throws not caught)
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (_isFirebaseAvailable) {
        try {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        } catch (_) {}
      }
      _report(
        error: error,
        stackTrace: stack,
        context: 'PlatformDispatcher (async/uncaught)',
        summary: error.toString(),
        fatal: true,
      );
      return true; // Returning true prevents the app from crashing
    };
  }

  /// Safe launch helper. Calls runApp() with global error handlers already registered.
  static void runAppSafe(Widget app) {
    try {
      runApp(app);
    } catch (error, stack) {
      if (instance._isFirebaseAvailable) {
        try {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        } catch (_) {}
      }
      instance._report(
        error: error,
        stackTrace: stack,
        context: 'runAppSafe (startup exception)',
        summary: error.toString(),
        fatal: true,
      );
    }
  }

  /// Sets user context in Firebase Crashlytics so crashes can be filtered by user and role.
  Future<void> setUserContext({required String userId, required String role, String? phone}) async {
    try {
      final userData = <String, dynamic>{'role': role};
      if (phone != null && phone.isNotEmpty) {
        userData['phone'] = phone;
      }
      Sentry.configureScope((scope) {
        scope.setUser(SentryUser(id: userId, data: userData));
        scope.setTag('user_role', role);
      });
    } catch (_) {}

    if (!_isFirebaseAvailable) return;
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(userId);
      await FirebaseCrashlytics.instance.setCustomKey('user_role', role);
      if (phone != null && phone.isNotEmpty) {
        await FirebaseCrashlytics.instance.setCustomKey('user_phone', phone);
      }
    } catch (_) {}
  }

  /// Custom breadcrumb log for tracking customer journey leading to a crash.
  void logBreadcrumb(String message) {
    try {
      Sentry.addBreadcrumb(Breadcrumb(message: message));
    } catch (_) {}

    if (!_isFirebaseAvailable) return;
    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (_) {}
  }

  /// Core reporting method.
  void _report({
    required Object error,
    StackTrace? stackTrace,
    required String context,
    required String summary,
    bool fatal = false,
  }) {
    // ── Console log (always in debug or when active) ─────────────────────
    debugPrint('╔══════════════════════════════════════════════════════════');
    debugPrint('║ ❌ ${fatal ? "FATAL" : "NON-FATAL"} ERROR [$context]');
    debugPrint('║ $summary');
    if (stackTrace != null) {
      debugPrint('║ Stack Trace:');
      debugPrint(stackTrace.toString());
    }
    debugPrint('╚══════════════════════════════════════════════════════════');

    // ── Stream to Sentry ─────────────────────────────────────────────────
    try {
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.setContexts('error_details', {
            'context': context,
            'summary': summary,
            'fatal': fatal,
          });
        },
      );
    } catch (_) {}

    // ── Stream to Firebase Crashlytics ────────────────────────────────────
    if (_isFirebaseAvailable) {
      try {
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          reason: context,
          fatal: fatal,
        );
      } catch (_) {}
    }
  }

  /// Manually report a caught error (e.g., from a try/catch you want tracked).
  void captureException(Object error, {StackTrace? stackTrace, String? hint, bool fatal = false}) {
    _report(
      error: error,
      stackTrace: stackTrace,
      context: 'manual capture${hint != null ? ': $hint' : ''}',
      summary: error.toString(),
      fatal: fatal,
    );
  }
}

/// A widget that wraps the entire app and shows a friendly error screen
/// instead of the default red crash screen in release mode.
class AppErrorBoundary extends StatelessWidget {
  final Widget child;
  const AppErrorBoundary({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) return child; // in debug: show normal Flutter error widget
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return _FriendlyErrorScreen(details: details);
    };
    return child;
  }
}

class _FriendlyErrorScreen extends StatelessWidget {
  final FlutterErrorDetails details;
  const _FriendlyErrorScreen({required this.details});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDED),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 56,
                  color: Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Something went wrong',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    '${details.exceptionAsString()}\n\n${details.stack.toString().split('\n').take(6).join('\n')}',
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'We\'ve logged this issue and will fix it soon.\nPlease try going back or restarting the app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),
              ElevatedButton.icon(
                onPressed: () {
                  // Pop back to previous screen if possible
                  final nav = Navigator.maybeOf(context);
                  if (nav != null && nav.canPop()) {
                    nav.pop();
                  }
                },
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Go Back', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
