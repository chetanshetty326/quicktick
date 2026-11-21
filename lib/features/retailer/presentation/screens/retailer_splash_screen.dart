import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/retailer_bloc.dart';
import 'retailer_auth_screen.dart';
import 'retailer_main_screen.dart';
import 'retailer_registration_screen.dart';
import 'retailer_status_screens.dart';

class RetailerSplashScreen extends StatefulWidget {
  const RetailerSplashScreen({super.key});

  @override
  State<RetailerSplashScreen> createState() => _RetailerSplashScreenState();
}

class _RetailerSplashScreenState extends State<RetailerSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeIn),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();
    _checkSessionAndNavigate();
  }

  void _navigateTo(Widget screen) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _checkSessionAndNavigate() async {
    // 1. Give minimum time for splash animation branding
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted || _hasNavigated) return;

    final authBloc = sl.isRegistered<AuthBloc>() ? sl<AuthBloc>() : context.read<AuthBloc>();
    AuthState authState = authBloc.state;

    // Trigger session check if still initial
    if (authState is AuthInitial) {
      authBloc.add(CheckAuthSessionEvent());
    }

    // Await async session resolution from AuthBloc
    if (authState is AuthInitial || authState is AuthLoading) {
      try {
        authState = await authBloc.stream
            .firstWhere((s) => s is! AuthInitial && s is! AuthLoading)
            .timeout(const Duration(milliseconds: 3000), onTimeout: () => authBloc.state);
      } catch (_) {
        authState = authBloc.state;
      }
    }

    // 2. Direct hardware Keystore fallback: inspect ISecureStorageService
    bool isRetailerLoggedIn = false;
    if (authState is AuthenticatedState && authState.user.role == UserRole.retailer) {
      isRetailerLoggedIn = true;
    } else if (sl.isRegistered<ISecureStorageService>()) {
      try {
        final storage = sl<ISecureStorageService>();
        final hasToken = (await storage.getAccessToken())?.isNotEmpty ?? false;
        final isSessionValid = await storage.isSessionValid();
        if (hasToken || isSessionValid) {
          final data = await storage.getUserData();
          final roleStr = data['role']?.toString().toLowerCase();
          if (roleStr == 'retailer') {
            isRetailerLoggedIn = true;
            final user = UserEntity(
              id: data['userId'] ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
              name: (data['name'] != null && data['name']!.trim().isNotEmpty) ? data['name']!.trim() : 'Store Partner',
              phone: data['phone'] ?? '',
              email: data['email'],
              role: UserRole.retailer,
            );
            authBloc.add(RestoreUserSessionEvent(user));
          }
        }
      } catch (_) {}
    }

    if (!mounted || _hasNavigated) return;

    // 3. If NOT logged in (e.g. after explicit user logout or fresh install), ONLY then show RetailerAuthScreen
    if (!isRetailerLoggedIn) {
      _navigateTo(const RetailerAuthScreen());
      return;
    }

    // 4. User is logged in as Retailer: NEVER ask for login screen again!
    final retailerBloc = sl.isRegistered<RetailerBloc>() ? sl<RetailerBloc>() : context.read<RetailerBloc>();
    final currentStatus = retailerBloc.state.registrationStatus;

    if (currentStatus == RetailerRegistrationStatus.approved || retailerBloc.state.profile != null) {
      _navigateTo(const RetailerMainScreen());
      return;
    } else if (currentStatus == RetailerRegistrationStatus.pendingApproval) {
      _navigateTo(RetailerAwaitingApprovalScreen(shopName: retailerBloc.state.registeredShopName));
      return;
    } else if (currentStatus == RetailerRegistrationStatus.rejected) {
      _navigateTo(const RetailerRejectedScreen());
      return;
    } else if (currentStatus == RetailerRegistrationStatus.suspended) {
      _navigateTo(const RetailerSuspendedScreen());
      return;
    }

    // Trigger status check if not yet loaded
    retailerBloc.add(const CheckRetailerStatusEvent());

    try {
      final resolvedState = await retailerBloc.stream
          .firstWhere((s) => s.registrationStatus != RetailerRegistrationStatus.checking)
          .timeout(const Duration(milliseconds: 2500));

      if (!mounted || _hasNavigated) return;

      if (resolvedState.registrationStatus == RetailerRegistrationStatus.pendingApproval) {
        _navigateTo(RetailerAwaitingApprovalScreen(shopName: resolvedState.registeredShopName));
      } else if (resolvedState.registrationStatus == RetailerRegistrationStatus.rejected) {
        _navigateTo(const RetailerRejectedScreen());
      } else if (resolvedState.registrationStatus == RetailerRegistrationStatus.suspended) {
        _navigateTo(const RetailerSuspendedScreen());
      } else if (resolvedState.registrationStatus == RetailerRegistrationStatus.notRegistered) {
        final phone = (authState is AuthenticatedState) ? authState.user.phone : null;
        _navigateTo(RetailerRegistrationScreen(initialPhone: phone));
      } else {
        _navigateTo(const RetailerMainScreen());
      }
    } catch (_) {
      // Timeout or offline: merchant is authenticated, proceed directly to RetailerMainScreen
      if (mounted && !_hasNavigated) {
        _navigateTo(const RetailerMainScreen());
      }
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
      backgroundColor: const Color(0xFF0B132B), // Deep Merchant Midnight Navy
      body: BlocListener<RetailerBloc, RetailerState>(
        listenWhen: (previous, current) =>
            previous.registrationStatus != current.registrationStatus,
        listener: (context, state) {
          if (_hasNavigated) return;
          if (state.registrationStatus == RetailerRegistrationStatus.approved) {
            _navigateTo(const RetailerMainScreen());
          } else if (state.registrationStatus == RetailerRegistrationStatus.pendingApproval) {
            _navigateTo(RetailerAwaitingApprovalScreen(shopName: state.registeredShopName));
          } else if (state.registrationStatus == RetailerRegistrationStatus.rejected) {
            _navigateTo(const RetailerRejectedScreen());
          } else if (state.registrationStatus == RetailerRegistrationStatus.suspended) {
            _navigateTo(const RetailerSuspendedScreen());
          } else if (state.registrationStatus == RetailerRegistrationStatus.notRegistered) {
            final authState = context.read<AuthBloc>().state;
            final initialPhone = authState is AuthenticatedState && authState.user.phone.isNotEmpty
                ? authState.user.phone
                : null;
            _navigateTo(RetailerRegistrationScreen(initialPhone: initialPhone));
          }
        },
        child: Stack(
        children: [
          // Ambient Glow Orbs
          Positioned(
            top: -70,
            left: -70,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF059669).withValues(alpha: 0.12),
              ),
            ),
          ),

          // Central Logo & Titles
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
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.45),
                            blurRadius: 36,
                            spreadRadius: 6,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/images/retailer_logo.png',
                        fit: BoxFit.cover,
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
                        'Quick Mart',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'MANAGE  •  GROW  •  DELIVER',
                        style: TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, color: Color(0xFF34D399), size: 14),
                            SizedBox(width: 6),
                            Text(
                              'FSSAI & GST COMPLIANT PLATFORM',
                              style: TextStyle(
                                color: Color(0xFF34D399),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Loading Indicator
          Positioned(
            bottom: 44,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: const Column(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Loading Partner Dark Stores...',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
