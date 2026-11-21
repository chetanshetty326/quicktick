import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../order/domain/entities/order_entity.dart';
import '../bloc/delivery_bloc.dart';

class DoorstepPaymentCollectionSheet extends StatefulWidget {
  final OrderEntity order;
  final VoidCallback onDismiss;

  const DoorstepPaymentCollectionSheet({
    super.key,
    required this.order,
    required this.onDismiss,
  });

  @override
  State<DoorstepPaymentCollectionSheet> createState() => _DoorstepPaymentCollectionSheetState();
}

class _DoorstepPaymentCollectionSheetState extends State<DoorstepPaymentCollectionSheet> {
  final TextEditingController _otpController = TextEditingController();
  bool _useCashMode = false;
  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  String? _otpError;

  bool get _isCod {
    final method = widget.order.paymentMethod.toUpperCase();
    return method.contains('COD') || method.contains('CASH');
  }

  double get _amount => widget.order.grandTotal > 0 ? widget.order.grandTotal : 250.0;

  @override
  void initState() {
    super.initState();
    if (_isCod) {
      // Auto-request QR upon opening if COD
      context.read<DeliveryBloc>().add(RequestDoorstepQrEvent(orderId: widget.order.id));
    }
    _startLocalCountdownTicker();
  }

  void _startLocalCountdownTicker() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final state = context.read<DeliveryBloc>().state;
      final expiresAt = state.qrPaymentStatus?.expiresAt ?? state.activeDoorstepQr?.expiresAt;
      if (expiresAt != null) {
        final remaining = expiresAt.difference(DateTime.now()).inSeconds;
        setState(() {
          _secondsRemaining = remaining > 0 ? remaining : 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _submitDelivery({required bool isCash}) {
    final otp = _otpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() {
        _otpError = 'Delivery PIN must be a 6-digit number';
      });
      return;
    }

    setState(() {
      _otpError = null;
    });

    context.read<DeliveryBloc>().add(VerifyDeliveryOtpEvent(
          orderId: widget.order.id,
          otp: otp,
          collectedAmount: isCash ? _amount : 0.0,
          paymentCollected: isCash,
        ));
    widget.onDismiss();
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: BlocConsumer<DeliveryBloc, DeliveryState>(
        listener: (context, state) {
          if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final qr = state.activeDoorstepQr;
          final status = state.qrPaymentStatus;
          final isPaid = status?.isCompleted ?? qr?.isCompleted ?? false;
          final isExpired = !isPaid && (_secondsRemaining <= 0 && qr != null);

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title & Order Number
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isCod ? 'Doorstep Payment Collection' : 'Verify Customer Delivery',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Order #${widget.order.orderNumber}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: widget.onDismiss,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_isCod) ...[
                  // Payment mode selector (UPI QR vs Cash)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _useCashMode = false;
                              });
                              if (state.activeDoorstepQr == null && !state.isRequestingQr) {
                                context.read<DeliveryBloc>().add(
                                      RequestDoorstepQrEvent(orderId: widget.order.id),
                                    );
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_useCashMode ? const Color(0xFF10B981) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.qr_code_scanner_rounded,
                                    size: 18,
                                    color: !_useCashMode ? Colors.white : Colors.white60,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'UPI QR Code',
                                    style: TextStyle(
                                      color: !_useCashMode ? Colors.white : Colors.white60,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _useCashMode = true;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _useCashMode ? const Color(0xFFF59E0B) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.payments_outlined,
                                    size: 18,
                                    color: _useCashMode ? Colors.white : Colors.white60,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Cash Collection',
                                    style: TextStyle(
                                      color: _useCashMode ? Colors.white : Colors.white60,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // BODY: Cash Mode or UPI QR Mode
                if (_useCashMode || !_isCod) ...[
                  // Cash / Prepaid Flow
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isCod ? const Color(0xFFF59E0B).withValues(alpha: 0.3) : const Color(0xFF10B981).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isCod
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                : const Color(0xFF10B981).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isCod ? Icons.payments_rounded : Icons.check_circle_rounded,
                            color: _isCod ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isCod ? 'Cash to Collect' : 'Order Paid Online',
                                style: TextStyle(
                                  color: _isCod ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '₹${_amount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (_isCod)
                                const Text(
                                  'Collect exact cash before verifying delivery PIN',
                                  style: TextStyle(color: Colors.white54, fontSize: 11),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildOtpInputSection(isCash: _isCod),
                ] else ...[
                  // UPI QR Code Flow
                  if (state.isRequestingQr) ...[
                    const SizedBox(height: 40),
                    const CircularProgressIndicator(color: Color(0xFF10B981)),
                    const SizedBox(height: 16),
                    const Text(
                      'Generating Doorstep UPI QR Code...',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 40),
                  ] else if (state.qrError != null && qr == null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            state.qrError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Retry QR Generation'),
                            onPressed: () {
                              context.read<DeliveryBloc>().add(
                                    RequestDoorstepQrEvent(orderId: widget.order.id),
                                  );
                            },
                          ),
                        ],
                      ),
                    ),
                  ] else if (isPaid) ...[
                    // Payment Completed Banner & OTP Input
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 48),
                          const SizedBox(height: 8),
                          const Text(
                            'UPI Payment Verified! 🎉',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Collected ₹${(status?.secondsLeft != null ? qr?.amount : _amount)?.toStringAsFixed(0) ?? _amount.toStringAsFixed(0)} via UPI',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          if (status?.razorpayPaymentId != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Txn: ${status!.razorpayPaymentId}',
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildOtpInputSection(isCash: false),
                  ] else if (isExpired) ...[
                    // QR Expired Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.timer_off_outlined, color: Color(0xFFF59E0B), size: 44),
                          const SizedBox(height: 8),
                          const Text(
                            'Doorstep QR Code Expired',
                            style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Validity window ended. Please generate a new QR or switch to cash payment.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                    side: const BorderSide(color: Colors.white24),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _useCashMode = true;
                                    });
                                  },
                                  child: const Text('Collect Cash'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                                  onPressed: () {
                                    context.read<DeliveryBloc>().add(
                                          RequestDoorstepQrEvent(orderId: widget.order.id),
                                        );
                                  },
                                  child: const Text('Regenerate QR'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else if (qr != null) ...[
                    // Active QR Code Display
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.currency_rupee, color: Color(0xFF10B981), size: 20),
                                  Text(
                                    'Collect ₹${qr.amount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              // Countdown Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFF59E0B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDuration(_secondsRemaining),
                                      style: const TextStyle(
                                        color: Color(0xFFF59E0B),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // QR Image Container
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Image.network(
                              qr.imageUrl,
                              width: 220,
                              height: 220,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const SizedBox(
                                  width: 220,
                                  height: 220,
                                  child: Center(
                                    child: CircularProgressIndicator(color: Color(0xFF10B981)),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return const SizedBox(
                                  width: 220,
                                  height: 220,
                                  child: Center(
                                    child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Customer instructions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Scan with GPay, PhonePe, Paytm, or BHIM',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                          if (qr.reused) ...[
                            const SizedBox(height: 4),
                            const Text(
                              'Using active QR session for this order',
                              style: TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOtpInputSection({required bool isCash}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter 6-Digit Delivery PIN from Customer',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF10B981),
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 10,
          ),
          decoration: InputDecoration(
            hintText: '••••••',
            hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 10),
            counterText: '',
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF10B981)),
            ),
            errorText: _otpError,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => _submitDelivery(isCash: isCash),
            child: Text(
              isCash
                  ? 'Confirm Delivery & Cash (₹${_amount.toStringAsFixed(0)})'
                  : 'Confirm Delivery (PIN Verified)',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
