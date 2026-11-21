import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-featured in-app Privacy Policy, Terms of Service, and Data Safety Viewer
/// strictly adhering to Google Play Developer Policy (User Data & Privacy).
class LegalPolicyScreen extends StatefulWidget {
  final int initialTabIndex;

  const LegalPolicyScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  static const String publicWebsiteUrl = 'https://www.quicktick.shop/';
  static const String publicPrivacyPolicyUrl = 'https://www.quicktick.shop/';
  static const String publicTermsUrl = 'https://www.quicktick.shop/';
  static const String publicAccountDeletionUrl = 'https://www.quicktick.shop/';

  static Future<void> openExternalUrl(String url, [BuildContext? context]) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open $url'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  State<LegalPolicyScreen> createState() => _LegalPolicyScreenState();
}

class _LegalPolicyScreenState extends State<LegalPolicyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open $url'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Legal & Privacy Compliance',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Google Play Data Safety & Standards',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Open in Browser',
            icon: const Icon(Icons.open_in_browser_rounded, color: Color(0xFF38BDF8)),
            onPressed: () {
              final url = _tabController.index == 0
                  ? LegalPolicyScreen.publicPrivacyPolicyUrl
                  : (_tabController.index == 1
                      ? LegalPolicyScreen.publicTermsUrl
                      : LegalPolicyScreen.publicAccountDeletionUrl);
              _openExternalUrl(url);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          indicatorWeight: 3,
          labelColor: const Color(0xFF38BDF8),
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Privacy Policy'),
            Tab(text: 'Terms of Service'),
            Tab(text: 'Data Safety'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPrivacyPolicyView(),
              _buildTermsOfServiceView(),
              _buildDataSafetyView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveWebBanner() {
    return InkWell(
      onTap: () => LegalPolicyScreen.openExternalUrl(LegalPolicyScreen.publicWebsiteUrl, context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.language, color: Color(0xFF38BDF8), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Official Website & Policy Portal',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    'https://www.quicktick.shop/',
                    style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, decoration: TextDecoration.underline),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new, color: Color(0xFF38BDF8), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyPolicyView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      children: [
        _buildHeroBadge(
          icon: Icons.shield_outlined,
          color: const Color(0xFF10B981),
          title: 'QuickTick Privacy Commitment',
          subtitle: 'Last Updated: October 2026 • Valid for Customers, Retailers & Delivery Partners',
        ),
        const SizedBox(height: 16),
        _buildLiveWebBanner(),
        _buildSectionCard(
          title: '1. Overview & Scope',
          content:
              'QuickTick ("we", "us", or "our") is dedicated to safeguarding your personal data and upholding your digital privacy rights. This Privacy Policy details how we collect, process, store, and protect your information across our customer ordering, store partner, and delivery partner applications in strict compliance with the Google Play Developer Distribution Agreement and applicable privacy laws.\n\nOfficial Portal: https://www.quicktick.shop/',
        ),
        _buildSectionCard(
          title: '2. Information We Collect',
          content:
              '• Profile Data: Full name, mobile phone number, and email address.\n'
              '• Delivery Details: Saved shipping addresses, landmark hints, and drop-off instructions.\n'
              '• Retailer & Delivery Partner KYC: Government ID, FSSAI / GSTIN licenses, driving license, vehicle registration, and biometric verification.\n'
              '• Telemetry & Device Data: Hardware identifiers, Firebase Cloud Messaging (FCM) tokens for real-time dispatch alerts, and crash analytics.',
        ),
        _buildSectionCard(
          title: '3. Location Data & Background Telematics',
          content:
              'QuickTick collects and processes precise and approximate location data:\n\n'
              '• For Customers: To automatically identify delivery destinations, suggest nearby retail stores, and calculate accurate arrival times.\n'
              '• For Delivery Partners: To allocate nearby pickup requests, provide turn-by-turn navigation, and broadcast live GPS telematics to customers.\n'
              '• Background Location: Delivery partner location is collected during active delivery trips even when the app is minimized or running in the background until delivery drop-off is completed. Location tracking ceases immediately when you go Offline.',
        ),
        _buildSectionCard(
          title: '4. Data Security & Storage Architecture',
          content:
              '• Transmission: All client-server traffic is strictly encrypted in transit using TLS 1.3 / HTTPS and Secure WebSockets (WSS).\n'
              '• At Rest: Tokens and sensitive identifiers are encrypted using AES-256 via hardware keystore backed storage.\n'
              '• Payments: Payment processing is handled by certified PCI-DSS Level 1 payment aggregators (e.g. Razorpay, UPI). QuickTick never stores raw debit/credit card numbers or CVVs on our servers.',
        ),
        _buildSectionCard(
          title: '5. Account & Data Deletion Rights',
          content:
              'Under Google Play Data Safety policies, you retain the full right to delete your account and request complete erasure of your personal data at any time.\n\n'
              '• In-App: Navigate to Profile > "Delete Account" to permanently delete your profile, saved addresses, and active session.\n'
              '• Web Portal: Log in with your registered credentials at https://app.quicktick.shop/login, go to the Profile section, and select "Delete Account" to permanently delete your account and associated data.',
        ),
        _buildSectionCard(
          title: '6. Grievance Officer & Contact',
          content:
              'If you have any questions, concerns, or requests regarding this Privacy Policy or our data handling practices, please contact our Data Protection Office:\n\n'
              'Official Website: https://www.quicktick.shop/\n'
              'Email: privacy@quicktick.shop\n'
              'Support Desk: support@quicktick.shop\n'
              'Entity: Prajnan Software Private Limited, Bengaluru, India',
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildTermsOfServiceView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      children: [
        _buildHeroBadge(
          icon: Icons.gavel_rounded,
          color: const Color(0xFF38BDF8),
          title: 'Terms of Service',
          subtitle: 'Please review these terms carefully prior to accessing QuickTick services.',
        ),
        const SizedBox(height: 16),
        _buildLiveWebBanner(),
        _buildSectionCard(
          title: '1. User Eligibility & Account Registration',
          content:
              'By accessing or using QuickTick (https://www.quicktick.shop/), you affirm that you are at least 18 years of age and legally competent to enter into binding agreements. You agree to provide accurate, truthful, and updated credentials during OTP-based authentication.',
        ),
        _buildSectionCard(
          title: '2. Customer Orders & Cancellations',
          content:
              'Orders placed on QuickTick are processed swiftly through automated dark store allocation. Once a delivery partner has been assigned or the order milestone advances to "Out for Delivery", cancellations may incur a standard restocking fee to compensate riders for transit.',
        ),
        _buildSectionCard(
          title: '3. Store & Delivery Partner Code of Conduct',
          content:
              'Delivery partners and store merchants agree to uphold strict standards of product safety, punctuality, and professional interactions. Falsification of GPS telematics, expired food licensing, or document tampering constitutes grounds for immediate deactivation.',
        ),
        _buildSectionCard(
          title: '4. Limitation of Liability',
          content:
              'QuickTick provides an on-demand logistics matchmaking platform. While we make every effort to guarantee rapid delivery windows, delays arising from extreme weather conditions, traffic restrictions, or force majeure events do not incur direct punitive liability.\n\nAll rights reserved by Prajnan Software Private Limited • https://www.quicktick.shop/',
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildDataSafetyView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      children: [
        _buildHeroBadge(
          icon: Icons.verified_user_rounded,
          color: const Color(0xFFA855F7),
          title: 'Google Play Data Safety Disclosures',
          subtitle: 'Transparent declaration of all permissions & collected telemetry',
        ),
        const SizedBox(height: 16),
        _buildPermissionItem(
          icon: Icons.location_on_rounded,
          title: 'Location (Precise & Background)',
          purpose: 'Order routing, accurate ETA calculation, live customer tracking during transit.',
          isOptional: false,
        ),
        _buildPermissionItem(
          icon: Icons.camera_alt_rounded,
          title: 'Camera & Document Storage',
          purpose: 'Delivery partner document KYC verification (Aadhaar, DL) and face biometrics.',
          isOptional: true,
        ),
        _buildPermissionItem(
          icon: Icons.notifications_active_rounded,
          title: 'Push Notifications (FCM)',
          purpose: 'Instant trip dispatch alerts, delivery milestone updates, and transaction receipts.',
          isOptional: false,
        ),
        _buildPermissionItem(
          icon: Icons.lock_outline_rounded,
          title: 'Data Encryption',
          purpose: 'All user data is encrypted in transit via TLS 1.3 / HTTPS / WSS. Tokens stored in hardware keystore.',
          isOptional: false,
        ),
        _buildPermissionItem(
          icon: Icons.delete_outline_rounded,
          title: 'Account & Data Erasure',
          purpose: 'Users can delete account & data anytime in-app, or via web by logging in at https://app.quicktick.shop/login and visiting Profile.',
          isOptional: false,
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildHeroBadge({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required String content}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String purpose,
    required bool isOptional,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF38BDF8), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOptional
                            ? Colors.blueGrey.withValues(alpha: 0.3)
                            : const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isOptional ? 'Optional' : 'Required',
                        style: TextStyle(
                          color: isOptional ? Colors.white70 : const Color(0xFF10B981),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  purpose,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
