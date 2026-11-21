import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/delivery_models.dart';
import '../../domain/entities/delivery_api_entities.dart';
import '../bloc/delivery_bloc.dart';
import 'delivery_auth_screen.dart';
import 'delivery_main_screen.dart';
import '../widgets/delivery_hero_banner_carousel.dart';
import '../../../support/presentation/screens/support_tickets_screen.dart';

class DeliveryPendingApprovalScreen extends StatelessWidget {
  final RiderKYCEntity? kycData;
  final DeliveryPartnerProfileEntity? apiProfile;
  const DeliveryPendingApprovalScreen({super.key, this.kycData, this.apiProfile});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DeliveryBloc, DeliveryState>(
      listenWhen: (prev, curr) =>
          prev.riderKYC.kycStatus != curr.riderKYC.kycStatus ||
          prev.apiProfile?.status != curr.apiProfile?.status,
      listener: (context, state) {
        final isApproved = (state.apiProfile != null && state.apiProfile!.isApproved && state.apiProfile!.status.toUpperCase() == 'APPROVED') ||
            (state.apiProfile == null && state.riderKYC.kycStatus == KYCStatus.verified);
        if (isApproved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Congratulations! Your Delivery Partner profile has been approved!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DeliveryMainScreen()),
          );
        }
      },
      builder: (context, state) {
        final kyc = kycData ?? state.riderKYC;
        final isApproved = (state.apiProfile != null && state.apiProfile!.isApproved && state.apiProfile!.status.toUpperCase() == 'APPROVED') ||
            (state.apiProfile == null && kyc.kycStatus == KYCStatus.verified);
        final isRejected = (state.apiProfile != null && state.apiProfile!.isRejected) ||
            (state.apiProfile == null && kyc.kycStatus == KYCStatus.rejected);

        void handleBack() {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DeliveryAuthScreen()),
            );
          }
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) handleBack();
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            appBar: AppBar(
              backgroundColor: const Color(0xFF0F172A),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: handleBack,
              ),
              title: const Text(
                'Verification Status',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),

                  // Status Icon with Pulse Ring
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isApproved
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : isRejected
                              ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      border: Border.all(
                        color: isApproved
                            ? const Color(0xFF10B981)
                            : isRejected
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFF59E0B),
                        width: 2.5,
                      ),
                    ),
                    child: Icon(
                      isApproved
                          ? Icons.check_circle_rounded
                          : isRejected
                              ? Icons.cancel_rounded
                              : Icons.hourglass_top_rounded,
                      color: isApproved
                          ? const Color(0xFF10B981)
                          : isRejected
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFF59E0B),
                      size: 52,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    isApproved
                        ? 'Profile Approved! 🎉'
                        : isRejected
                            ? 'Application Requires Correction'
                            : 'Application Under Review',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    isApproved
                        ? 'Your partner account is active. You can now go online and accept orders.'
                        : isRejected
                            ? 'Certain documents need re-upload before approval can be granted.'
                            : 'Admin verification is in progress pursuant to statutory partner onboarding compliance (FR-DEL-002).',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  // Hero Banners (Company Announcements, Guidelines & Safety Updates)
                  if (state.heroBanners.isNotEmpty) ...[
                    DeliveryHeroBannerCarousel(banners: state.heroBanners),
                    const SizedBox(height: 20),
                  ],

                  // Application Reference Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'APPLICATION DETAILS',
                              style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (isApproved ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isApproved ? 'APPROVED' : 'IN REVIEW',
                                style: TextStyle(
                                  color: isApproved ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Builder(
                          builder: (context) {
                            final authState = context.read<AuthBloc>().state;
                            final authUser = authState is AuthenticatedState ? authState.user : null;
                            final displayPhone = (apiProfile?.phone.isNotEmpty == true)
                                ? apiProfile!.phone
                                : (kyc.phone.isNotEmpty ? kyc.phone : (authUser?.phone ?? ''));
                            final displayName = (kyc.fullName.isNotEmpty && kyc.fullName != 'Vikram Singh')
                                ? kyc.fullName
                                : (authUser?.name != null && authUser!.name.isNotEmpty && authUser.name != 'Customer' && authUser.name != 'Delivery Partner'
                                    ? authUser.name
                                    : (displayPhone.isNotEmpty ? displayPhone : 'Delivery Partner'));
                            final displayVehicle = (apiProfile != null && apiProfile!.vehicleNumber.isNotEmpty)
                                ? '${apiProfile!.vehicleType} • ${apiProfile!.vehicleNumber}'
                                : (kyc.vehicleNumber.isNotEmpty ? '${kyc.vehicleType} • ${kyc.vehicleNumber}' : 'Vehicle Pending');
                            final displayDl = (apiProfile != null && apiProfile!.licenseNumber.isNotEmpty)
                                ? apiProfile!.licenseNumber
                                : (kyc.dlNumber.isNotEmpty ? kyc.dlNumber : 'DL Pending');
                            final displayUpi = kyc.upiId.isNotEmpty ? kyc.upiId : (displayPhone.isNotEmpty ? '$displayPhone@upi' : 'Pending Settlement');

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow('Partner Name', displayName),
                                _buildDetailRow('Contact Phone', displayPhone),
                                _buildDetailRow('Registered Vehicle', displayVehicle),
                                _buildDetailRow('Driving Licence', displayDl),
                                _buildDetailRow('Payout UPI ID', displayUpi),
                                _buildDetailRow('Review Window', 'Standard TAT: 2-4 Hours'),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Checklist of verification steps
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Verification Checklist',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        _buildCheckItem('UIDAI Aadhaar Document Verified', isDone: true),
                        _buildCheckItem('Driving Licence Legitimacy Check', isDone: true),
                        _buildCheckItem('Vehicle Registration (RC) Verification', isDone: true),
                        _buildCheckItem('Bank / UPI Settlement Payout Channel', isDone: true),
                        _buildCheckItem('Operations Admin Account Approval', isDone: isApproved),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Admin Demo Simulator Button
                  // Check Live Status Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.read<DeliveryBloc>().add(const FetchDeliveryProfileEvent());
                        context.read<DeliveryBloc>().add(const FetchDeliveryBannersEvent(forceRefresh: true));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Checking latest verification status from backend...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh, color: Color(0xFF38BDF8), size: 18),
                      label: const Text(
                        'CHECK STATUS FROM SERVER (GET /delivery/me)',
                        style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF38BDF8)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Contact Rider Support Button (POST /support/tickets app: "rider")
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          SupportTicketsScreen.route(app: 'rider'),
                        );
                      },
                      icon: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 18),
                      label: const Text(
                        'CONTACT RIDER SUPPORT',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Sign out / Back to Login
                  TextButton.icon(
                    onPressed: () {
                      context.read<DeliveryBloc>().add(const ResetDeliveryStateEvent());
                      context.read<AuthBloc>().add(LogoutEvent());
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const DeliveryAuthScreen()),
                      );
                    },
                    icon: const Icon(Icons.logout, color: Colors.white60, size: 16),
                    label: const Text('Return to Login', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      );
    },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String title, {required bool isDone}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: isDone ? const Color(0xFF10B981) : Colors.white38,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isDone ? Colors.white : Colors.white54,
                fontSize: 12,
                fontWeight: isDone ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
