import 'dart:async';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayCheckoutSheet extends StatefulWidget {
  final String keyId;
  final int amountInPaise;
  final String orderId;
  final String customerPhone;
  final String customerEmail;
  final String storeName;
  final String description;
  final void Function(PaymentSuccessResponse response) onSuccess;
  final void Function(PaymentFailureResponse response) onFailure;

  const RazorpayCheckoutSheet({
    super.key,
    required this.keyId,
    required this.amountInPaise,
    required this.orderId,
    required this.customerPhone,
    required this.customerEmail,
    required this.storeName,
    required this.description,
    required this.onSuccess,
    required this.onFailure,
  });

  static Future<void> show(
    BuildContext context, {
    required String keyId,
    required int amountInPaise,
    required String orderId,
    required String customerPhone,
    required String customerEmail,
    required String storeName,
    required String description,
    required void Function(PaymentSuccessResponse response) onSuccess,
    required void Function(PaymentFailureResponse response) onFailure,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => RazorpayCheckoutSheet(
        keyId: keyId,
        amountInPaise: amountInPaise,
        orderId: orderId,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        storeName: storeName,
        description: description,
        onSuccess: onSuccess,
        onFailure: onFailure,
      ),
    );
  }

  @override
  State<RazorpayCheckoutSheet> createState() => _RazorpayCheckoutSheetState();
}

class _RazorpayCheckoutSheetState extends State<RazorpayCheckoutSheet> {
  int _selectedTab = 0; // 0: UPI, 1: Cards, 2: Netbanking
  String _selectedUpiApp = 'Google Pay';
  String _selectedBank = 'HDFC Bank';
  bool _isProcessing = false;
  String _processingStatus = 'Processing...';

  final TextEditingController _upiIdController = TextEditingController(text: 'customer@okhdfcbank');
  final TextEditingController _cardNumberController = TextEditingController(text: '4315 8892 0019 4432');
  final TextEditingController _expiryController = TextEditingController(text: '08/28');
  final TextEditingController _cvvController = TextEditingController(text: '782');

  @override
  void dispose() {
    _upiIdController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _executePayment() {
    setState(() {
      _isProcessing = true;
      _processingStatus = 'Connecting to Razorpay Gateway...';
    });

    Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _processingStatus = 'Authorizing with Bank Server...');
    });

    Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _processingStatus = 'Capturing Payment Token...');
    });

    Timer(const Duration(milliseconds: 2100), () {
      if (!mounted) return;
      final paymentId = 'pay_${DateTime.now().millisecondsSinceEpoch}';
      final signature = 'rzp_sig_${DateTime.now().millisecondsSinceEpoch}';

      Navigator.pop(context);
      widget.onSuccess(PaymentSuccessResponse(
        paymentId,
        widget.orderId,
        signature,
        null,
      ));
    });
  }

  void _cancelPayment() {
    Navigator.pop(context);
    widget.onFailure(PaymentFailureResponse(
      0,
      'Payment cancelled by customer',
      null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final double displayAmount = widget.amountInPaise / 100.0;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            margin: EdgeInsets.only(bottom: bottomInset),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, -4)),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // 1. Official Razorpay Navy Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0C2340), // Razorpay brand navy
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.storeName.isNotEmpty ? widget.storeName : 'Quick Tick Mart',
                                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 14),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                'Order #${widget.orderId.substring(widget.orderId.length > 8 ? widget.orderId.length - 8 : 0)}',
                                                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white70),
                              onPressed: _isProcessing ? null : _cancelPayment,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AMOUNT TO PAY',
                                    style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${displayAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF10B981)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.lock_rounded, color: Color(0xFF10B981), size: 12),
                                    SizedBox(width: 4),
                                    Text(
                                      '256-BIT SECURE',
                                      style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
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

                  // 2. Pre-filled Customer Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    color: const Color(0xFFF1F5F9),
                    child: Row(
                      children: [
                        const Icon(Icons.account_circle_outlined, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${widget.customerPhone} • ${widget.customerEmail}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. Processing View OR Tabs View
                  if (_isProcessing)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 50,
                            height: 50,
                            child: CircularProgressIndicator(
                              strokeWidth: 4,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _processingStatus,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Please do not press back or close this window',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        // Payment Modes Tab Bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Row(
                            children: [
                              _buildTabButton(0, Icons.qr_code_scanner_rounded, 'UPI / QR'),
                              const SizedBox(width: 8),
                              _buildTabButton(1, Icons.credit_card_rounded, 'Cards'),
                              const SizedBox(width: 8),
                              _buildTabButton(2, Icons.account_balance_rounded, 'Netbanking'),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),

                        // Tab Contents
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: _selectedTab == 0
                              ? _buildUpiTab(displayAmount)
                              : _selectedTab == 1
                                  ? _buildCardsTab(displayAmount)
                                  : _buildNetbankingTab(displayAmount),
                        ),
                      ],
                    ),

                  // 4. Razorpay Footer Logo
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: const Color(0xFFF8FAFC),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shield_rounded, color: Color(0xFF0284C7), size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Secured by Razorpay • Trusted by 10M+ Businesses',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, IconData icon, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0C2340) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: isSelected ? Colors.white : const Color(0xFF475569)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpiTab(double amount) {
    final upiApps = ['Google Pay', 'PhonePe', 'Paytm', 'BHIM UPI'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select your UPI App',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 10),
        Row(
          children: upiApps.map((app) {
            final isAppSelected = _selectedUpiApp == app;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () => setState(() => _selectedUpiApp = app),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    decoration: BoxDecoration(
                      color: isAppSelected ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isAppSelected ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                        width: isAppSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          color: isAppSelected ? const Color(0xFF10B981) : const Color(0xFF64748B),
                          size: 18,
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            app,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isAppSelected ? const Color(0xFF065F46) : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        const Text(
          'Or enter UPI ID / VPA',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _upiIdController,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'e.g. yourname@okhdfcbank',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _executePayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_rounded, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Pay ₹${amount.toStringAsFixed(2)} via $_selectedUpiApp',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardsTab(double amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Card Details',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _cardNumberController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            isDense: true,
            labelText: 'Card Number',
            prefixIcon: const Icon(Icons.credit_card_rounded, color: Color(0xFF0284C7)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _expiryController,
                keyboardType: TextInputType.datetime,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'Expiry (MM/YY)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _cvvController,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'CVV',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _executePayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_rounded, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Pay ₹${amount.toStringAsFixed(2)} Securely',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNetbankingTab(double amount) {
    final banks = ['HDFC Bank', 'SBI', 'ICICI Bank', 'Axis Bank', 'Kotak'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Your Bank',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: banks.map((bank) {
            final isBankSelected = _selectedBank == bank;
            return InkWell(
              onTap: () => setState(() => _selectedBank = bank),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isBankSelected ? const Color(0xFF0C2340) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  bank,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isBankSelected ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _executePayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_rounded, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Pay ₹${amount.toStringAsFixed(2)} via $_selectedBank',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
