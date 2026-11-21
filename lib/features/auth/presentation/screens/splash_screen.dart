import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/user_entity.dart';
import '../bloc/auth_bloc.dart';
import '../../../customer/presentation/screens/customer_main_screen.dart';
import '../../../retailer/presentation/screens/retailer_main_screen.dart';
import '../../../delivery/presentation/screens/delivery_main_screen.dart';
import 'login_screen.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../../../core/di/service_locator.dart';

class SplashScreen extends StatefulWidget {
  final Widget? destination;
  final Future<void>? initFuture;
  const SplashScreen({super.key, this.destination, this.initFuture});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  bool _hasNavigated = false;

  void _navigateTo(Widget target) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => target),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.8, curve: Curves.easeIn)),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.6, 1.0, curve: Curves.easeInOut)),
    );

    _controller.forward();
    _checkSessionAndNavigate();
  }

  Future<void> _checkSessionAndNavigate() async {
    // Safety watchdog: Force navigate after 2.5 seconds no matter what happens
    Timer(const Duration(milliseconds: 2500), () {
      if (!_hasNavigated && mounted) {
        final authBloc = sl.isRegistered<AuthBloc>() ? sl<AuthBloc>() : null;
        final authState = authBloc?.state;
        if (authState is AuthenticatedState) {
          Widget target = const CustomerMainScreen();
          if (authState.user.role == UserRole.retailer) {
            target = const RetailerMainScreen();
          } else if (authState.user.role == UserRole.deliveryPartner) {
            target = const DeliveryMainScreen();
          }
          _navigateTo(widget.destination ?? target);
        } else {
          _navigateTo(widget.destination ?? const LoginScreen());
        }
      }
    });

    try {
      if (widget.initFuture != null) {
        try {
          await widget.initFuture!.timeout(const Duration(milliseconds: 1000));
        } catch (_) {}
      }

      // Minimum splash branding time
      await Future.delayed(const Duration(milliseconds: 1200));
      if (_hasNavigated || !mounted) return;

      if (widget.destination != null) {
        _navigateTo(widget.destination!);
        return;
      }

      final authBloc = sl.isRegistered<AuthBloc>() ? sl<AuthBloc>() : context.read<AuthBloc>();
      AuthState authState = authBloc.state;

      // If auth session check has not been triggered yet, trigger it
      if (authState is AuthInitial) {
        authBloc.add(CheckAuthSessionEvent());
      }

      // If auth session check is still pending, await the resolved session state
      if (authState is AuthInitial || authState is AuthLoading) {
        try {
          authState = await authBloc.stream
              .firstWhere((s) => s is! AuthInitial && s is! AuthLoading)
              .timeout(const Duration(milliseconds: 1000), onTimeout: () => authBloc.state);
        } catch (_) {
          authState = authBloc.state;
        }
      }

      // Fast direct keystore verification fallback
      if (authState is! AuthenticatedState && sl.isRegistered<ISecureStorageService>()) {
        try {
          final storage = sl<ISecureStorageService>();
          final hasToken = (await storage.getAccessToken().timeout(const Duration(milliseconds: 600), onTimeout: () => null))?.isNotEmpty ?? false;
          final isSessionValid = await storage.isSessionValid().timeout(const Duration(milliseconds: 600), onTimeout: () => false);
          if (hasToken || isSessionValid) {
            final data = await storage.getUserData().timeout(const Duration(milliseconds: 600), onTimeout: () => {});
            final role = UserRole.fromString(data['role']);
            final cachedName = (data['name'] != null && data['name']!.trim().isNotEmpty)
                ? data['name']!.trim()
                : (role == UserRole.customer ? 'Customer' : role.displayName);
            final user = UserEntity(
              id: data['userId'] ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
              name: cachedName,
              phone: data['phone'] ?? '',
              email: data['email'],
              role: role,
            );
            authState = AuthenticatedState(user);
          }
        } catch (_) {}
      }

      if (_hasNavigated || !mounted) return;

      if (authState is AuthenticatedState) {
        Widget target;
        switch (authState.user.role) {
          case UserRole.retailer:
            target = const RetailerMainScreen();
            break;
          case UserRole.deliveryPartner:
            target = const DeliveryMainScreen();
            break;
          case UserRole.customer:
          case UserRole.admin:
            target = const CustomerMainScreen();
            break;
        }
        _navigateTo(target);
      } else {
        _navigateTo(const LoginScreen());
      }
    } catch (_) {
      _navigateTo(widget.destination ?? const LoginScreen());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF042F2E), // Deep Emerald Night
      body: Stack(
        children: [
          // Ambient Lighting Glow Orbs
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryLight.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF14B8A6).withValues(alpha: 0.12),
              ),
            ),
          ),

          // Center Animated Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.45),
                            blurRadius: 32,
                            spreadRadius: 4,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFF0F766E),
                          alignment: Alignment.center,
                          child: const Icon(Icons.bolt_rounded, size: 70, color: Color(0xFF5EEAD4)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      const Text(
                        'Quick Tick',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Daily Essentials Delivered',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: const Text(
                          '⚡ 15-MINUTE HYPERLOCAL DELIVERY',
                          style: TextStyle(
                            color: Color(0xFF5EEAD4),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Indicator
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: const Column(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2DD4BF)),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Loading fresh essentials...',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'A product from Prajnan Softwares',
                    style: TextStyle(
                      color: Color(0xFF5EEAD4),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
