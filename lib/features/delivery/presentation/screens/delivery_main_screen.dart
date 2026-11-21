import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../order/domain/entities/order_entity.dart';
import '../../domain/entities/delivery_models.dart';
import '../../domain/entities/delivery_api_entities.dart';
import '../bloc/delivery_bloc.dart';
import '../widgets/delivery_hero_banner_carousel.dart';
import '../widgets/delivery_sos_sheet.dart';
import 'delivery_active_navigation_screen.dart';
import 'delivery_auth_screen.dart';
import 'delivery_face_verification_sheet.dart';
import 'delivery_payment_history_screen.dart';
import 'delivery_registration_screen.dart';
import 'delivery_status_screens.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/widgets/legal_policy_screen.dart';
import '../../../../core/widgets/delete_account_dialog.dart';
import '../../../support/presentation/screens/support_tickets_screen.dart';
import '../../../../core/widgets/system_status_banner.dart';
import '../../../../core/widgets/network_and_server_error_view.dart';
import '../../../../core/errors/failures.dart';

class DeliveryMainScreen extends StatefulWidget {
  const DeliveryMainScreen({super.key});

  @override
  State<DeliveryMainScreen> createState() => _DeliveryMainScreenState();
}

class _DeliveryMainScreenState extends State<DeliveryMainScreen> with WidgetsBindingObserver {
  int _selectedTab = 0;
  Timer? _locationPingTimer;
  DateTime? _lastBackPressTime;

  Future<void> _handleBackPress() async {
    // Level 1: If on non-radar/jobs tab, return to Radar (Tab 0)
    if (_selectedTab != 0) {
      setState(() => _selectedTab = 0);
      return;
    }

    // Level 2: Root tab -> Double tap back to exit gracefully
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
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
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
    WidgetsBinding.instance.addObserver(this);
    _startLocationPingerIfOnline();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationPingTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed && mounted) {
      // Promptly refresh jobs when returning to the foreground
      context.read<DeliveryBloc>().add(const FetchDeliveryJobsEvent(filter: 'all'));
    }
  }

  void _startLocationPingerIfOnline() {
    _locationPingTimer?.cancel();
    // Fast background location ping & jobs refresher interval (every 15s)
    _locationPingTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!mounted) return;
      final deliveryState = context.read<DeliveryBloc>().state;
      if (!deliveryState.isOnline) return;

      // When the rider has an active trip, DeliveryActiveNavigationScreen already
      // pings location every 6 seconds. Skip the 60s background ping to avoid
      // redundant UpdateLocationPingEvent dispatches and unnecessary FetchDeliveryJobsEvent
      // calls (rider is busy — no new jobs needed).
      if (deliveryState.activeTrips.isNotEmpty) return;

      final pos = await LocationService.getCurrentPosition(requestIfNeeded: false);
      final lat = pos?.latitude ?? 12.9716;
      final lng = pos?.longitude ?? 77.5946;
      if (mounted) {
        context.read<DeliveryBloc>().add(
              UpdateLocationPingEvent(lat: lat, lng: lng),
            );
        context.read<DeliveryBloc>().add(
              const FetchDeliveryJobsEvent(filter: 'all'),
            );
      }
    });
  }

  Future<void> _goOnlineWithLocation() async {
    final hasPerm = await LocationService.requestLocationPermission(
      context: context,
      isDeliveryPartner: true,
    );
    if (!hasPerm && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Location permission recommended to match nearby store orders!'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 3),
        ),
      );
    }

    final pos = await LocationService.getCurrentPosition(requestIfNeeded: true);
    final lat = pos?.latitude ?? 12.9716;
    final lng = pos?.longitude ?? 77.5946;

    if (!mounted) return;
    context.read<DeliveryBloc>().add(const ToggleDutyEvent(true));
    context.read<DeliveryBloc>().add(UpdateLocationPingEvent(lat: lat, lng: lng));
    context.read<DeliveryBloc>().add(const FetchDeliveryJobsEvent(filter: 'all'));
  }

  void _triggerFaceSelfieCheck() {
    DeliveryFaceVerificationSheet.show(context);
  }

  void _showOfflineReasonPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Reason for Going Offline', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...['Taking a Lunch / Tea Break ☕', 'Shift Ended for the Day 🏠', 'Vehicle Fuel / Charging ⛽', 'Rain / Extreme Weather 🌧️'].map(
              (reason) => ListTile(
                leading: const Icon(Icons.radio_button_unchecked, color: Color(0xFF38BDF8)),
                title: Text(reason, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                onTap: () {
                  context.read<DeliveryBloc>().add(ToggleDutyEvent(false, reason: reason));
                  Navigator.of(ctx).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context, DeliveryState state) {
    context.read<DeliveryBloc>().add(const LoadDeliveryNotificationsEvent(refresh: true));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return BlocBuilder<DeliveryBloc, DeliveryState>(
          builder: (ctx, blState) {
            final notifs = blState.notifications;
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.notifications_active, color: Color(0xFF10B981), size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Notifications',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (blState.unreadNotificationsCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${blState.unreadNotificationsCount}',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (notifs.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            context.read<DeliveryBloc>().add(const MarkAllDeliveryNotificationsReadEvent());
                          },
                          child: const Text('Mark all read', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                        ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 16),
                  Expanded(
                    child: RefreshIndicator(
                      color: const Color(0xFF10B981),
                      onRefresh: () async {
                        context.read<DeliveryBloc>().add(const LoadDeliveryNotificationsEvent(refresh: true));
                      },
                      child: notifs.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                                const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.notifications_off_outlined, size: 48, color: Colors.white24),
                                      SizedBox(height: 12),
                                      Text('No notifications yet', style: TextStyle(color: Colors.white54, fontSize: 14)),
                                      SizedBox(height: 4),
                                      Text(
                                        'New delivery job assignments and alerts will show here',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.white38, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              itemCount: notifs.length,
                              separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                              itemBuilder: (ctx, index) {
                                final item = notifs[index];
                                final typeUpper = item.type.toUpperCase();
                                IconData icon = Icons.notifications_none;
                                Color iconColor = const Color(0xFF38BDF8);
                                if (typeUpper.contains('ASSIGN') || typeUpper.contains('JOB') || typeUpper.contains('ORDER')) {
                                  icon = Icons.directions_bike;
                                  iconColor = const Color(0xFF10B981);
                                } else if (typeUpper.contains('PAY') || typeUpper.contains('WALLET') || typeUpper.contains('EARN')) {
                                  icon = Icons.account_balance_wallet_rounded;
                                  iconColor = const Color(0xFFF59E0B);
                                } else if (typeUpper.contains('KYC') || typeUpper.contains('VERIF') || typeUpper.contains('APPROV')) {
                                  icon = Icons.verified_user_rounded;
                                  iconColor = const Color(0xFF38BDF8);
                                }

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: iconColor.withValues(alpha: 0.18),
                                    child: Icon(icon, color: iconColor, size: 18),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        item.timeAgo,
                                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                                      ),
                                      if (!item.isRead)
                                        Container(
                                          width: 7,
                                          height: 7,
                                          margin: const EdgeInsets.only(left: 6),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      item.body,
                                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ),
                                  onTap: () {
                                    if (!item.isRead) {
                                      context.read<DeliveryBloc>().add(MarkDeliveryNotificationReadEvent(item.id));
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: BlocConsumer<DeliveryBloc, DeliveryState>(
        listenWhen: (prev, curr) =>
            prev.errorMessage != curr.errorMessage ||
            prev.successMessage != curr.successMessage ||
            prev.latestPushNotification != curr.latestPushNotification ||
            prev.isPartnerNotApproved != curr.isPartnerNotApproved ||
            prev.apiProfile?.isApproved != curr.apiProfile?.isApproved ||
            prev.riderKYC.kycStatus != curr.riderKYC.kycStatus,
        listener: (context, state) {
          final latestPush = state.latestPushNotification;
          if (latestPush != null) {
            final fromTap = latestPush['fromTap'] == true;
            if (fromTap) {
              setState(() {
                _selectedTab = state.activeTrips.isNotEmpty ? 1 : 0;
              });
              context.read<DeliveryBloc>().add(const FetchDeliveryJobsEvent(filter: 'all'));
            } else {
              final title = latestPush['title']?.toString() ?? 'New Delivery Alert ⚡';
              final body = latestPush['body']?.toString() ?? latestPush['message']?.toString() ?? '';
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  backgroundColor: const Color(0xFF0F172A),
                  duration: const Duration(seconds: 4),
                  content: Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: Color(0xFF10B981), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (body.isNotEmpty)
                              Text(body, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                  action: SnackBarAction(
                    label: 'VIEW',
                    textColor: const Color(0xFF10B981),
                    onPressed: () {
                      setState(() {
                        _selectedTab = state.activeTrips.isNotEmpty ? 1 : 0;
                      });
                    },
                  ),
                ),
              );
            }
          }
          // Strict Gatekeeper Guard: Prevent unapproved or unverified riders from accessing dashboard
          // Avoid prematurely kicking user to registration during initial loading or temporary server/network outages
          if (!state.isLoading && state.failureType == FailureType.none) {
            final isApproved = !state.isPartnerNotApproved &&
                ((state.apiProfile != null && state.apiProfile!.isApproved && state.apiProfile!.status.toUpperCase() == 'APPROVED') ||
                (state.apiProfile == null && state.riderKYC.kycStatus == KYCStatus.verified));
            if (!isApproved) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  if (state.riderKYC.kycStatus == KYCStatus.unsubmitted && state.apiProfile == null) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const DeliveryRegistrationScreen()),
                    );
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => DeliveryPendingApprovalScreen(apiProfile: state.apiProfile),
                      ),
                    );
                  }
                }
              });
              return;
            }
          }

          if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
            final rawMsg = state.errorMessage!;
            final lowerMsg = rawMsg.toLowerCase();
            // Suppress technical backend state-transition strings from raw UI alerts
            final isTransitionError = lowerMsg.contains('invalid state transition') ||
                lowerMsg.contains('from assigned to accepted');

            if (!isTransitionError) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: const Color(0xFFEF4444),
                  elevation: 6,
                  content: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          rawMsg,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  action: rawMsg.contains('Face Selfie')
                      ? SnackBarAction(
                          label: 'Verify Face',
                          textColor: Colors.amber,
                          onPressed: _triggerFaceSelfieCheck,
                        )
                      : null,
                ),
              );
              context.read<DeliveryBloc>().add(const ClearDeliveryErrorMessageEvent());
            }
          }
          if (state.successMessage != null && state.successMessage!.isNotEmpty) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: const Color(0xFF10B981),
                elevation: 6,
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.successMessage!,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            );
            if (state.activeTrips.isNotEmpty && (_selectedTab == 0 || state.successMessage!.contains('Job Accepted'))) {
              setState(() => _selectedTab = 1);
            } else if (state.activeTrips.isEmpty && (_selectedTab == 1 || state.activeJobStep == DeliveryTripStep.completed || state.successMessage?.contains('Delivery Completed') == true)) {
              setState(() => _selectedTab = 0);
            }
          }
        },
        builder: (context, state) {
          final isApproved = (state.apiProfile != null && state.apiProfile!.isApproved && state.apiProfile!.status.toUpperCase() == 'APPROVED') ||
              (state.apiProfile == null && state.riderKYC.kycStatus == KYCStatus.verified);
          if (!isApproved) {
            if (state.riderKYC.kycStatus == KYCStatus.unsubmitted && state.apiProfile == null) {
              return const DeliveryRegistrationScreen();
            }
            return DeliveryPendingApprovalScreen(apiProfile: state.apiProfile, kycData: state.riderKYC);
          }

          return Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            appBar: _buildAppBar(state),
            body: Column(
              children: [
                if (state.isNetworkOffline)
                  const SystemStatusBar(
                    severity: SystemStatusSeverity.offline,
                    message: 'You are offline • Location tracking and job requests paused',
                  )
                else if (state.isServerDown)
                  SystemStatusBar(
                    severity: SystemStatusSeverity.serverDown,
                    message: 'QuickLink Server Busy • Reconnecting...',
                    actionLabel: 'Retry',
                    onAction: () => context.read<DeliveryBloc>().add(const LoadDeliveryDataEvent()),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      IndexedStack(
                        index: _selectedTab,
                        children: [
                          _buildRadarTab(state),
                          _buildActiveTripTab(state),
                          const DeliveryPaymentHistoryScreen(isEmbedded: true),
                          _buildProfileTab(state),
                        ],
                      ),

                      // Incoming Job Broadcast Radar Modal
                      if (state.incomingJobAlert != null && state.activeTrips.isEmpty)
                        _IncomingJobAlertOverlay(order: state.incomingJobAlert!),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: _buildBottomNav(),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(DeliveryState state) {
    return AppBar(
      backgroundColor: const Color(0xFF0F172A),
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 10,
      title: Row(
        children: [
          GestureDetector(
            onTap: _triggerFaceSelfieCheck,
            child: Stack(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: state.isFaceVerifiedToday ? const Color(0xFF10B981) : Colors.amber,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      state.riderKYC.faceProfilePhotoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => const Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: state.isFaceVerifiedToday ? const Color(0xFF10B981) : Colors.amber,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        state.riderKYC.fullName,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, color: Color(0xFF10B981), size: 14),
                  ],
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${state.riderKYC.vehicleType} • ${state.riderKYC.vehicleNumber}',
                        style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (state.currentZoneId != null && state.currentZoneId!.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4), width: 0.8),
                          ),
                          child: Text(
                            '📍 ${state.currentZoneName}',
                            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 9, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Feature C: Emergency SOS Quick Action Pill
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: InkWell(
            onTap: () => DeliverySosSheet.show(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.6), width: 1.2),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emergency_rounded, color: Color(0xFFEF4444), size: 14),
                  SizedBox(width: 4),
                  Text(
                    'SOS',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Notifications Bell with Badge
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white70),
              tooltip: 'Notifications',
              onPressed: () => _showNotificationsSheet(context, state),
            ),
            if (state.unreadNotificationsCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '${state.unreadNotificationsCount > 9 ? "9+" : state.unreadNotificationsCount}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Duty Pill Switcher
        Container(
          margin: const EdgeInsets.only(right: 14),
          child: GestureDetector(
            onTap: () {
              if (state.isOnline) {
                _showOfflineReasonPicker();
              } else {
                if (state.riderKYC.kycStatus != KYCStatus.verified) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Admin approval required before going Online (FR-DEL-002). Status: ${state.riderKYC.kycStatus == KYCStatus.underReview ? "Under Review" : "Pending"}',
                      ),
                      backgroundColor: const Color(0xFFF59E0B),
                      action: SnackBarAction(
                        label: 'Check Status',
                        textColor: Colors.white,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const DeliveryPendingApprovalScreen()),
                          );
                        },
                      ),
                    ),
                  );
                } else if (!state.isFaceVerifiedToday) {
                  _triggerFaceSelfieCheck();
                } else {
                  _goOnlineWithLocation();
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: state.isOnline
                    ? const Color(0xFF10B981).withValues(alpha: 0.2)
                    : Colors.white12,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: state.isOnline ? const Color(0xFF10B981) : Colors.white24,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: state.isOnline ? const Color(0xFF10B981) : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      state.isOnline ? 'ON DUTY' : 'OFFLINE',
                      style: TextStyle(
                        color: state.isOnline ? const Color(0xFF10B981) : Colors.white60,
                        fontWeight: FontWeight.w900,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRadarTab(DeliveryState state) {
    if (state.failureType != FailureType.none &&
        state.apiJobs.isEmpty &&
        state.availableJobs.isEmpty &&
        state.activeTrips.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFF10B981),
        onRefresh: () async {
          context.read<DeliveryBloc>().add(const LoadDeliveryDataEvent());
        },
        child: NetworkAndServerErrorView(
          failureType: state.failureType,
          customMessage: state.errorMessage,
          isRetrying: state.isLoading,
          onRetry: () => context.read<DeliveryBloc>().add(const LoadDeliveryDataEvent()),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF10B981),
      onRefresh: () async {
        context.read<DeliveryBloc>().add(const FetchDeliveryJobsEvent(filter: 'all'));
        context.read<DeliveryBloc>().add(const FetchDeliveryBannersEvent(forceRefresh: true));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
        // Admin Approval Pending Warning Banner (FR-DEL-002)
        if (state.riderKYC.kycStatus != KYCStatus.verified)
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DeliveryPendingApprovalScreen()),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, color: Color(0xFFF59E0B), size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Account Under Review (FR-DEL-002) • Tap to view verification status & simulator',
                      style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Color(0xFFF59E0B)),
                ],
              ),
            ),
          ),

        // Face Verification Warning if not verified today
        if (!state.isFaceVerifiedToday && state.riderKYC.kycStatus == KYCStatus.verified)
          GestureDetector(
            onTap: _triggerFaceSelfieCheck,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber),
              ),
              child: const Row(
                children: [
                  Icon(Icons.face_retouching_natural, color: Colors.amber, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Daily Face Selfie Pending • Tap to verify identity & receive orders',
                      style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.amber),
                ],
              ),
            ),
          ),

        // Live Telemetry & Quick Shift Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _TelemetryItem(
                  icon: Icons.account_balance_wallet,
                  label: "Today's Payout",
                  value: '₹${state.todayEarnings.toStringAsFixed(0)}',
                  color: const Color(0xFF10B981),
                ),
              ),
              Container(width: 1, height: 32, color: Colors.white12),
              Expanded(
                child: _TelemetryItem(
                  icon: Icons.moped_rounded,
                  label: 'Completed',
                  value: '${state.todayCompletedCount} Trips',
                  color: const Color(0xFF38BDF8),
                ),
              ),
              Container(width: 1, height: 32, color: Colors.white12),
              Expanded(
                child: _TelemetryItem(
                  icon: Icons.radar,
                  label: 'Radar Duty',
                  value: state.isOnline ? 'Online 📡' : 'Offline',
                  color: state.isOnline ? const Color(0xFF10B981) : Colors.grey,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Company Hero Banners (Announcements, Safety Tips, Updates)
        if (state.heroBanners.isNotEmpty) ...[
          DeliveryHeroBannerCarousel(banners: state.heroBanners),
          const SizedBox(height: 18),
        ],

        // Dynamic Offers & Incentive Carousel
        if (state.offers.isNotEmpty) ...[
          const Text('Active Incentives & Boosters 🎁',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: state.offers.length,
              itemBuilder: (ctx, i) {
                final offer = state.offers[i];
                return _OfferBannerCard(offer: offer);
              },
            ),
          ),
          const SizedBox(height: 20),
        ],

        const SizedBox(height: 20),

        // Active Trips Alert
        if (state.activeTrips.isNotEmpty) ...[
          const Text('Active Delivery in Progress 🛵',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ...state.activeTrips.map(
            (order) => _ActiveTripSummaryTile(
              order: order,
              onOpenTrip: () => setState(() => _selectedTab = 1),
            ),
          ),
        ],

        // Available Requests Radar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text('Job Radar & Nearby Pickups 📡',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Text('${state.availableJobs.length} available',
                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),

        if (state.hasZoneMismatch) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Zone Mismatch Notice ⚠️',
                        style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.zoneMismatchNotice!,
                        style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.3),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    context.read<DeliveryBloc>().add(const ToggleCrossZoneScanningEvent());
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: Text(
                    state.isCrossZoneEnabled ? 'Cross-Zone: ON' : 'All Zones',
                    style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (!state.isOnline)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
            child: const Text('You are currently OFFLINE.\nTurn ON Duty to scan nearby merchant orders.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5)),
          )
        else if (state.availableJobs.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                const Icon(Icons.radar_outlined, color: Color(0xFF38BDF8), size: 36),
                const SizedBox(height: 12),
                Text(
                  'Radar Active • Scanning in ${state.currentZoneName}...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'No pending pickup orders within 15 km in your zone at this moment.\nOrders assigned within your 15 km service radius will appear here live.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    context.read<DeliveryBloc>().add(const FetchDeliveryJobsEvent(filter: 'all'));
                  },
                  icon: const Icon(Icons.refresh, size: 14, color: Color(0xFF10B981)),
                  label: const Text('Refresh Radar', style: TextStyle(color: Color(0xFF10B981), fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF10B981), width: 0.8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          )
        else
          ...state.availableJobs.map((order) => _JobRadarCard(order: order)),
      ],
      ),
    );
  }

  Widget _buildActiveTripTab(DeliveryState state) {
    if (state.activeTrips.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.moped_outlined, size: 64, color: Colors.white24),
            const SizedBox(height: 14),
            const Text('No Active Trip at the moment', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Accept a delivery job from the Radar tab to begin navigation.', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () => setState(() => _selectedTab = 0),
              child: const Text('Go to Radar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    final activeOrder = state.activeTrips.first;
    return DeliveryActiveNavigationScreen(
      order: activeOrder,
      isEmbedded: true,
      onBackToRadar: () => setState(() => _selectedTab = 0),
    );
  }

  Widget _buildProfileTab(DeliveryState state) {
    final kyc = state.riderKYC;
    final api = state.apiProfile;
    final authState = context.read<AuthBloc>().state;
    final authUser = authState is AuthenticatedState ? authState.user : null;

    final resolvedName = (kyc.fullName.isNotEmpty && kyc.fullName != 'Vikram Singh')
        ? kyc.fullName
        : ((authUser?.name.isNotEmpty == true && authUser!.name != 'Customer' && authUser.name != 'Delivery Partner')
            ? authUser.name
            : (kyc.fullName.isNotEmpty ? kyc.fullName : 'Delivery Partner'));

    final resolvedPhone = api?.phone.isNotEmpty == true
        ? api!.phone
        : ((kyc.phone.isNotEmpty && kyc.phone != '+91 91234 56789')
            ? kyc.phone
            : (authUser?.phone.isNotEmpty == true ? authUser!.phone : kyc.phone));

    final resolvedVehicle = api != null && api.vehicleNumber.isNotEmpty
        ? '${api.vehicleType} (${api.vehicleNumber})${api.vehicleModel.isNotEmpty ? ' • ${api.vehicleModel}' : ''}'
        : (kyc.vehicleNumber.isNotEmpty
            ? '${kyc.vehicleType} (${kyc.vehicleNumber})'
            : 'Pending Vehicle Registration');

    final resolvedDl = api?.licenseNumber.isNotEmpty == true
        ? api!.licenseNumber
        : (kyc.dlNumber.isNotEmpty ? kyc.dlNumber : 'DL Pending');

    final isApproved = api?.isApproved == true || kyc.kycStatus == KYCStatus.verified;
    final isPending = (api?.status == 'PENDING' || kyc.kycStatus == KYCStatus.underReview) && !isApproved;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Digital ID Badge
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isApproved
                  ? const Color(0xFF10B981).withValues(alpha: 0.5)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isApproved ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        width: 2.5,
                      ),
                    ),
                    child: ClipOval(
                      child: kyc.faceProfilePhotoUrl.isNotEmpty
                          ? Image.network(
                              kyc.faceProfilePhotoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => const Icon(Icons.person, size: 40, color: Colors.white),
                            )
                          : const Icon(Icons.person, size: 40, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resolvedName,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          resolvedPhone,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isApproved
                                ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                : (isPending
                                    ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                                    : Colors.red.withValues(alpha: 0.2)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isApproved
                                ? 'APPROVED & ACTIVE RIDER ✓'
                                : (isPending ? 'APPLICATION UNDER REVIEW ⏳' : 'APPLICATION REJECTED ❌'),
                            style: TextStyle(
                              color: isApproved
                                  ? const Color(0xFF10B981)
                                  : (isPending ? const Color(0xFFF59E0B) : Colors.redAccent),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 24),
              _ProfileDetailRow(title: 'Rider ID', value: api?.id.isNotEmpty == true ? api!.id : (kyc.riderId.isNotEmpty ? kyc.riderId : 'Active Rider')),
              _ProfileDetailRow(
                title: 'Aadhaar ID',
                value: kyc.maskedAadhaar.isNotEmpty ? kyc.maskedAadhaar : 'Verified Partner Document ✓',
              ),
              _ProfileDetailRow(title: 'Driving License', value: resolvedDl),
              _ProfileDetailRow(title: 'Vehicle', value: resolvedVehicle),
              _ProfileDetailRow(title: 'Assigned Hub Zone', value: state.currentZoneName),
              _ProfileDetailRow(
                title: 'Home Address',
                value: (kyc.fullAddress.trim().isNotEmpty && kyc.fullAddress != ', , ,  - ')
                    ? kyc.fullAddress
                    : (kyc.street.isNotEmpty
                        ? '${kyc.houseNo.isNotEmpty ? '${kyc.houseNo}, ' : ''}${kyc.street}${kyc.city.isNotEmpty ? ', ${kyc.city}' : ''}${kyc.pincode.isNotEmpty ? ' - ${kyc.pincode}' : ''}'
                        : 'Address recorded in verified KYC'),
              ),
              _ProfileDetailRow(
                title: 'UPI Payout',
                value: kyc.upiId.isNotEmpty
                    ? kyc.upiId
                    : (kyc.bankAccount.isNotEmpty
                        ? 'A/C: ••••${kyc.bankAccount.length > 4 ? kyc.bankAccount.substring(kyc.bankAccount.length - 4) : kyc.bankAccount}'
                        : '$resolvedPhone@okhdfcbank'),
              ),
              if (api != null) ...[
                _ProfileDetailRow(title: 'Partner Rating', value: '${api.rating > 0 ? api.rating.toStringAsFixed(1) : '5.0'} ⭐'),
                _ProfileDetailRow(title: 'Total Deliveries', value: '${api.totalDeliveries > 0 ? api.totalDeliveries : state.todayCompletedCount} Completed'),
                _ProfileDetailRow(title: 'Service Radius', value: '${api.serviceRadius} km'),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Edit KYC / Verification Actions
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: const Color(0xFF1E293B),
          leading: const Icon(Icons.face_retouching_natural, color: Color(0xFF10B981)),
          title: const Text('Update Live Face Biometrics', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
          onTap: _triggerFaceSelfieCheck,
        ),
        const SizedBox(height: 10),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: const Color(0xFF1E293B),
          leading: const Icon(Icons.badge, color: Color(0xFF38BDF8)),
          title: const Text('Update KYC Documents & Address', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DeliveryRegistrationScreen(
                  initialName: resolvedName,
                  initialPhone: resolvedPhone,
                  initialKYC: kyc,
                  initialProfile: api,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: const Color(0xFF1E293B),
          leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF10B981)),
          title: const Text('Privacy Policy & Telematics', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: const Text('Background location and data disclosure', style: TextStyle(color: Colors.white60, fontSize: 11)),
          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LegalPolicyScreen(initialTabIndex: 0)),
            );
          },
        ),
        const SizedBox(height: 10),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: const Color(0xFF1E293B),
          leading: const Icon(Icons.description_outlined, color: Color(0xFF38BDF8)),
          title: const Text('Partner Terms of Service', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: const Text('Rider agreement & service policies', style: TextStyle(color: Colors.white60, fontSize: 11)),
          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LegalPolicyScreen(initialTabIndex: 1)),
            );
          },
        ),
        const SizedBox(height: 10),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: const Color(0xFF1E293B),
          leading: const Icon(Icons.verified_user_outlined, color: Color(0xFFA855F7)),
          title: const Text('Data Safety & Permissions', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: const Text('Google Play transparent declarations', style: TextStyle(color: Colors.white60, fontSize: 11)),
          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LegalPolicyScreen(initialTabIndex: 2)),
            );
          },
        ),
        const SizedBox(height: 10),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: const Color(0xFF1E293B),
          leading: const Icon(Icons.support_agent_rounded, color: Color(0xFF10B981)),
          title: const Text('24x7 Rider Support & Tickets', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: const Text('Report order, payout, or app issues directly', style: TextStyle(color: Colors.white60, fontSize: 11)),
          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
          onTap: () {
            Navigator.of(context).push(
              SupportTicketsScreen.route(app: 'rider'),
            );
          },
        ),
        const SizedBox(height: 10),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: Colors.red.withValues(alpha: 0.1),
          leading: const Icon(Icons.logout, color: Colors.redAccent),
          title: const Text('Logout from Quick Reach', style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
          trailing: const Icon(Icons.chevron_right, color: Colors.redAccent),
          onTap: () {
            context.read<DeliveryBloc>().add(const ResetDeliveryStateEvent());
            context.read<AuthBloc>().add(LogoutEvent());
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DeliveryAuthScreen()),
            );
          },
        ),
        const SizedBox(height: 8),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent, size: 16),
                label: const Text(
                  'Delete Partner Account & Wipe KYC',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
                onPressed: () => DeleteAccountDialog.show(context, isDeliveryPartner: true),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Web Deletion: Log in with credentials at https://app.quicktick.shop/login, go to Profile section, and select "Delete Account" to permanently erase account data.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.6),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (i) => setState(() => _selectedTab = i),
        backgroundColor: const Color(0xFF0F172A),
        selectedItemColor: const Color(0xFF10B981),
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Radar'),
          BottomNavigationBarItem(icon: Icon(Icons.navigation), label: 'Active Trip'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Payments'),
          BottomNavigationBarItem(icon: Icon(Icons.badge), label: 'ID Profile'),
        ],
      ),
    );
  }
}

class _TelemetryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _TelemetryItem({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10), maxLines: 1),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1),
        ),
      ],
    );
  }
}

class _OfferBannerCard extends StatelessWidget {
  final DeliveryOfferEntity offer;
  const _OfferBannerCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(offer.tag, style: const TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold)),
              ),
              Flexible(
                child: Text('₹${offer.bonusReward.toStringAsFixed(0)} Bonus',
                    style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w900),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          Text(offer.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          Text(offer.subtitle, style: const TextStyle(color: Colors.white60, fontSize: 10), maxLines: 1),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: offer.progress,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveTripSummaryTile extends StatelessWidget {
  final OrderEntity order;
  final VoidCallback? onOpenTrip;
  const _ActiveTripSummaryTile({required this.order, this.onOpenTrip});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981)),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_bike, color: Color(0xFF10B981), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${order.orderNumber}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${order.storeName} ➔ ${order.customerName}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (onOpenTrip != null) {
                onOpenTrip!();
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DeliveryActiveNavigationScreen(order: order)),
                );
              }
            },
            child: const Text('Open Trip 🗺️', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _JobRadarCard extends StatefulWidget {
  final OrderEntity order;
  const _JobRadarCard({required this.order});

  @override
  State<_JobRadarCard> createState() => _JobRadarCardState();
}

class _JobRadarCardState extends State<_JobRadarCard> {
  Timer? _countdownTimer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _initCountdown();
  }

  void _initCountdown() {
    final state = context.read<DeliveryBloc>().state;
    DeliveryJobEntity? apiJob;
    for (final j in state.apiJobs) {
      if (j.id == widget.order.id) {
        apiJob = j;
        break;
      }
    }
    if (apiJob?.assignment?.expiresAt != null) {
      _secondsRemaining = apiJob!.assignment!.secondsRemaining;
    } else {
      _secondsRemaining = 0;
    }

    if (_secondsRemaining > 0) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_secondsRemaining <= 1) {
          timer.cancel();
          context.read<DeliveryBloc>().add(RemoveExpiredJobEvent(widget.order.id));
        } else {
          setState(() {
            _secondsRemaining--;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final payout = order.deliveryFee > 0 ? order.deliveryFee : 55.0;
    final isCod = order.paymentMethod.toUpperCase() == 'COD';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Order #${order.orderNumber}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCod ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : const Color(0xFF38BDF8).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isCod ? const Color(0xFFF59E0B).withValues(alpha: 0.4) : const Color(0xFF38BDF8).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            isCod ? 'COD 💵' : 'PAID 💳',
                            style: TextStyle(
                              color: isCod ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (order.zoneId != null && order.zoneId!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, size: 10, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                order.resolvedZoneName,
                                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Payout: ₹${payout.toStringAsFixed(0)}',
                      style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),
                  if (_secondsRemaining > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, size: 10, color: Color(0xFFEF4444)),
                          const SizedBox(width: 3),
                          Text(
                            'Expires in ${_secondsRemaining ~/ 60}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Complete Pickup Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.store, color: Color(0xFF38BDF8), size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.storeName,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    if (order.storeAddress.isNotEmpty)
                      Text(
                        order.storeAddress,
                        style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Complete Delivery Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.pin_drop, color: Color(0xFFF59E0B), size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deliver to: ${order.customerName.isNotEmpty ? order.customerName : 'Customer'}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      order.deliveryAddress,
                      style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (order.items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.shopping_bag_outlined, color: Colors.white38, size: 14),
                const SizedBox(width: 6),
                Text(
                  '${order.items.length} ${order.items.length == 1 ? 'item' : 'items'} to deliver',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    context.read<DeliveryBloc>().add(AcceptDeliveryJobEvent(orderId: order.id));
                  },
                  child: const Text('Accept Delivery 🛵', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IncomingJobAlertOverlay extends StatefulWidget {
  final OrderEntity order;
  const _IncomingJobAlertOverlay({required this.order});

  @override
  State<_IncomingJobAlertOverlay> createState() => _IncomingJobAlertOverlayState();
}

class _IncomingJobAlertOverlayState extends State<_IncomingJobAlertOverlay> {
  int _secondsLeft = 30;
  Timer? _timer;
  bool _isAccepting = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        t.cancel();
        context.read<DeliveryBloc>().add(DeclineDeliveryJobEvent(
          widget.order.id,
          reason: 'Timeout (30s auto-decline)',
        ));
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showDeclineReasonSheet() {
    _timer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reason for Declining (FR-DEL-005)',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...[
              'Store is too far from current location 📍',
              'Vehicle battery / petrol is low ⛽',
              'Rain / extreme weather difficulty 🌧️',
              'Personal emergency / ending shift 🏠',
            ].map(
              (reason) => ListTile(
                leading: const Icon(Icons.radio_button_unchecked, color: Color(0xFF38BDF8)),
                title: Text(reason, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.read<DeliveryBloc>().add(DeclineDeliveryJobEvent(widget.order.id, reason: reason));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payout = widget.order.deliveryFee > 0 ? widget.order.deliveryFee : 55.0;

    return Positioned(
      bottom: 12,
      left: 14,
      right: 14,
      child: SafeArea(
        top: false,
        child: BlocListener<DeliveryBloc, DeliveryState>(
          listener: (context, state) {
            if (state.errorMessage != null && _isAccepting && mounted) {
              setState(() => _isAccepting = false);
            }
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF10B981), width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.radar, color: Color(0xFF10B981), size: 16),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'NEW ORDER ALERT',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _secondsLeft < 10
                          ? Colors.red.withValues(alpha: 0.2)
                          : Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _secondsLeft < 10
                            ? Colors.redAccent.withValues(alpha: 0.4)
                            : Colors.amber.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '${_secondsLeft}s left ⏱️',
                      style: TextStyle(
                        color: _secondsLeft < 10 ? Colors.redAccent : Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Linear countdown line
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (_secondsLeft / 30.0).clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _secondsLeft < 10 ? Colors.redAccent : const Color(0xFF10B981),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Store Name
              Row(
                children: [
                  const Icon(Icons.storefront_outlined, color: Colors.white70, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.order.storeName.isNotEmpty ? widget.order.storeName : 'Merchant Store',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Pickup Address
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.north_east_rounded, color: Color(0xFF10B981), size: 14),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Pickup: ${widget.order.storeAddress.isNotEmpty ? widget.order.storeAddress : "Store Location"}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Drop Address
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.location_on, color: Color(0xFF38BDF8), size: 14),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Drop: ${widget.order.deliveryAddress.isNotEmpty ? widget.order.deliveryAddress : "Customer Address"}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Actions Row
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 42,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isAccepting ? null : _showDeclineReasonSheet,
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Decline',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          backgroundColor: const Color(0xFF10B981),
                          disabledBackgroundColor: const Color(0xFF10B981).withValues(alpha: 0.6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                        onPressed: _isAccepting
                            ? null
                            : () {
                                _timer?.cancel();
                                setState(() => _isAccepting = true);
                                context.read<DeliveryBloc>().add(AcceptDeliveryJobEvent(orderId: widget.order.id));
                              },
                        child: _isAccepting
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Accepting...',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              )
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Accept Job (Earn ₹${payout.toStringAsFixed(0)})',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  ),
),
);
  }
}

class _ProfileDetailRow extends StatelessWidget {
  final String title;
  final String value;
  const _ProfileDetailRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
