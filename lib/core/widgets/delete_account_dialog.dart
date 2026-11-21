import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../di/service_locator.dart';
import '../security/secure_storage_service.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/customer/presentation/bloc/customer_bloc.dart';
import '../../features/delivery/presentation/bloc/delivery_bloc.dart';

/// Google Play Developer Policy Compliant Account & Data Deletion Flow.
///
/// Google Play strictly requires:
/// 1. An in-app path for users to initiate permanent account and data deletion.
/// 2. Clear explanation of what data is permanently wiped and any legally retained audit data.
/// 3. A visible external web link where users can submit deletion requests without the app.
class DeleteAccountDialog extends StatefulWidget {
  final bool isDeliveryPartner;

  const DeleteAccountDialog({
    super.key,
    this.isDeliveryPartner = false,
  });

  static Future<void> show(BuildContext context, {bool isDeliveryPartner = false}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DeleteAccountDialog(isDeliveryPartner: isDeliveryPartner),
    );
  }

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  bool _isProcessing = false;
  final TextEditingController _confirmController = TextEditingController();
  bool _canConfirm = false;

  @override
  void initState() {
    super.initState();
    _confirmController.addListener(() {
      final text = _confirmController.text.trim().toUpperCase();
      setState(() {
        _canConfirm = text == 'DELETE';
      });
    });
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _executeAccountDeletion() async {
    setState(() => _isProcessing = true);

    try {
      // 1. Clear secure hardware keystore tokens
      if (sl.isRegistered<ISecureStorageService>()) {
        await sl<ISecureStorageService>().clearAuthData();
      }

      // 2. Wipe SharedPreferences cached user details
      if (sl.isRegistered<SharedPreferences>()) {
        final prefs = sl<SharedPreferences>();
        await prefs.remove('delivery_partner_kyc_data');
        await prefs.remove('fcm_device_token');
        await prefs.remove('location_disclosure_agreed_customer');
        await prefs.remove('location_disclosure_agreed_rider');
      }

      // 3. Reset all active BLoC states
      if (mounted) {
        try {
          context.read<CustomerBloc>().add(const ClearCustomerSessionEvent());
        } catch (_) {}
        try {
          context.read<DeliveryBloc>().add(const ResetDeliveryStateEvent());
        } catch (_) {}
        try {
          context.read<AuthBloc>().add(LogoutEvent());
        } catch (_) {}
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account and associated data have been permanently deleted.'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actionsOverflowButtonSpacing: 8,
      actionsOverflowDirection: VerticalDirection.down,
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Permanently Delete Account?',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This action is irreversible. As required by Google Play Data Safety policies, deleting your account will permanently wipe:',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 10),
            _buildWipeItem('Your profile name, phone number, and authentication credentials'),
            _buildWipeItem('Saved delivery addresses, landmarks, and favorite store pins'),
            _buildWipeItem(widget.isDeliveryPartner
                ? 'All uploaded KYC documents, driving license records, and payout tokens'
                : 'Cart items, active orders, and historical payment receipts'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Type "DELETE" below to confirm:',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmController,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'DELETE',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.language_rounded, color: Color(0xFF38BDF8), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Web Account Deletion Portal',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'To delete your account via web: Login with your registered credentials at https://app.quicktick.shop/login, navigate to the Profile section, and select "Delete Account" to confirm permanent deletion.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final uri = Uri.parse('https://app.quicktick.shop/login');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: const Text(
                      'Open https://app.quicktick.shop/login ↗',
                      style: TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: (_canConfirm && !_isProcessing) ? _executeAccountDeletion : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            disabledBackgroundColor: Colors.redAccent.withValues(alpha: 0.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isProcessing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Delete Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildWipeItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.close_rounded, color: Colors.redAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, height: 1.3)),
          ),
        ],
      ),
    );
  }
}
