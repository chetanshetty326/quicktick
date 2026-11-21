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
import 'features/retailer/presentation/bloc/retailer_bloc.dart';
import 'features/retailer/presentation/screens/retailer_splash_screen.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('Firebase default init notice: $e');
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (_) {}
  }

  await ErrorReportingService.initializeWithSentry(
    appRole: 'retailer',
    appRunner: () async {
      await ErrorReportingService.instance.initialize();
      await initServiceLocator();

      if (Firebase.apps.isNotEmpty) {
        try {
          FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
          unawaited(
            sl<IPushNotificationService>()
                .initialize(role: UserRole.retailer)
                .catchError((e) => debugPrint('Push notification init: $e')),
          );
        } catch (_) {}
      }

      ErrorReportingService.runAppSafe(const RetailerApp());
    },
  );
}

class RetailerApp extends StatelessWidget {
  const RetailerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppErrorBoundary(
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (_) => sl<AuthBloc>()..add(CheckAuthSessionEvent()),
          ),
          BlocProvider<RetailerBloc>(
            create: (_) => sl<RetailerBloc>()..add(const LoadRetailerDataEvent()),
          ),
        ],
        child: MaterialApp(
          title: 'Quick Mart',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          navigatorObservers: [SentryNavigatorObserver()],
          builder: (context, child) => ConnectivityBanner(child: child ?? const SizedBox.shrink()),
          home: const RetailerSplashScreen(),
        ),
      ),
    );
  }
}
