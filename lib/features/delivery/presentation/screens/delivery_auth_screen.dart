import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/repositories/delivery_repository.dart';
import '../bloc/delivery_bloc.dart';
import 'delivery_main_screen.dart';
import 'delivery_registration_screen.dart';
import 'delivery_status_screens.dart';
import '../../../../core/widgets/legal_policy_screen.dart';

class DeliveryAuthScreen extends StatefulWidget {
  final bool initialIsSignUp;
  const DeliveryAuthScreen({super.key, this.initialIsSignUp = false});

  @override
  State<DeliveryAuthScreen> createState() => _DeliveryAuthScreenState();
}

class _DeliveryAuthScreenState extends State<DeliveryAuthScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  late bool _isSignUp;
  bool _isOtpSent = false;
  bool _isLoading = false;
  DateTime? _lastBackPressTime;

  Future<void> _handleBackPress() async {
    final now = DateTime.now();
    if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E293B),
          elevation: 6,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
          content: const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, color: Color(0xFF38BDF8), size: 18),
              SizedBox(width: 10),
              Text(
                'Press back again to exit',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      try {
        const platform = MethodChannel('com.quicktick.app/navigation');
        await platform.invokeMethod('moveToBackground');
      } catch (_) {
        SystemNavigator.pop();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _sendOtp() {
    if (_isSignUp && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your full legal name to register'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid mobile number starting with 6, 7, 8 or 9'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    if (_isSignUp) {
      // Sign-up: no pre-check needed — new partner, proceed directly to OTP
      context.read<AuthBloc>().add(SendOtpEvent(
        phone,
        name: _nameController.text.trim(),
        isRegistration: true,
      ));
    } else {
      // Sign-in: call POST /auth/check-mobile first to validate role is DELIVERY_PARTNER
      context.read<AuthBloc>().add(CheckMobileEvent(phone));
    }
  }

  void _verifyOtpAndLogin() {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();
    if (otp.length != 6 || !RegExp(r'^\d{6}$').hasMatch(otp)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit verification OTP'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    context.read<AuthBloc>().add(LoginWithOtpEvent(
      phone: phone,
      otp: otp,
      name: _isSignUp ? _nameController.text.trim() : null,
      role: UserRole.deliveryPartner,
    ));
  }

  Future<void> _checkProfileAndNavigate() async {
    context.read<DeliveryBloc>().add(const LoadDeliveryDataEvent());

    // Call /delivery/me to determine routing according to Section 14
    try {
      final repo = sl<IDeliveryRepository>();
      final res = await repo.getProfile();
      if (!mounted) return;
      setState(() => _isLoading = false);

      res.fold(
        (failure) {
          // If profile not found, 404, or new rider -> Route to Registration with pre-filled details
          final authState = context.read<AuthBloc>().state;
          final authUser = authState is AuthenticatedState ? authState.user : null;
          final regName = _nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : (authUser?.name != null && authUser!.name.isNotEmpty && authUser.name != 'Customer' && authUser.name != 'Delivery Partner'
                  ? authUser.name
                  : null);

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => DeliveryRegistrationScreen(
                initialName: regName,
                initialPhone: _phoneController.text.trim(),
              ),
            ),
          );
        },
        (profile) {
          if (profile.isApproved && profile.status.toUpperCase() == 'APPROVED') {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DeliveryMainScreen()),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => DeliveryPendingApprovalScreen(apiProfile: profile)),
            );
          }
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final authState = context.read<AuthBloc>().state;
      final authUser = authState is AuthenticatedState ? authState.user : null;
      final regName = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : (authUser?.name != null && authUser!.name.isNotEmpty && authUser.name != 'Customer' && authUser.name != 'Delivery Partner'
              ? authUser.name
              : null);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DeliveryRegistrationScreen(
            initialName: regName,
            initialPhone: _phoneController.text.trim(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isOtpSent) {
          setState(() {
            _isOtpSent = false;
            _otpController.clear();
          });
          return;
        }
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          _handleBackPress();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is CheckMobileCompletedState) {
            // Validate check-mobile response for sign-in flow
            if (!state.exists) {
              // Number not registered at all - auto-switch to Sign Up tab
              setState(() {
                _isLoading = false;
                _isOtpSent = false;
                _isSignUp = true;
                _otpController.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('New partner mobile! Please enter your name to register.'),
                  backgroundColor: Color(0xFF38BDF8),
                  duration: Duration(seconds: 4),
                ),
              );
              return;
            }

            final role = state.role?.toUpperCase();
            if (role != null && role != 'DELIVERY_PARTNER') {
              // Registered but as a different role (RETAILER / CUSTOMER)
              setState(() {
                _isLoading = false;
                _isOtpSent = false;
              });
              final roleLabel = role == 'RETAILER' ? 'Store Partner' : 'Customer';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'This number is registered as a $roleLabel. Please use the correct QuickMart app.',
                  ),
                  backgroundColor: Colors.orange.shade800,
                  duration: const Duration(seconds: 5),
                ),
              );
              return;
            }

            // Exists and is DELIVERY_PARTNER (or role is null/unset) — proceed to OTP
            // preChecked: true skips redundant check-mobile inside SendOtpEvent handler
            context.read<AuthBloc>().add(SendOtpEvent(
              _phoneController.text.trim(),
              isRegistration: false,
              preChecked: true,
            ));
          } else if (state is OtpSentState) {
            setState(() {
              _isOtpSent = true;
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFF10B981),
                duration: const Duration(seconds: 4),
              ),
            );
          } else if (state is AuthenticatedState) {
            _checkProfileAndNavigate();
          } else if (state is AuthErrorState) {
            setState(() {
              _isLoading = false;
              _isOtpSent = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
                action: state.isNotRegistered
                    ? SnackBarAction(
                        label: 'Sign Up Now',
                        textColor: Colors.white,
                        onPressed: () {
                          setState(() {
                            _isSignUp = true;
                            _isOtpSent = false;
                            _otpController.clear();
                          });
                        },
                      )
                    : null,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width < 360 ? 14 : 24,
                  vertical: 20,
                ),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Quick Reach Header Logo
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Image.asset(
                        'assets/images/quick_reach_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => const Icon(Icons.electric_moped, size: 46, color: Color(0xFF0284C7)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'QuickReach',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'FAST • RELIABLE • ON TIME',
                    style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.8),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp ? 'New Delivery Partner Registration' : 'Delivery Partner Operations Portal',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),

                  const SizedBox(height: 24),

                  // Login / Sign Up Form Card
                  Container(
                    padding: EdgeInsets.all(MediaQuery.of(context).size.width < 360 ? 16 : 22),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Interactive Mode Switcher: Sign In vs New Partner Sign Up
                        if (!_isOtpSent)
                          Container(
                            padding: const EdgeInsets.all(4),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _isSignUp = false;
                                        _isOtpSent = false;
                                        _otpController.clear();
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: !_isSignUp ? const Color(0xFF1E293B) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        border: !_isSignUp ? Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6)) : null,
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'Sign In',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: !_isSignUp ? const Color(0xFF10B981) : Colors.white60,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _isSignUp = true;
                                        _isOtpSent = false;
                                        _otpController.clear();
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: _isSignUp ? const Color(0xFF1E293B) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        border: _isSignUp ? Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.6)) : null,
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'New Partner • Sign Up',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: _isSignUp ? const Color(0xFF38BDF8) : Colors.white60,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Section Title
                        Text(
                          _isOtpSent
                              ? 'Verify OTP'
                              : (_isSignUp ? 'Create Partner Account' : 'Partner Sign In'),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isOtpSent
                              ? 'Enter the 6-digit security OTP sent to +91 ${_phoneController.text.trim()}'
                              : (_isSignUp
                                  ? 'Enter your name and mobile to start your KYC registration.'
                                  : 'Enter your registered mobile number to continue.'),
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 18),

                        // Full Name Field (Only on Sign Up)
                        if (_isSignUp && !_isOtpSent) ...[
                          const Text(
                            'Full Legal Name *',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _nameController,
                            enabled: !_isLoading,
                            textCapitalization: TextCapitalization.words,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF38BDF8)),
                              hintText: 'Enter full name as per Aadhaar',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white24)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Flexible(
                              child: Text(
                                'Rider Mobile Number',
                                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_isOtpSent)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isOtpSent = false;
                                    _otpController.clear();
                                  });
                                },
                                child: const Text(
                                  'Change Number',
                                  style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _phoneController,
                          enabled: !_isOtpSent && !_isLoading,
                          keyboardType: TextInputType.number,
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            prefixText: '+91 ',
                            prefixStyle: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                            prefixIcon: const Icon(Icons.phone_android, color: Color(0xFF10B981)),
                            hintText: 'Enter 10-digit number',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                            counterText: '',
                            suffixIcon: _phoneController.text.length == 10
                                ? const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20)
                                : Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    child: Text(
                                      '${_phoneController.text.length}/10',
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white24)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981))),
                          ),
                        ),

                        if (_isOtpSent) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Enter Security OTP',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 8),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '••••',
                              hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 4),
                              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF10B981)),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white24)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981))),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _isLoading ? null : (_isOtpSent ? _verifyOtpAndLogin : _sendOtp),
                            child: _isLoading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _isOtpSent
                                          ? (_isSignUp ? 'Verify OTP & Complete Registration' : 'Verify OTP & Start Delivering')
                                          : (_isSignUp ? 'Send Registration OTP' : 'Send Verification OTP'),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Bottom Switcher Link
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _isOtpSent = false;
                        _otpController.clear();
                      });
                    },
                    child: Text(
                      _isSignUp
                          ? 'Already a registered partner? Sign In here ➔'
                          : 'New Partner? Sign Up & Start Delivering ➔',
                      style: TextStyle(
                        color: _isSignUp ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Legal & Privacy Notice
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text.rich(
                      TextSpan(
                        text: 'By signing up as a Delivery Partner, you agree to our ',
                        style: const TextStyle(fontSize: 11, color: Colors.white54, height: 1.4),
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
                                'Partner Agreement',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF38BDF8),
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(text: ' & '),
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
                                  color: Color(0xFF38BDF8),
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
      ),
      ),
      ),
    );
  }
}
