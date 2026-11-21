import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/retailer_bloc.dart';
import 'retailer_main_screen.dart';
import 'retailer_registration_screen.dart';
import 'retailer_status_screens.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../../../core/widgets/legal_policy_screen.dart';

class RetailerAuthScreen extends StatefulWidget {
  const RetailerAuthScreen({super.key});

  @override
  State<RetailerAuthScreen> createState() => _RetailerAuthScreenState();
}

class _RetailerAuthScreenState extends State<RetailerAuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  bool _isAlreadyRegistered = false;
  // Stores OTP returned by backend in dev mode — only shown in debug builds
  String _devOtp = '';
  int _timerSeconds = 30;
  Timer? _timer;
  String? _merchantName;

  @override
  void initState() {
    super.initState();
    _checkRegistrationStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkActiveSession();
      }
    });
  }

  Future<void> _checkActiveSession() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthenticatedState && authState.user.role == UserRole.retailer) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RetailerMainScreen()),
        );
      }
      return;
    }

    if (sl.isRegistered<ISecureStorageService>()) {
      try {
        final storage = sl<ISecureStorageService>();
        final hasToken = (await storage.getAccessToken())?.isNotEmpty ?? false;
        final isSessionValid = await storage.isSessionValid();
        if (hasToken || isSessionValid) {
          final data = await storage.getUserData();
          if (data['role']?.toString().toLowerCase() == 'retailer') {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const RetailerMainScreen()),
              );
            }
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _checkRegistrationStatus() async {
    final sp = await SharedPreferences.getInstance();
    final registered = sp.getBool('retailer_registered') ?? false;
    if (mounted) {
      setState(() => _isAlreadyRegistered = registered);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _sendOtp() {
    final phone = _phoneController.text.trim();
    if (phone.length != 10 || int.tryParse(phone) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit mobile number')),
      );
      return;
    }

    SharedPreferences.getInstance().then((sp) {
      sp.setString('retailer_login_phone', phone);
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 10),
            Text('Verifying mobile number...'),
          ],
        ),
        backgroundColor: Color(0xFF1E293B),
        duration: Duration(seconds: 2),
      ),
    );
    context.read<AuthBloc>().add(CheckMobileEvent(phone));
  }

  void _handleVerify() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final entered = _otpController.text.trim();
    if (entered.isEmpty || entered.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
      return;
    }

    context.read<AuthBloc>().add(
          LoginWithOtpEvent(
            name: _merchantName ?? 'Store Partner',
            phone: '+91 ${_phoneController.text.trim()}',
            otp: entered,
            role: UserRole.retailer,
          ),
        );
  }

  void _showNotRegisteredDialog(String phone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.storefront_rounded, color: Color(0xFF10B981), size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Number Not Registered',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mobile number +91 $phone is not registered yet as a merchant.',
              style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'To start selling on Quick Mart, you can register your store now or verify your number with an OTP.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, height: 1.4),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.read<AuthBloc>().add(SendOtpEvent(phone, isRegistration: true));
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF334155)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Verify with OTP', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RetailerRegistrationScreen(initialPhone: phone),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Register Store', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_otpSent,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_otpSent) {
          setState(() {
            _otpSent = false;
            _otpController.clear();
          });
          _timer?.cancel();
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark Midnight
      body: MultiBlocListener(
        listeners: [
          BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is CheckMobileCompletedState) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                final phone = _phoneController.text.trim();
                if (!state.exists) {
                  _showNotRegisteredDialog(phone);
                } else {
                  setState(() {
                    _merchantName = state.name;
                  });

                  if (state.userId != null) {
                    SharedPreferences.getInstance().then((sp) {
                      sp.setString('retailer_user_id', state.userId!);
                    });
                  }
                  context.read<AuthBloc>().add(SendOtpEvent(phone, name: state.name));
                }
              } else if (state is OtpSentState) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
                setState(() {
                  // Store OTP from backend response (available in dev/test mode only)
                  _devOtp = (state.otp != null && state.otp!.isNotEmpty) ? state.otp! : '';
                  _otpSent = true;
                  _timerSeconds = 30;
                });
                _timer?.cancel();
                _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
                  if (_timerSeconds > 0) {
                    setState(() => _timerSeconds--);
                  } else {
                    timer.cancel();
                  }
                });
              } else if (state is AuthenticatedState) {
                // Check retailer store registration status on backend
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Checking store registration status...'),
                    backgroundColor: Color(0xFF0F172A),
                    duration: Duration(seconds: 2),
                  ),
                );
                context.read<RetailerBloc>().add(const CheckRetailerStatusEvent());
              } else if (state is AuthErrorState) {
                if (state.isNotRegistered) {
                  _showNotRegisteredDialog(_phoneController.text.trim());
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.red,
                      action: SnackBarAction(
                        label: 'REGISTER STORE',
                        textColor: Colors.white,
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RetailerRegistrationScreen(
                                initialPhone: _phoneController.text.trim(),
                              ),
                            ),
                          );
                        },
                      ),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                } else {
                  final msg = state.message;
                  final isServerOrNetwork = msg.contains('500') ||
                      msg.contains('502') ||
                      msg.contains('503') ||
                      msg.contains('504') ||
                      msg.contains('SocketException') ||
                      msg.contains('Connection') ||
                      msg.toLowerCase().contains('server');
                  final displayMsg = isServerOrNetwork
                      ? 'Servers temporarily unreachable. Please check connection and try again.'
                      : msg;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(
                            isServerOrNetwork ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              displayMsg,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFFDC2626),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              }
            },
          ),
          BlocListener<RetailerBloc, RetailerState>(
            listenWhen: (previous, current) =>
                previous.registrationStatus != current.registrationStatus,
            listener: (context, state) {
              if (state.registrationStatus == RetailerRegistrationStatus.notRegistered) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RetailerRegistrationScreen(
                      initialPhone: _phoneController.text.trim().isNotEmpty
                          ? _phoneController.text.trim()
                          : null,
                    ),
                  ),
                );
              } else if (state.registrationStatus == RetailerRegistrationStatus.pendingApproval) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RetailerAwaitingApprovalScreen(shopName: state.registeredShopName),
                  ),
                );
              } else if (state.registrationStatus == RetailerRegistrationStatus.approved) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const RetailerMainScreen()),
                );
              } else if (state.registrationStatus == RetailerRegistrationStatus.rejected) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const RetailerRejectedScreen()),
                );
              } else if (state.registrationStatus == RetailerRegistrationStatus.suspended) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const RetailerSuspendedScreen()),
                );
              }
            },
          ),
        ],
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final isCheckingRetailer = context.select<RetailerBloc, bool>(
              (b) => b.state.registrationStatus == RetailerRegistrationStatus.checking,
            );
            final isLoading = state is AuthLoading || isCheckingRetailer;

            return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),

                  // Brand Badge
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/retailer_logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header Titles
                  const Text(
                    'Quick Mart Partner',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in to your merchant dashboard to manage live orders, catalog stock & daily payouts.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 28),

                  // STEP 1: Phone Field
                  if (!_otpSent) ...[
                    const Text('Registered Merchant Mobile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: const BoxDecoration(
                              border: Border(right: BorderSide(color: Color(0xFF334155))),
                            ),
                            child: const Text(
                              '+91',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              cursorColor: const Color(0xFF10B981),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5),
                              decoration: const InputDecoration(
                                hintText: '98765 43210',
                                hintStyle: TextStyle(color: Color(0xFF64748B), letterSpacing: 1),
                                counterText: '',
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Send OTP Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _sendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Send Verification OTP', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Direct Register Store Shortcut
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RetailerRegistrationScreen(
                                initialPhone: _phoneController.text.trim(),
                              ),
                            ),
                          );
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storefront_outlined, color: Color(0xFF34D399), size: 18),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'New Merchant? Register Store Directly',
                                style: TextStyle(
                                  color: Color(0xFF34D399),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // OTP input — user enters code from SMS

                    // STEP 2: 6-Digit OTP Field
                    const Text('Enter 6-Digit Verification Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      autofocus: true,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 8, color: Color(0xFF34D399)),
                      decoration: InputDecoration(
                        hintText: '••••••',
                        hintStyle: const TextStyle(color: Color(0xFF475569)),
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF334155))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
                      ),
                    ),
                    // DEV ONLY BANNER — compiled away in release builds (kDebugMode = false)
                    if (kDebugMode && _devOtp.isNotEmpty) ...[  
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1A00),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.developer_mode_rounded, color: Color(0xFFFCD34D), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('DEV MODE — OTP from server', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFFCD34D))),
                                  Text(_devOtp, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 4, color: Colors.white)),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() => _otpController.text = _devOtp),
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFFFCD34D)),
                              child: const Text('FILL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),


                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _otpSent = false),
                          child: const Text('Change Number', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        ),
                        _timerSeconds > 0
                            ? Text('Resend in ${_timerSeconds}s', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13))
                            : TextButton(
                                onPressed: _sendOtp,
                                child: const Text('Resend OTP', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                              ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Verify OTP Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _handleVerify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Verify & Access Portal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 36),

                  // OR REGISTER NEW STORE (FSSAI) - ONLY FOR NEW MERCHANTS
                  if (!_isAlreadyRegistered) ...[
                    const Row(
                      children: [
                        Expanded(child: Divider(color: Color(0xFF334155))),
                        Flexible(
                          flex: 3,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'NEW RESTAURANT OR DARK STORE?',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 9.5, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Color(0xFF334155))),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Onboard Store with FSSAI Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.verified_user_outlined, color: Color(0xFF34D399), size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Register with FSSAI Certification',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Onboard your restaurant or supermarket in 10 mins with 14-digit FSSAI license & bank details.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RetailerRegistrationScreen(
                                      initialPhone: _phoneController.text.trim().isNotEmpty
                                          ? _phoneController.text.trim()
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Start Store Onboarding', style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),
                  // Legal & Policies Note
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text.rich(
                      TextSpan(
                        text: 'By continuing, you agree to QuickTick\'s ',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.4),
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const LegalPolicyScreen(initialTabIndex: 1)),
                                );
                              },
                              child: const Text(
                                'Terms of Service',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF34D399),
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(text: ' and acknowledge our '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const LegalPolicyScreen(initialTabIndex: 0)),
                                );
                              },
                              child: const Text(
                                'Privacy Policy',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF34D399),
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  ),
),
),
);
}
}
