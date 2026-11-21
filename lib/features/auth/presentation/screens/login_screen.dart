import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/user_entity.dart';
import '../bloc/auth_bloc.dart';
import '../../../customer/presentation/screens/customer_main_screen.dart';
import '../../../retailer/presentation/screens/retailer_main_screen.dart';
import '../../../delivery/presentation/screens/delivery_main_screen.dart';
import '../../../../core/widgets/legal_policy_screen.dart';
import 'account_suspended_screen.dart';

class LoginScreen extends StatefulWidget {
  final UserRole initialRole;
  const LoginScreen({super.key, this.initialRole = UserRole.customer});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _isNewUser = true;
  bool _obscurePassword = true;
  bool _otpSent = false;
  // Stores OTP returned by backend in dev mode — only shown in debug builds
  String _devOtp = '';
  int _timerSeconds = 30;
  Timer? _timer;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  void _sendEmailOtp() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name to register')),
      );
      return;
    }

    final email = _emailController.text.trim();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Gmail or email address')),
      );
      return;
    }

    final phone = _phoneController.text.trim();
    if (phone.length != 10 || int.tryParse(phone) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit mobile number for delivery updates')),
      );
      return;
    }

    final password = _passwordController.text;
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    context.read<AuthBloc>().add(SendEmailOtpEvent(email));
  }

  void _handleEmailVerify() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final entered = _otpController.text.trim();
    if (entered.isEmpty || entered.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit OTP sent to your email')),
      );
      return;
    }

    context.read<AuthBloc>().add(
          RegisterWithEmailEvent(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            otp: entered,
            phone: _phoneController.text.trim(),
            role: widget.initialRole,
          ),
        );
  }

  void _handleEmailLogin() {
    final email = _emailController.text.trim();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Gmail or email address')),
      );
      return;
    }

    final password = _passwordController.text;
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password')),
      );
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    context.read<AuthBloc>().add(
          LoginWithEmailEvent(
            email: email,
            password: password,
            role: widget.initialRole,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Crisp Clean Slate Background
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is EmailOtpSentState) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFF0F766E),
              ),
            );
            setState(() {
              // Store OTP from backend response (only available in dev/test backends)
              _devOtp = (kDebugMode && state.otp != null && state.otp!.isNotEmpty) ? state.otp! : '';
              _otpSent = true;
              _timerSeconds = 30;
            });
            _startTimer();
          } else if (state is AuthenticatedState) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            Widget targetScreen;
            switch (state.user.role) {
              case UserRole.retailer:
                targetScreen = const RetailerMainScreen();
                break;
              case UserRole.deliveryPartner:
                targetScreen = const DeliveryMainScreen();
                break;
              case UserRole.customer:
              case UserRole.admin:
                targetScreen = const CustomerMainScreen();
                break;
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => targetScreen),
                );
              }
            });
          } else if (state is AuthErrorState) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFFDC2626),
                action: state.isNotRegistered
                    ? SnackBarAction(
                        label: 'Register Now',
                        textColor: Colors.white,
                        onPressed: () {
                          setState(() {
                            _isNewUser = true;
                          });
                        },
                      )
                    : null,
                duration: const Duration(seconds: 4),
              ),
            );
          } else if (state is UserSuspendedState) {
            _otpController.clear();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AccountSuspendedScreen(message: state.message)),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480), // Responsive Container for Tablets/Phones
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: size.width < 360 ? 16 : 24,
                        vertical: 20,
                      ),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),

                          // Brand Logo & Badge
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF1E293B)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
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
                                    child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 32),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Quick Tick',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    Text(
                                      '15-Minute Grocery & Food Delivery',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'A product from Prajnan Softwares',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryDark,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Responsive Header Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // New User vs Existing User Switcher
                                if (!_otpSent)
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    margin: const EdgeInsets.only(bottom: 20),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap: () => setState(() => _isNewUser = true),
                                            borderRadius: BorderRadius.circular(10),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                                              decoration: BoxDecoration(
                                                color: _isNewUser ? Colors.white : Colors.transparent,
                                                borderRadius: BorderRadius.circular(10),
                                                boxShadow: _isNewUser
                                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                                                    : null,
                                              ),
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  'New User • Sign Up',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: _isNewUser ? AppColors.primaryDark : const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () => setState(() => _isNewUser = false),
                                            borderRadius: BorderRadius.circular(10),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                                              decoration: BoxDecoration(
                                                color: !_isNewUser ? Colors.white : Colors.transparent,
                                                borderRadius: BorderRadius.circular(10),
                                                boxShadow: !_isNewUser
                                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                                                    : null,
                                              ),
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  'Existing User • Sign In',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: !_isNewUser ? AppColors.primaryDark : const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                Text(
                                  _otpSent
                                      ? 'Verify Gmail OTP'
                                      : (_isNewUser ? 'Create New Account' : 'Welcome Back'),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _otpSent
                                      ? 'Enter the 6-digit code sent to ${_emailController.text.trim()}'
                                      : (_isNewUser
                                          ? 'We will send a verification OTP to your Gmail inbox.'
                                          : 'Sign in with your Gmail and password.'),
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                ),
                                const SizedBox(height: 20),

                                // STEP 1: Input Form
                                if (!_otpSent) ...[
                                  if (_isNewUser) ...[
                                    const Text(
                                      'Full Name *',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                                      ),
                                      child: TextField(
                                        controller: _nameController,
                                        textCapitalization: TextCapitalization.words,
                                        cursorColor: AppColors.primary,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                        decoration: const InputDecoration(
                                          hintText: 'Enter your full name',
                                          hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.normal),
                                          prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 20),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                  ],

                                  // Email field (mandatory for Sign Up OTP & Sign In)
                                  const Text(
                                    'Gmail / Email Address *',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                                    ),
                                    child: TextField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      cursorColor: AppColors.primary,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'name@gmail.com',
                                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.normal),
                                        prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary, size: 20),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // Mobile Number field (needed during Sign-Up for delivery & payment)
                                  if (_isNewUser) ...[
                                    const Text(
                                      'Mobile Number (For Delivery) *',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                            decoration: const BoxDecoration(
                                              border: Border(right: BorderSide(color: Color(0xFFCBD5E1))),
                                            ),
                                            child: const Text(
                                              '+91',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 15,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: TextField(
                                              controller: _phoneController,
                                              keyboardType: TextInputType.phone,
                                              maxLength: 10,
                                              cursorColor: AppColors.primary,
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 1.5,
                                                color: Color(0xFF0F172A),
                                              ),
                                              decoration: const InputDecoration(
                                                hintText: '98765 43210',
                                                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 15, letterSpacing: 1, fontWeight: FontWeight.normal),
                                                counterText: '',
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                  ],

                                  // Password field
                                  Text(
                                    _isNewUser ? 'Create Password *' : 'Password *',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                                    ),
                                    child: TextField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      cursorColor: AppColors.primary,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                      decoration: InputDecoration(
                                        hintText: _isNewUser ? 'Min 6 characters' : 'Enter your password',
                                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.normal),
                                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 20),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                            color: const Color(0xFF64748B),
                                            size: 20,
                                          ),
                                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 22),

                                  // Action Button (Send Gmail OTP / Email Sign In)
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: isLoading
                                          ? null
                                          : (_isNewUser ? _sendEmailOtp : _handleEmailLogin),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                      child: isLoading
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                _isNewUser ? 'Send Gmail Verification OTP' : 'Sign In with Email',
                                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // OR Divider
                                  Row(
                                    children: const [
                                      Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 12),
                                        child: Text(
                                          'OR',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF94A3B8),
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                      Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Google Sign-In Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: OutlinedButton(
                                      onPressed: isLoading
                                          ? null
                                          : () {
                                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                              context.read<AuthBloc>().add(
                                                    SignInWithGoogleEvent(role: widget.initialRole),
                                                  );
                                            },
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            _buildGoogleLogo(),
                                            const SizedBox(width: 12),
                                            const Text(
                                              'Continue with Google',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  // STEP 2: 6-Digit OTP Field
                                  const Text(
                                    'Enter 6-Digit Verification Code',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _otpController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    textAlign: TextAlign.center,
                                    autofocus: true,
                                    cursorColor: AppColors.primary,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 8,
                                      color: Color(0xFF059669), // Crisp emerald OTP numbers
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '••••••',
                                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), letterSpacing: 4),
                                      counterText: '',
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
                                    ),
                                   ),
                                   // DEV ONLY BANNER — compiled away in release builds (kDebugMode = false)
                                   if (kDebugMode && _devOtp.isNotEmpty) ...
                                   [
                                     const SizedBox(height: 10),
                                     Container(
                                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                       decoration: BoxDecoration(
                                         color: const Color(0xFFFFFBEB),
                                         borderRadius: BorderRadius.circular(12),
                                         border: Border.all(color: const Color(0xFFFCD34D)),
                                       ),
                                       child: Row(
                                         children: [
                                           const Icon(Icons.developer_mode_rounded, color: Color(0xFFD97706), size: 18),
                                           const SizedBox(width: 8),
                                           Expanded(
                                             child: Column(
                                               crossAxisAlignment: CrossAxisAlignment.start,
                                               children: [
                                                 const Text('DEV MODE — OTP from server', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
                                                 Text(_devOtp, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 4, color: Color(0xFF92400E))),
                                               ],
                                             ),
                                           ),
                                           TextButton(
                                             onPressed: () => setState(() => _otpController.text = _devOtp),
                                             style: TextButton.styleFrom(foregroundColor: const Color(0xFFD97706)),
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
                                        onPressed: () => setState(() {
                                          _otpSent = false;
                                        }),
                                        child: const Text('Change Details', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                                      ),
                                      _timerSeconds > 0
                                          ? Text('Resend in ${_timerSeconds}s', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13))
                                          : TextButton(
                                              onPressed: _sendEmailOtp,
                                              child: const Text('Resend OTP', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                            ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  // Verify & Login Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: isLoading ? null : _handleEmailVerify,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                      child: isLoading
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : Text(
                                              _isNewUser ? 'Complete Registration & Start' : 'Verify & Sign In',
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),
                          _buildTermsAndPrivacyNote(context),
                          const SizedBox(height: 10),
                          const Center(
                            child: Text(
                              'A product from Prajnan Softwares • Karnataka',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Benefits for New Users
                          if (_isNewUser && !_otpSent)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.card_giftcard, color: Color(0xFF1D4ED8), size: 18),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'New User Welcome Offer',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    '• Free Delivery on your first 3 orders\n• Instant ₹100 Flat discount with code WELCOME100\n• 15-Minute Guaranteed Delivery',
                                    style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTermsAndPrivacyNote(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text.rich(
        TextSpan(
          text: 'By continuing, you agree to QuickTick\'s ',
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4),
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
                    color: AppColors.primary,
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
                    color: AppColors.primary,
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
    );
  }

  Widget _buildGoogleLogo() {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 3.6;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    // Blue arc (top-right to mid-right)
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, -0.6, 1.2, false, bluePaint);

    // Green arc (bottom-right to bottom-center)
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 0.6, 1.3, false, greenPaint);

    // Yellow arc (bottom-left to mid-left)
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 1.9, 1.3, false, yellowPaint);

    // Red arc (top-left to top-center)
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 3.2, 1.3, false, redPaint);

    // Blue horizontal bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(center.dx - 1, center.dy - (strokeWidth / 2), radius, strokeWidth),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
