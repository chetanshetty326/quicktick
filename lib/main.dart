import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/di/service_locator.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/error_reporting_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/customer/presentation/bloc/customer_bloc.dart';
import 'features/ai_assistant/presentation/bloc/ai_assistant_bloc.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  await ErrorReportingService.initializeWithSentry(
    appRole: 'unified',
    appRunner: () async {
      // 1. Initialize Firebase & Crash Analytics
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        debugPrint('Firebase init notice: $e');
      }

      // 2. Initialize Global Error Reporting Service (Crashlytics, UI, async Dart)
      await ErrorReportingService.instance.initialize();

      // Initialize Clean Architecture Dependency Injection & Storage Tiers
      await initServiceLocator();

      try {
        await sl<IPushNotificationService>().initialize();
      } catch (e) {
        debugPrint('Push notifications notice: $e');
      }

      ErrorReportingService.runAppSafe(
        const AppErrorBoundary(
          child: LocalDailyEssentialsApp(),
        ),
      );
    },
  );
}

class LocalDailyEssentialsApp extends StatelessWidget {
  const LocalDailyEssentialsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => sl<AuthBloc>()..add(CheckAuthSessionEvent()),
        ),
        BlocProvider<CustomerBloc>(
          create: (_) => sl<CustomerBloc>(),
        ),
        BlocProvider<AiAssistantBloc>(
          create: (_) => sl<AiAssistantBloc>(),
        ),
      ],
      child: MaterialApp(
        title: 'Quick Tick',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        navigatorObservers: [SentryNavigatorObserver()],
        home: const SplashScreen(),
      ),
    );
  }
}
