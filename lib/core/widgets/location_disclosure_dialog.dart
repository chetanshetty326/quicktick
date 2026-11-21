import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../di/service_locator.dart';
import 'legal_policy_screen.dart';

/// Google Play Developer Policy Compliant Prominent Location Disclosure.
///
/// Google Play strictly mandates:
/// 1. Must be shown within the app BEFORE triggering the OS runtime permission request.
/// 2. Must explicitly disclose that location is accessed and how it is used.
/// 3. For delivery partners, must clearly state that location is collected in the background
///    during active delivery trips even when the app is minimized.
class LocationDisclosureDialog extends StatelessWidget {
  final bool isDeliveryPartner;
  final VoidCallback onAccept;
  final VoidCallback onDeny;

  const LocationDisclosureDialog({
    super.key,
    required this.isDeliveryPartner,
    required this.onAccept,
    required this.onDeny,
  });

  static const String prefKeyCustomerConsent = 'location_disclosure_agreed_customer';
  static const String prefKeyRiderConsent = 'location_disclosure_agreed_rider';

  /// Show the prominent disclosure if the user has not yet consented.
  /// Returns `true` if consent is granted or was previously granted.
  static Future<bool> ensureDisclosureConsent(
    BuildContext context, {
    required bool isDeliveryPartner,
  }) async {
    final key = isDeliveryPartner ? prefKeyRiderConsent : prefKeyCustomerConsent;

    try {
      if (sl.isRegistered<SharedPreferences>()) {
        final prefs = sl<SharedPreferences>();
        final alreadyAgreed = prefs.getBool(key) ?? false;
        if (alreadyAgreed) return true;
      }
    } catch (_) {}

    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LocationDisclosureDialog(
        isDeliveryPartner: isDeliveryPartner,
        onAccept: () async {
          try {
            if (sl.isRegistered<SharedPreferences>()) {
              final prefs = sl<SharedPreferences>();
              await prefs.setBool(key, true);
            }
          } catch (_) {}
          if (ctx.mounted) Navigator.of(ctx).pop(true);
        },
        onDeny: () {
          if (ctx.mounted) Navigator.of(ctx).pop(false);
        },
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_rounded, color: Color(0xFF38BDF8), size: 28),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Location Access Notice',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isDeliveryPartner
                  ? 'QuickLink Partner collects precise location data to enable:'
                  : 'QuickLink collects precise location data to enable:',
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            if (isDeliveryPartner) ...[
              _buildBullet(
                icon: Icons.radar,
                text: 'Proximity-based dispatching of nearby store orders to you.',
              ),
              _buildBullet(
                icon: Icons.navigation_rounded,
                text: 'Turn-by-turn routing to store pickup locations and customer addresses.',
              ),
              _buildBullet(
                icon: Icons.alt_route_rounded,
                text: 'Live telematics & ETA broadcasting to customers during active deliveries.',
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Background Location: QuickLink accesses your location even when the app is closed or running in the background during active trips so customers can track their orders in real time. Tracking stops immediately when you switch Offline.',
                        style: TextStyle(color: Color(0xFFFDE68A), fontSize: 11, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              _buildBullet(
                icon: Icons.pin_drop_rounded,
                text: 'Automatic address detection and precise pin placement on maps.',
              ),
              _buildBullet(
                icon: Icons.store_rounded,
                text: 'Locating the closest dark store to ensure 15-minute express delivery.',
              ),
              _buildBullet(
                icon: Icons.moped_rounded,
                text: 'Live order tracking while your delivery partner is en route.',
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Your location data is encrypted in transit and is never sold or used for targeted third-party advertising.',
              style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.4),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LegalPolicyScreen(initialTabIndex: 0),
                  ),
                );
              },
              child: const Text(
                'Read our full Privacy Policy →',
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
      actions: [
        TextButton(
          onPressed: onDeny,
          child: const Text('Deny', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          onPressed: onAccept,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF38BDF8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text(
            'Agree & Continue',
            style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildBullet({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF38BDF8), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
