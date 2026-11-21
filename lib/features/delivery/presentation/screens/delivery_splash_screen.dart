import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import 'dart:convert';
import '../../domain/entities/delivery_models.dart';
import '../../domain/repositories/delivery_repository.dart';
import '../bloc/delivery_bloc.dart';
import 'delivery_auth_screen.dart';
import 'delivery_main_screen.dart';
import 'delivery_registration_screen.dart';
import 'delivery_status_screens.dart';

class DeliverySplashScreen extends StatefulWidget {
  const DeliverySplashScreen({super.key});

  @override
  State<DeliverySplashScreen> createState() => _DeliverySplashScreenState();
}

class _DeliverySplashScreenState extends State<DeliverySplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainAnimController;
  late AnimationController _pulseAnimController;
  late AnimationController _progressController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _logoRotateAnimation;
  late Animation<Offset> _titleSlideAnimation;
  late Animation<double> _titleFadeAnimation;
  late Animation<Offset> _tagSlideAnimation;
  late Animation<double> _tagFadeAnimation;
  late Animation<double> _pulseRingScale;
  late Animation<double> _pulseRingOpacity;

  bool _isAutoLoggingIn = false;
  String _loggingInStatus = 'Logging in...';

  @override
  void initState() {
    super.initState();

    // 1. Main entrance sequence controller
    _mainAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // 2. Continuous ambient pulse controller
    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: false);

    // 3. Telemetry progress line controller
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..forward();

    // Logo Staggered Animations
    _logoScaleAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainAnimController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainAnimController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
      ),
    );

    _logoRotateAnimation = Tween<double>(begin: -0.08, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainAnimController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    // Pulse Ring Animations
    _pulseRingScale = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _pulseAnimController, curve: Curves.easeOutQuad),
    );

    _pulseRingOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _pulseAnimController, curve: Curves.easeOutQuad),
    );

    // Title Text Animations
    _titleSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _mainAnimController,
        curve: const Interval(0.4, 0.85, curve: Curves.easeOutQuart),
      ),
    );

    _titleFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainAnimController,
        curve: const Interval(0.4, 0.85, curve: Curves.easeIn),
      ),
    );

    // Tag Badge Animations
    _tagSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _mainAnimController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _tagFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainAnimController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    _mainAnimController.forward();

    // Check for saved session and trigger auto-login
    _checkSavedSessionAndNavigate();
  }

  Future<void> _checkSavedSessionAndNavigate() async {
    try {
      if (sl.isRegistered<ISecureStorageService>()) {
        final storage = sl<ISecureStorageService>();
        final isValid = await storage.isSessionValid();
        final token = await storage.getAccessToken();

        if (isValid && token != null && token.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _isAutoLoggingIn = true;
            _loggingInStatus = 'Logging in...';
          });

          // Restore session in AuthBloc & DeliveryBloc
          context.read<AuthBloc>().add(CheckAuthSessionEvent());
          context.read<DeliveryBloc>().add(const LoadDeliveryDataEvent());

          Map<String, dynamic> userData = {};
          try {
            userData = await storage.getUserData();
          } catch (_) {}
          final savedName = userData['name'];
          final savedPhone = userData['phone'];

          // Verify with backend /delivery/me
          Widget targetScreen = const DeliveryAuthScreen();
          try {
            if (sl.isRegistered<IDeliveryRepository>()) {
              final repo = sl<IDeliveryRepository>();
              final profRes = await repo.getProfile();
              await profRes.fold(
                (failure) async {
                  if (failure.statusCode == 401 ||
                      failure.message.toLowerCase().contains('unauthorized') ||
                      failure.message.toLowerCase().contains('unauthenticated')) {
                    targetScreen = const DeliveryAuthScreen();
                  } else if (failure.statusCode == 404 ||
                      failure.message.toLowerCase().contains('not found')) {
                    targetScreen = DeliveryRegistrationScreen(
                      initialName: savedName,
                      initialPhone: savedPhone,
                    );
                  } else {
                    // Network failure or temporary server issue (5xx/timeout) with valid token
                    // Default to DeliveryMainScreen so cached data or NetworkAndServerErrorView is presented with Retry
                    targetScreen = const DeliveryMainScreen();
                    try {
                      final clean = savedPhone?.replaceAll(RegExp(r'[^0-9]'), '');
                      final last10 = clean != null && clean.length > 10 ? clean.substring(clean.length - 10) : clean;
                      String? rawKyc;
                      if (sl.isRegistered<ISecureStorageService>()) {
                        rawKyc = await sl<ISecureStorageService>().getRiderKycData(phoneSuffix: last10);
                      }
                      if (rawKyc != null && rawKyc.isNotEmpty) {
                        final kycMap = jsonDecode(rawKyc) as Map<String, dynamic>;
                        final restoredKyc = RiderKYCEntity.fromJson(kycMap);
                        final rPhone = restoredKyc.phone.replaceAll(RegExp(r'[^0-9]'), '');
                        if (last10 == null || rPhone.endsWith(last10)) {
                          if (restoredKyc.kycStatus == KYCStatus.verified) {
                            targetScreen = const DeliveryMainScreen();
                          } else {
                            targetScreen = DeliveryPendingApprovalScreen(kycData: restoredKyc);
                          }
                        }
                      }
                    } catch (_) {}
                  }
                },
                (profile) async {
                  if (profile.isApproved && profile.status.toUpperCase() == 'APPROVED') {
                    targetScreen = const DeliveryMainScreen();
                  } else {
                    targetScreen = DeliveryPendingApprovalScreen(apiProfile: profile);
                  }
                },
              );
            }
          } catch (_) {
            targetScreen = const DeliveryAuthScreen();
          }

          // Allow visual transition
          await Future.delayed(const Duration(milliseconds: 1600));
          if (!mounted) return;
          _navigateTo(targetScreen);
          return;
        }
      }
    } catch (_) {}

    // No valid saved session -> wait for splash sequence and route to login
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    _navigateTo(const DeliveryAuthScreen());
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (ctx, anim, secAnim) => screen,
        transitionsBuilder: (ctx, animation, secAnim, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _mainAnimController.dispose();
    _pulseAnimController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D), // Ultra Dark Premium Slate
      body: Stack(
        children: [
          // 1. Ambient Background Glow Orbs
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF10B981).withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF38BDF8).withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 2. Central Animated Brand Hero
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated Glowing Badge with Pulse Rings
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Expanding Pulse Ring
                    AnimatedBuilder(
                      animation: _pulseAnimController,
                      builder: (ctx, child) {
                        return Transform.scale(
                          scale: _pulseRingScale.value,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: _pulseRingOpacity.value),
                                width: 2.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Main App Icon Container with Quick Reach Logo
                    FadeTransition(
                      opacity: _logoFadeAnimation,
                      child: ScaleTransition(
                        scale: _logoScaleAnimation,
                        child: RotationTransition(
                          turns: _logoRotateAnimation,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                                  blurRadius: 32,
                                  spreadRadius: 4,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: Image.asset(
                                'assets/images/quick_reach_logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (ctx, err, stack) => Container(
                                  color: const Color(0xFF0284C7),
                                  child: const Center(
                                    child: Icon(
                                      Icons.electric_moped,
                                      size: 54,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Staggered Title Animation
                SlideTransition(
                  position: _titleSlideAnimation,
                  child: FadeTransition(
                    opacity: _titleFadeAnimation,
                    child: Column(
                      children: [
                        const Text(
                          'QuickReach',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            shadows: [
                              Shadow(
                                color: Color(0xFF38BDF8),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'FAST • RELIABLE • ON TIME',
                          style: TextStyle(
                            color: const Color(0xFFF59E0B),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Delivering Smiles, Every Mile! 📦',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Staggered Tag Badge Animation
                SlideTransition(
                  position: _tagSlideAnimation,
                  child: FadeTransition(
                    opacity: _tagFadeAnimation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF10B981).withValues(alpha: 0.25),
                            const Color(0xFF38BDF8).withValues(alpha: 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, color: Color(0xFF34D399), size: 14),
                          SizedBox(width: 4),
                          Text(
                            'DELIVERY PARTNER NETWORK',
                            style: TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Smooth Neon Telemetry Progress Track
                FadeTransition(
                  opacity: _tagFadeAnimation,
                  child: Container(
                    width: 160,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: AnimatedBuilder(
                      animation: _progressController,
                      builder: (ctx, child) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 160 * _progressController.value,
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF38BDF8), Color(0xFF10B981)],
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.7),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                if (_isAutoLoggingIn) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _loggingInStatus,
                        style: const TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Authenticating secure rider session...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 3. Bottom Version & Security Footer
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _tagFadeAnimation,
              child: const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 12),
                    SizedBox(width: 6),
                    Text(
                      'AI Biometric Verification & Real-time GPS Radar',
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
          ),
        ],
      ),
    );
  }
}

