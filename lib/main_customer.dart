import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/di/service_locator.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/error_reporting_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/connectivity_banner.dart';
import 'dart:async';
import 'features/auth/domain/entities/user_entity.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/customer/presentation/bloc/customer_bloc.dart';
import 'features/ai_assistant/presentation/bloc/ai_assistant_bloc.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  // Initialize Firebase safely before error reporting and service locator
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('Firebase default init notice: $e');
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.customerAndroid,
        );
      }
    } catch (e2) {
      debugPrint('Firebase customer options init notice: $e2');
    }
  }

  await ErrorReportingService.initializeWithSentry(
    appRole: 'customer',
    appRunner: () async {
      // Initialize error reporting & Clean Architecture Service Locator
      await ErrorReportingService.instance.initialize();
      await initServiceLocator();

      // Register push notifications only if Firebase is active
      if (Firebase.apps.isNotEmpty) {
        try {
          FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
          unawaited(
            sl<IPushNotificationService>()
                .initialize(role: UserRole.customer)
                .catchError((e) => debugPrint('Push notification init: $e')),
          );
        } catch (e) {
          debugPrint('FCM background handler init: $e');
        }
      }

      ErrorReportingService.runAppSafe(const CustomerApp());
    },
  );
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppErrorBoundary(
      child: MultiBlocProvider(
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
          builder: (context, child) => ConnectivityBanner(
            child: child ?? const SizedBox.shrink(),
          ),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
