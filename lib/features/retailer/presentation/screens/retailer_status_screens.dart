import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/retailer_bloc.dart';
import 'retailer_auth_screen.dart';
import 'retailer_main_screen.dart';
import 'retailer_registration_screen.dart';
import '../widgets/retailer_hero_banner_carousel.dart';
import '../../../support/presentation/screens/support_tickets_screen.dart';

/// Screen displayed when retailer registration is PENDING admin approval
class RetailerAwaitingApprovalScreen extends StatelessWidget {
  final String? shopName;

  const RetailerAwaitingApprovalScreen({super.key, this.shopName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: BlocConsumer<RetailerBloc, RetailerState>(
        listenWhen: (previous, current) =>
            previous.registrationStatus != current.registrationStatus,
        listener: (context, state) {
          if (state.registrationStatus == RetailerRegistrationStatus.approved) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const RetailerMainScreen()),
            );
          } else if (state.registrationStatus == RetailerRegistrationStatus.rejected) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const RetailerRejectedScreen()),
            );
          } else if (state.registrationStatus == RetailerRegistrationStatus.notRegistered) {
            final authState = context.read<AuthBloc>().state;
            final initialPhone = authState is AuthenticatedState && authState.user.phone.isNotEmpty
                ? authState.user.phone
                : null;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => RetailerRegistrationScreen(initialPhone: initialPhone),
              ),
            );
          }
        },
        builder: (context, state) {
          final isChecking = state.registrationStatus == RetailerRegistrationStatus.checking;
          final displayShopName = shopName ?? state.registeredShopName ?? 'Your Store';

          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Status Icon
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.hourglass_top_rounded,
                          size: 48,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Text(
                          'AWAITING APPROVAL',
                          style: TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        displayShopName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      const Text(
                        'Your store registration and uploaded verification documents are under review by our admin team.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Company Announcements / Hero Banners
                      BlocBuilder<RetailerBloc, RetailerState>(
                        builder: (context, state) {
                          if (state.heroBanners.isEmpty) return const SizedBox.shrink();
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 24),
                            child: RetailerHeroBannerCarousel(),
                          );
                        },
                      ),

                      // Info Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              Icons.verified_user_outlined,
                              'Document Review',
                              'Under verification',
                              const Color(0xFFF59E0B),
                            ),
                            const Divider(color: Colors.white10, height: 24),
                            _buildInfoRow(
                              Icons.timer_outlined,
                              'Estimated Time',
                              '2 - 4 Business Hours',
                              const Color(0xFF10B981),
                            ),
                            const Divider(color: Colors.white10, height: 24),
                            _buildInfoRow(
                              Icons.notifications_active_outlined,
                              'SMS & In-App Alert',
                              'Notified once approved',
                              Colors.white70,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Refresh Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: isChecking
                              ? null
                              : () {
                                  context.read<RetailerBloc>().add(const CheckRetailerStatusEvent());
                                  context.read<RetailerBloc>().add(const FetchRetailerBannersEvent(forceRefresh: true));
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          icon: isChecking
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                          label: Text(
                            isChecking ? 'Checking status...' : 'Check Status',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Logout button
                      TextButton(
                        onPressed: () {
                          context.read<AuthBloc>().add(LogoutEvent());
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const RetailerAuthScreen()),
                            (route) => false,
                          );
                        },
                        child: const Text(
                          'Log Out',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
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
    );
  }

  static Widget _buildInfoRow(IconData icon, String title, String subtitle, Color iconColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Screen displayed when retailer registration is REJECTED
class RetailerRejectedScreen extends StatelessWidget {
  const RetailerRejectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: BlocConsumer<RetailerBloc, RetailerState>(
        listener: (context, state) {
          if (state.registrationStatus == RetailerRegistrationStatus.approved) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const RetailerMainScreen()),
            );
          } else if (state.registrationStatus == RetailerRegistrationStatus.pendingApproval) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const RetailerAwaitingApprovalScreen()),
            );
          }
        },
        builder: (context, state) {
          final rejectionReason = state.rejectionRemarks ?? 'One or more submitted documents did not meet verification criteria.';
          final rejectedDocs = state.rejectedDocuments;

          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    children: [
                      // Rejection Icon
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.cancel_outlined,
                          size: 46,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Text(
                          'REGISTRATION REJECTED',
                          style: TextStyle(
                            color: Color(0xFFF87171),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Application Requires Attention',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Rejection remarks card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info_outline, color: Color(0xFFF87171), size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Reason for Rejection',
                                  style: TextStyle(
                                    color: Color(0xFFF87171),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              rejectionReason,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Rejected Documents List (if any)
                      if (rejectedDocs.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Rejected Documents (${rejectedDocs.length})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...rejectedDocs.map((doc) => Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.description, color: Color(0xFFF87171), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          doc.type,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (doc.remarks.isNotEmpty)
                                          Text(
                                            doc.remarks,
                                            style: const TextStyle(
                                              color: Color(0xFFF87171),
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'REJECTED',
                                      style: TextStyle(
                                        color: Color(0xFFF87171),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        const SizedBox(height: 20),
                      ],

                      // Re-submit / Edit Registration Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final authState = context.read<AuthBloc>().state;
                            final initialPhone = authState is AuthenticatedState && authState.user.phone.isNotEmpty
                                ? authState.user.phone
                                : null;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RetailerRegistrationScreen(initialPhone: initialPhone),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.edit_document),
                          label: const Text(
                            'Re-upload & Update Details',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Logout button
                      TextButton(
                        onPressed: () {
                          context.read<AuthBloc>().add(LogoutEvent());
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const RetailerAuthScreen()),
                            (route) => false,
                          );
                        },
                        child: const Text(
                          'Log Out',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
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
    );
  }
}

/// Screen displayed when retailer account is SUSPENDED
class RetailerSuspendedScreen extends StatelessWidget {
  const RetailerSuspendedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.block, size: 46, color: Colors.amber),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Store Account Suspended',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your store account has been temporarily suspended by QuickClick administration. Please contact partner support for more information.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          SupportTicketsScreen.route(app: 'retailer'),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.support_agent),
                      label: const Text('Contact Support'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () {
                      context.read<AuthBloc>().add(LogoutEvent());
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const RetailerAuthScreen()),
                        (route) => false,
                      );
                    },
                    child: const Text('Log Out', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
