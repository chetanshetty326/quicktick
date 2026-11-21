import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../customer/domain/entities/catalog_entities.dart';
import '../../../order/domain/entities/order_entity.dart';
import '../bloc/retailer_bloc.dart';
import '../../domain/entities/retailer_entities.dart';
import '../../domain/entities/retailer_finance_entities.dart';
import '../widgets/retailer_notifications_sheet.dart';
import '../widgets/retailer_order_details_sheet.dart';
import '../widgets/retailer_reject_dialog.dart';
import '../widgets/retailer_product_image_picker.dart';
import '../widgets/retailer_order_stats_card.dart';
import '../widgets/retailer_hero_banner_carousel.dart';
import '../widgets/subscription_renewal_sheet.dart';
import '../widgets/retailer_barcode_scanner_sheet.dart';
import 'retailer_auth_screen.dart';
import 'retailer_registration_screen.dart';
import 'retailer_status_screens.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../core/widgets/legal_policy_screen.dart';
import '../../../../core/widgets/system_status_banner.dart';
import '../../../../core/widgets/network_and_server_error_view.dart';
import '../../../../core/errors/failures.dart';
import '../../../support/presentation/screens/support_tickets_screen.dart';

class RetailerMainScreen extends StatefulWidget {
  const RetailerMainScreen({super.key});

  @override
  State<RetailerMainScreen> createState() => _RetailerMainScreenState();
}

class _RetailerMainScreenState extends State<RetailerMainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _lastBackPressTime;

  void _handleBackPress() {
    // Level 1: If on non-first tab, switch back to 'Live Orders' (Tab 0)
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
      return;
    }

    // Level 2: Root Live Orders tab -> Double tap back to exit
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
      SystemNavigator.pop();
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RetailerBloc>().add(const LoadRetailerDataEvent());
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RetailerBloc, RetailerState>(
      listenWhen: (previous, current) =>
          previous.isLoading != current.isLoading ||
          previous.successMessage != current.successMessage ||
          previous.errorMessage != current.errorMessage ||
          previous.latestPushNotification != current.latestPushNotification ||
          previous.registrationStatus != current.registrationStatus ||
          previous.showSubscriptionRequiredSheet != current.showSubscriptionRequiredSheet,
      listener: (context, state) {
        final latestPush = state.latestPushNotification;
        if (latestPush != null && latestPush['fromTap'] == true) {
          if (_tabController.index != 0) {
            _tabController.animateTo(0);
          }
          context.read<RetailerBloc>().add(const PollRetailerOrdersEvent());
        }
        if (state.showSubscriptionRequiredSheet) {
          SubscriptionRenewalSheet.show(context);
        }
        if (state.registrationStatus == RetailerRegistrationStatus.suspended) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const RetailerSuspendedScreen()),
          );
          return;
        } else if (state.registrationStatus == RetailerRegistrationStatus.rejected) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const RetailerRejectedScreen()),
          );
          return;
        } else if (state.registrationStatus == RetailerRegistrationStatus.pendingApproval) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RetailerAwaitingApprovalScreen(shopName: state.registeredShopName),
            ),
          );
          return;
        }
        if (!state.isLoading) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
        if (state.successMessage != null && state.successMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.successMessage!,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleBackPress();
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            elevation: 0,
            title: BlocBuilder<RetailerBloc, RetailerState>(
              builder: (context, state) {
                final storeName = state.profile?.storeName ?? 'Quick Mart Partner';
                final storeAddress = state.profile?.address ?? 'Indiranagar Dark Store • FSSAI Verified';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(storeName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(storeAddress, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                );
              },
            ),
            actions: [
              BlocBuilder<RetailerBloc, RetailerState>(
                buildWhen: (prev, curr) => prev.unreadNotificationsCount != curr.unreadNotificationsCount,
                builder: (context, state) {
                  final count = state.unreadNotificationsCount;
                  return IconButton(
                    icon: Badge(
                      isLabelVisible: count > 0,
                      label: Text('$count', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                      backgroundColor: const Color(0xFF10B981),
                      child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                    ),
                    tooltip: 'Store Alerts',
                    onPressed: () => RetailerNotificationsSheet.show(context),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 22),
                tooltip: 'Partner Support & Tickets',
                onPressed: () {
                  Navigator.of(context).push(
                    SupportTicketsScreen.route(app: 'retailer'),
                  );
                },
              ),
              BlocBuilder<RetailerBloc, RetailerState>(
                builder: (context, state) {
                  return Row(
                    children: [
                      Text(
                        state.isStoreOpen ? 'OPEN' : 'CLOSED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: state.isStoreOpen ? const Color(0xFF34D399) : const Color(0xFFF87171),
                        ),
                      ),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: state.isStoreOpen,
                          activeTrackColor: const Color(0xFF10B981),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: const Color(0xFF475569),
                          onChanged: (val) {
                            final targetStoreId = state.profile?.id;
                            if (targetStoreId == null || targetStoreId.isEmpty) return; // profile not loaded yet
                            context.read<RetailerBloc>().add(ToggleStoreStatusEvent(targetStoreId, val));
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
                tooltip: 'Log Out',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Row(
                        children: [
                          Icon(Icons.logout, color: Colors.redAccent, size: 22),
                          SizedBox(width: 8),
                          Text('Log Out', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      content: const Text(
                        'Are you sure you want to log out of your merchant account?',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            context.read<AuthBloc>().add(LogoutEvent());
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const RetailerAuthScreen()),
                              (route) => false,
                            );
                          },
                          child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF34D399),
              unselectedLabelColor: const Color(0xFF94A3B8),
              indicatorColor: const Color(0xFF34D399),
              indicatorWeight: 3,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'Live Orders'),
                Tab(icon: Icon(Icons.inventory_2_outlined, size: 18), text: 'Inventory & Stocks'),
                Tab(icon: Icon(Icons.account_balance_wallet_outlined, size: 18), text: 'Settlements & Payouts'),
                Tab(icon: Icon(Icons.verified_user_outlined, size: 18), text: 'FSSAI & Store'),
              ],
            ),
          ),
          body: Column(
            children: [
              BlocBuilder<RetailerBloc, RetailerState>(
                buildWhen: (prev, curr) => prev.failureType != curr.failureType,
                builder: (context, state) {
                  if (state.isOffline) {
                    return const SystemStatusBar(
                      severity: SystemStatusSeverity.offline,
                      message: 'You are offline • Orders cannot be received until online',
                    );
                  }
                  if (state.isServerDown) {
                    return const SystemStatusBar(
                      severity: SystemStatusSeverity.serverDown,
                      message: 'Quicktick Server Busy • Reconnecting...',
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    _RetailerOrdersTab(),
                    _RetailerInventoryTab(),
                    _RetailerFinancialsTab(),
                    _RetailerProfileTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================
// 1. LIVE ORDERS TAB (WITH STATUS SEGMENT FILTERS)
// ====================================================
class _RetailerOrdersTab extends StatefulWidget {
  const _RetailerOrdersTab();

  @override
  State<_RetailerOrdersTab> createState() => _RetailerOrdersTabState();
}

class _RetailerOrdersTabState extends State<_RetailerOrdersTab> {
  String _selectedStatusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RetailerBloc, RetailerState>(
      builder: (context, state) {
        if (state.isLoading && state.orders.isEmpty) {
          return const RetailerOrdersSkeleton();
        }

        if (state.failureType != FailureType.none && state.orders.isEmpty) {
          return NetworkAndServerErrorView(
            failureType: state.failureType,
            customMessage: state.errorMessage,
            isRetrying: state.isLoading,
            onRetry: () {
              final storeId = state.profile?.id ?? '';
              context.read<RetailerBloc>().add(LoadRetailerDataEvent(storeId: storeId));
            },
          );
        }

        final allOrders = state.orders;
        final newOrders = allOrders.where((o) => o.status == OrderStatus.placed).toList();
        final preparingOrders = allOrders.where((o) => o.status == OrderStatus.accepted || o.status == OrderStatus.preparing).toList();
        final readyOrders = allOrders.where((o) => o.status == OrderStatus.readyForPickup || o.status == OrderStatus.assigned || o.status == OrderStatus.pickedUp || o.status == OrderStatus.outForDelivery).toList();
        final completedOrders = allOrders.where((o) => o.status == OrderStatus.delivered || o.status == OrderStatus.cancelled || o.status == OrderStatus.rejected).toList();

        List<OrderEntity> displayedOrders;
        switch (_selectedStatusFilter) {
          case 'placed':
            displayedOrders = newOrders;
            break;
          case 'preparing':
            displayedOrders = preparingOrders;
            break;
          case 'ready':
            displayedOrders = readyOrders;
            break;
          case 'completed':
            displayedOrders = completedOrders;
            break;
          case 'all':
          default:
            displayedOrders = allOrders;
            break;
        }

        final filterOptions = [
          {'id': 'all', 'label': 'All Orders', 'count': allOrders.length, 'color': const Color(0xFF0F172A)},
          {'id': 'placed', 'label': 'New / Placed', 'count': newOrders.length, 'color': const Color(0xFFF59E0B)},
          {'id': 'preparing', 'label': 'Preparing', 'count': preparingOrders.length, 'color': const Color(0xFF3B82F6)},
          {'id': 'ready', 'label': 'Ready for Pickup', 'count': readyOrders.length, 'color': const Color(0xFF10B981)},
          {'id': 'completed', 'label': 'History / Done', 'count': completedOrders.length, 'color': const Color(0xFF64748B)},
        ];

        return RefreshIndicator(
          color: const Color(0xFF10B981),
          onRefresh: () async {
            context.read<RetailerBloc>().add(const LoadRetailerDataEvent());
            context.read<RetailerBloc>().add(const FetchRetailerBannersEvent(forceRefresh: true));
            await Future.delayed(const Duration(milliseconds: 600));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              // Trial Expiry Warning Banner (Spec: daysRemaining <= 3)
              if (state.subscription != null &&
                  ((state.subscription!.isTrial && state.subscription!.daysRemaining <= 3) ||
                      state.subscription!.isExpired)) ...[
                GestureDetector(
                  onTap: () => SubscriptionRenewalSheet.show(context),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: state.subscription!.isExpired
                            ? [const Color(0xFF991B1B), const Color(0xFFDC2626)]
                            : [const Color(0xFFB45309), const Color(0xFFD97706)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (state.subscription!.isExpired
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFD97706))
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.subscription!.isExpired
                                    ? 'Subscription Expired'
                                    : 'Free Trial Expiring (${state.subscription!.daysRemaining} Days Left)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                state.subscription!.isExpired
                                    ? 'Order acceptance is paused. Renew now to resume orders.'
                                    : 'Renew today to keep accepting orders without interruption.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            state.subscription!.isExpired ? 'RENEW' : 'UPGRADE',
                            style: TextStyle(
                              color: state.subscription!.isExpired
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFB45309),
                              fontWeight: FontWeight.w900,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // High-Priority Incoming Ringing Order Alert Banner
              if (newOrders.isNotEmpty) ...[
                _IncomingOrderAlertCard(
                  count: newOrders.length,
                  firstOrder: newOrders.first,
                  onAccept: () {
                    context.read<RetailerBloc>().add(AcceptOrderEvent(newOrders.first.id));
                  },
                  onView: () {
                    RetailerOrderDetailsSheet.show(context, order: newOrders.first);
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Real-Time Today's Order Statistics & Revenue Dashboard Card
              const RetailerOrderStatsCard(),
              const SizedBox(height: 16),

              // My Plan Subscription Card
              BlocBuilder<RetailerBloc, RetailerState>(
                buildWhen: (prev, curr) => prev.subscription != curr.subscription,
                builder: (context, state) {
                  return _RetailerMyPlanCard(subscription: state.subscription);
                },
              ),
              const SizedBox(height: 16),

              // 1. Company Announcement & Dynamic Banner Carousel
              const RetailerHeroBannerCarousel(),
              const SizedBox(height: 16),

              // 2. Company Offers & Worker Incentives Hub
              const _CompanyOffersSection(),
              const SizedBox(height: 16),

              // 3. Section Header: Live Incoming Orders
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'STORE ORDERS PIPELINE',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.8,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF059669),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${displayedOrders.length} Shown',
                          style: const TextStyle(
                            color: Color(0xFF065F46),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 4. Status Filter Segment Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: filterOptions.map((opt) {
                    final id = opt['id'] as String;
                    final label = opt['label'] as String;
                    final count = opt['count'] as int;
                    final isSelected = _selectedStatusFilter == id;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () {
                          setState(() => _selectedStatusFilter = id);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.12),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                  color: isSelected ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF10B981) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: isSelected ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // 5. Orders List or Empty State
              if (displayedOrders.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_rounded, size: 52, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        _selectedStatusFilter == 'all'
                            ? 'No Incoming Orders Right Now'
                            : 'No Orders in ${_selectedStatusFilter.toUpperCase()} Stage',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'New customer orders and status updates will ring here automatically.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ...displayedOrders.map((order) => _OrderPartnerCard(order: order)),
            ],
          ),
        );
      },
    );
  }
}

// ====================================================
// INCOMING RINGING ORDER ALERT CARD (RESPONSIVE)
// ====================================================
class _IncomingOrderAlertCard extends StatelessWidget {
  final int count;
  final OrderEntity firstOrder;
  final VoidCallback onAccept;
  final VoidCallback onView;

  const _IncomingOrderAlertCard({
    required this.count,
    required this.firstOrder,
    required this.onAccept,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 1 ? '🔔 NEW ORDER RECEIVED!' : '🔔 $count NEW ORDERS RECEIVED!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Order #${firstOrder.orderNumber} • ₹${firstOrder.grandTotal.toStringAsFixed(0)} • ${firstOrder.items.length} item(s)',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onView,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('VIEW DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFDC2626),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFFDC2626)),
                      SizedBox(width: 6),
                      Text('ACCEPT NOW', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ====================================================
// COMPANY ANNOUNCEMENT & BANNER CAROUSEL
// ====================================================
class _RetailerBannerCarousel extends StatefulWidget {
  const _RetailerBannerCarousel();

  @override
  State<_RetailerBannerCarousel> createState() => _RetailerBannerCarouselState();
}

class _RetailerBannerCarouselState extends State<_RetailerBannerCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _banners = [
    {
      'title': 'Kitchen Speed Master Bonus ⚡',
      'subtitle': 'Pack orders in < 12 mins • Earn ₹600 Daily Bonus for Kitchen Staff',
      'badge': 'STAFF INCENTIVE',
      'icon': Icons.timer_outlined,
      'gradient': [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF059669)],
      'cta': 'View Target',
      'details': 'Complete 40 customer orders today with average preparation time under 12 minutes to receive an instant ₹600 cash incentive credited directly to your staff payout wallet.',
      'terms': ['Must maintain < 12 min average prep time', 'Zero packaging tampering complaints', 'Calculated automatically on daily cutoff at 11:59 PM'],
    },
    {
      'title': 'Dinner Rush Surge Boost 🔥',
      'subtitle': 'Active 8:00 PM – 11:00 PM • +₹15 Extra Partner Payout per order',
      'badge': 'LIVE SURGE',
      'icon': Icons.local_fire_department_rounded,
      'gradient': [Color(0xFF7C2D12), Color(0xFFC2410C), Color(0xFFEA580C)],
      'cta': 'Boost Menu',
      'details': 'High demand forecasted across Indiranagar & Koramangala. Keep fast-moving inventory in stock to maximize dinner surge payouts.',
      'terms': ['Applicable on all orders placed between 8:00 PM and 11:00 PM', 'No minimum order value required', 'Bonus added automatically to daily settlement'],
    },
    {
      'title': 'Zero Cancellation Milestone 🛡️',
      'subtitle': '100% fulfill orders this week • Unlock ₹1,500 Store Bonus',
      'badge': 'WEEKLY TARGET',
      'icon': Icons.military_tech_rounded,
      'gradient': [Color(0xFF312E81), Color(0xFF4338CA), Color(0xFF6366F1)],
      'cta': 'Check Progress',
      'details': 'Fulfill all customer orders without any merchant-side cancellation for 7 consecutive days to earn an exclusive 5-star restaurant badge and ₹1,500 bonus.',
      'terms': ['0 merchant-initiated cancellations allowed', 'Customer ratings must average >= 4.5 stars', 'Credited on weekly payout cycle every Monday'],
    },
    {
      'title': 'Company Packaging SOP 2026 📋',
      'subtitle': 'Official guidelines for leak-proof hot food sealing & eco bags',
      'badge': 'COMPANY DIRECTIVE',
      'icon': Icons.verified_user_outlined,
      'gradient': [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
      'cta': 'Read SOP',
      'details': 'Adhere to Quick Mart 2026 quality packaging standards: double-tape liquid items, apply tamper-proof security seal, and attach itemized receipt on bag exterior.',
      'terms': ['Mandatory for all FSSAI registered partner kitchens', 'Random audits conducted by QA team weekly', 'Free branded seal rolls available on store portal'],
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showBannerModal(BuildContext context, Map<String, dynamic> banner) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final List<Color> gradientColors = banner['gradient'] as List<Color>;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Modal Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          banner['badge'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        banner['title'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  banner['details'] as String,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                ),
                const SizedBox(height: 14),

                const Text(
                  'Key Guidelines & Rules:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                ...((banner['terms'] as List<String>).map((t) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              t,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ))),
                const SizedBox(height: 20),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${banner['title']} guidelines acknowledged for kitchen staff!'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'ACKNOWLEDGE & ACTIVATE',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 124,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            itemCount: _banners.length,
            itemBuilder: (context, index) {
              final b = _banners[index];
              final List<Color> gradientColors = b['gradient'] as List<Color>;

              return InkWell(
                onTap: () => _showBannerModal(context, b),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors.last.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                b['badge'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              b['title'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              b['subtitle'] as String,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          b['icon'] as IconData,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Dot Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _banners.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentPage == index ? 16 : 6,
              height: 5,
              decoration: BoxDecoration(
                color: _currentPage == index ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ====================================================
// COMPANY OFFERS & RESTAURANT WORKER INCENTIVES HUB
// ====================================================
class _CompanyOffersSection extends StatelessWidget {
  const _CompanyOffersSection();

  void _showOfferModal(BuildContext context, Map<String, dynamic> offer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (offer['color'] as Color).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(offer['icon'] as IconData, color: offer['color'] as Color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offer['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            offer['reward'] as String,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: offer['color'] as Color),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  offer['description'] as String,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: Color(0xFF64748B), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Offer Validity: ${offer['validity']}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${offer['title']} activated for restaurant staff!'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'ACTIVATE SCHEME',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final offers = [
      {
        'title': 'Kitchen Speed Target',
        'subtitle': '32 / 40 orders packed (< 12 min avg)',
        'reward': '₹600 Instant Payout',
        'progress': 0.80,
        'progressText': '80% Achieved',
        'icon': Icons.flash_on_rounded,
        'color': const Color(0xFF059669),
        'validity': 'Today until 11:59 PM',
        'description': 'Speed Packing Challenge: Pack 40 orders under 12 minutes to earn a direct ₹600 cash reward distributed to kitchen packaging staff.',
      },
      {
        'title': 'Weekend Peak Multiplier',
        'subtitle': 'Friday to Sunday Dinner Surge (08:00 PM)',
        'reward': '1.5x Payout / +₹15/Order',
        'progress': 0.50,
        'progressText': 'Active Tonight',
        'icon': Icons.local_fire_department_rounded,
        'color': const Color(0xFFEA580C),
        'validity': '08:00 PM – 11:00 PM',
        'description': 'Company sponsored weekend peak-hour bonus for active kitchen lines to handle heavy dinner rush demand.',
      },
      {
        'title': 'FSSAI Clean Kitchen Bonus',
        'subtitle': 'Monthly compliance score: 98%',
        'reward': '₹1,000 Staff Credit',
        'progress': 0.98,
        'progressText': 'Verified & Claimable',
        'icon': Icons.verified_rounded,
        'color': const Color(0xFF2563EB),
        'validity': 'Monthly cycle ending 31st',
        'description': 'Awarded for maintaining 100% compliance with government food safety, hygiene hairnets, and sealed packaging checks.',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COMPANY OFFERS & STAFF BONUSES',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.6,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Live company targets & incentives for kitchen workers',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Offer Cards
          ...offers.map((offer) {
            final color = offer['color'] as Color;
            final progress = offer['progress'] as double;

            return InkWell(
              onTap: () => _showOfferModal(context, offer),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(offer['icon'] as IconData, color: color, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            offer['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              offer['reward'] as String,
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: color),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      offer['subtitle'] as String,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),

                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            offer['progressText'] as String,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Tap for details →',
                          style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _OrderPartnerCard extends StatelessWidget {
  final OrderEntity order;
  const _OrderPartnerCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final statusColor = order.status.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: InkWell(
        onTap: () => RetailerOrderDetailsSheet.show(context, order: order),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header: Order ID, Timestamp & Status Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
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
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.touch_app_outlined, size: 14, color: Color(0xFF64748B)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.createdAt.toLocal().toString().split('.')[0],
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      order.status.label.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 9.5, letterSpacing: 0.4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 18),
                ],
              ),
            ),

            // 2. Customer & Delivery Location Row
            if (order.customerName.isNotEmpty || order.deliveryAddress.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Row(
                  children: [
                    const Icon(Icons.person_pin_circle_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        order.customerName.isNotEmpty ? order.customerName : 'Customer',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (order.deliveryAddress.isNotEmpty) ...[
                      const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          order.deliveryAddress,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // 3. Items Checklist
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ITEMS TO PACK:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: AppColors.textSecondary, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  ...order.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('${item.quantity}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF0F172A))),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.nameSnapshot,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('₹${(item.priceSnapshot * item.quantity).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                          ],
                        ),
                      )),
                  const Divider(height: 18),

                  // Responsive Grand Total & Delivery OTP row
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Text(
                        'Total: ₹${order.grandTotal.toStringAsFixed(0)} (${order.paymentMethod})',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 4. Status-specific action buttons or informative banners
            if (order.status == OrderStatus.placed)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => RetailerRejectDialog.show(context, order: order),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFDC2626)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('REJECT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          context.read<RetailerBloc>().add(AcceptOrderEvent(order.id));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('ACCEPT ORDER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              )
            else if (order.status == OrderStatus.accepted)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.kitchen, size: 16, color: Colors.white),
                    label: const Text('START PACKING / PREPARING', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white)),
                    onPressed: () {
                      context.read<RetailerBloc>().add(MarkPreparingEvent(order.id));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              )
            else if (order.status == OrderStatus.preparing)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                    label: const Text('READY FOR DRIVER PICKUP', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white)),
                    onPressed: () {
                      context.read<RetailerBloc>().add(MarkReadyForPickupEvent(order.id));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              )
            else if (order.status == OrderStatus.readyForPickup)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.inventory_2_rounded, size: 18, color: Color(0xFF059669)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Food packed & ready • Waiting for delivery partner to arrive',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                      ),
                    ),
                  ],
                ),
              )
            else if (order.status == OrderStatus.assigned || order.status == OrderStatus.pickedUp || order.status == OrderStatus.outForDelivery)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.delivery_dining_rounded, size: 18, color: Color(0xFF1D4ED8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.status == OrderStatus.pickedUp || order.status == OrderStatus.outForDelivery
                            ? (order.deliveryPartnerName != null && order.deliveryPartnerName!.isNotEmpty
                                ? 'Picked up by ${order.deliveryPartnerName} • En route to customer'
                                : 'Order picked up • Out for delivery to customer')
                            : (order.deliveryPartnerName != null && order.deliveryPartnerName!.isNotEmpty
                                ? 'Driver ${order.deliveryPartnerName} assigned • Arriving at store'
                                : 'Delivery partner assigned • Arriving for pickup'),
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                      ),
                    ),
                  ],
                ),
              )
            else if (order.status == OrderStatus.delivered)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.task_alt_rounded, size: 18, color: Color(0xFF10B981)),
                    SizedBox(width: 8),
                    Text(
                      'Delivered Successfully to Customer ✨',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              )
            else if (order.status == OrderStatus.cancelled || order.status == OrderStatus.rejected)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.cancel_rounded, size: 18, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Order Cancelled / Rejected',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                          ),
                          if (order.rejectionReason != null && order.rejectionReason!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Reason: ${order.rejectionReason}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ====================================================
// 2. INVENTORY & STOCKS TAB (SEARCH, CATEGORY FILTERS & CRUD)
// ====================================================
class _RetailerInventoryTab extends StatefulWidget {
  const _RetailerInventoryTab();

  @override
  State<_RetailerInventoryTab> createState() => _RetailerInventoryTabState();
}

class _RetailerInventoryTabState extends State<_RetailerInventoryTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all';

  final List<Map<String, String>> _categories = const [
    {'id': 'all', 'name': 'All Items'},
    {'id': 'Grocery', 'name': 'Grocery & Staples'},
    {'id': 'Dairy', 'name': 'Dairy & Eggs'},
    {'id': 'Fruits & Vegetables', 'name': 'Vegetables & Fruits'},
    {'id': 'Bakery', 'name': 'Bakery & Bread'},
    {'id': 'Beverages', 'name': 'Beverages & Drinks'},
    {'id': 'snacks', 'name': 'Snacks & Munchies'},
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static String _getDefaultProductImageForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'fruits':
      case 'vegetables':
      case 'vegetables & fruits':
      case 'fruits & vegetables':
        return 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=500';
      case 'dairy':
      case 'dairy & eggs':
      case 'dairy & breakfast':
        return 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500';
      case 'snacks':
      case 'snacks & munchies':
      case 'instant food':
      case 'munchies':
        return 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=500';
      case 'beverages':
      case 'beverages & drinks':
      case 'cold drinks':
        return 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=500';
      case 'bakery':
      case 'bakery & bread':
        return 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=500';
      default:
        return 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=500';
    }
  }

  Widget _buildProductThumbnail(ProductEntity product) {
    final rawUrl = product.imageUrl.trim();
    if (rawUrl.isEmpty) {
      return Container(
        key: ValueKey('empty_${product.id}'),
        width: 60,
        height: 60,
        color: const Color(0xFFF1F5F9),
        child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF94A3B8)),
      );
    }

    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return CachedNetworkImage(
        key: ValueKey('net_${product.id}_$rawUrl'),
        imageUrl: ImageUrlHelper.optimize(rawUrl, width: 160, height: 160),
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        memCacheWidth: 160,
        memCacheHeight: 160,
        placeholder: (context, url) => Container(
          width: 60,
          height: 60,
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: 60,
          height: 60,
          color: const Color(0xFFF1F5F9),
          child: const Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8)),
        ),
      );
    }

    // Local file path (e.g. from camera/gallery before server upload completes or cached local file)
    try {
      final cleanPath = rawUrl.startsWith('file://') ? rawUrl.replaceFirst('file://', '') : rawUrl;
      final file = File(cleanPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          key: ValueKey('file_${product.id}_$cleanPath'),
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 60,
            height: 60,
            color: const Color(0xFFF1F5F9),
            child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF94A3B8)),
          ),
        );
      }
    } catch (_) {}

    return Container(
      key: ValueKey('fallback_${product.id}'),
      width: 60,
      height: 60,
      color: const Color(0xFFF1F5F9),
      child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF94A3B8)),
    );
  }


  void _handleBarcodeScanResult(String scannedBarcode) {
    final retailerState = context.read<RetailerBloc>().state;
    final cleanCode = scannedBarcode.trim();

    // Look up in store's loaded products by barcode or ID
    ProductEntity? matched;
    for (final p in retailerState.storeProducts) {
      if ((p.barcode != null && p.barcode!.trim() == cleanCode) ||
          p.id.trim().toLowerCase() == cleanCode.toLowerCase() ||
          p.name.trim().toLowerCase() == cleanCode.toLowerCase()) {
        matched = p;
        break;
      }
    }

    if (matched != null) {
      _showQuickBarcodeStockSheet(context, matched, cleanCode);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Barcode $cleanCode detected! Fill details to add it.',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2563EB),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
      _showAddProductModal(context, initialBarcode: cleanCode);
    }
  }

  void _showQuickBarcodeStockSheet(BuildContext context, ProductEntity product, String barcode) {
    int stockCount = product.stock;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                left: 20,
                right: 20,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4.5,
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF10B981), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Item Found by Barcode',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  // Product Preview Card
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildProductThumbnail(product),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${product.price.toStringAsFixed(0)} / ${product.unit}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF059669)),
                              ),
                              Text(
                                'Code: $barcode',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Stock Stepper Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Available Stock Units', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: stockCount > 0 ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                stockCount > 0 ? 'In Stock' : 'Out of Stock',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: stockCount > 0 ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: stockCount > 0
                                  ? () {
                                      setSheetState(() => stockCount--);
                                      HapticFeedback.selectionClick();
                                    }
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444), size: 30),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              constraints: const BoxConstraints(minWidth: 84),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                              ),
                              child: Text(
                                '$stockCount',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              onPressed: () {
                                setSheetState(() => stockCount++);
                                HapticFeedback.selectionClick();
                              },
                              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF10B981), size: 30),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Quick Increment Chips (+5, +10, +25, +50)
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [5, 10, 25, 50].map((inc) {
                            return ActionChip(
                              label: Text('+$inc', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              onPressed: () {
                                setSheetState(() => stockCount += inc);
                                HapticFeedback.selectionClick();
                              },
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        final updated = product.copyWith(
                          stock: stockCount,
                          isAvailable: stockCount > 0,
                          barcode: barcode,
                        );
                        context.read<RetailerBloc>().add(UpdateProductInInventoryEvent(updated));
                        HapticFeedback.lightImpact();
                      },
                      child: const Text(
                        'SAVE STOCK UPDATE',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
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

  void _showAddProductModal(BuildContext context, {String? initialBarcode}) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final mrpCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'piece');
    final stockCtrl = TextEditingController(text: '0');
    final hsnCtrl = TextEditingController();
    final taxCtrl = TextEditingController();
    final barcodeCtrl = TextEditingController(text: initialBarcode ?? '');
    final imageCtrl = TextEditingController(text: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400');
    String selectedCategory = 'Grocery';
    bool isVeg = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(modalCtx).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.add_box_rounded, color: Color(0xFF10B981), size: 24),
                        const SizedBox(width: 8),
                        const Text('Add New Item / Dish', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 10),

                    if (initialBarcode != null && initialBarcode.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.qr_code_2_rounded, size: 18, color: Color(0xFF10B981)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Scanned Barcode: $initialBarcode',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF065F46)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Item Name
                    const Text('Item / Dish Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Special Butter Chicken Bowl',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Category & Dietary Tag
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Category *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedCategory,
                                    isExpanded: true,
                                    items: _categories
                                        .where((c) => c['id'] != 'all')
                                        .map((c) => DropdownMenuItem(value: c['id']!, child: Text(c['name']!, style: const TextStyle(fontSize: 12))))
                                        .toList(),
                                    onChanged: (v) => setModalState(() => selectedCategory = v!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Dietary Tag', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () => setModalState(() => isVeg = !isVeg),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                  decoration: BoxDecoration(
                                    color: isVeg ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isVeg ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.circle, size: 10, color: isVeg ? Colors.green : Colors.red),
                                      const SizedBox(width: 6),
                                      Text(isVeg ? 'VEG' : 'NON-VEG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isVeg ? Colors.green : Colors.red)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Pricing (MRP vs Selling) & Unit
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Selling Price (₹) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: priceCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'e.g. 199',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('MRP Price (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: mrpCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'e.g. 249',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Unit / Size *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: unitCtrl,
                                decoration: InputDecoration(
                                  hintText: 'piece, kg, pack',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Initial Stock Quantity
                    const Text('Initial Stock Units *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'e.g. 50',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // HSN Code & GST Tax % (Section 5 Backend Sync)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('HSN Code (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: hsnCtrl,
                                decoration: InputDecoration(
                                  hintText: 'e.g. 1001',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tax % (0 to 28)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: taxCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  hintText: 'e.g. 5 or 18',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Responsive Product Image Upload Picker
                    RetailerProductImagePicker(
                      initialImageUrl: imageCtrl.text,
                      onImageChanged: (newImg) {
                        setModalState(() {
                          imageCtrl.text = newImg;
                        });
                      },
                    ),
                    const SizedBox(height: 18),

                    // Add Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          final price = double.tryParse(priceCtrl.text.trim());
                          final mrp = double.tryParse(mrpCtrl.text.trim()) ?? (price != null ? price + 40 : 0.0);
                          final stock = int.tryParse(stockCtrl.text.trim()) ?? 0;
                          final hsn = hsnCtrl.text.trim();
                          final taxRaw = taxCtrl.text.trim();
                          final taxVal = taxRaw.isNotEmpty ? double.tryParse(taxRaw)?.clamp(0.0, 28.0) : null;

                          if (name.isEmpty || price == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter item name and price')),
                            );
                            return;
                          }

                          if (price <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Item price must be greater than zero')),
                            );
                            return;
                          }

                          if (mrp < price) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('MRP cannot be less than selling price')),
                            );
                            return;
                          }

                          if (stock < 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid stock quantity (0 or more)')),
                            );
                            return;
                          }

                          final enteredImage = imageCtrl.text.trim();
                          if (enteredImage.isNotEmpty && !enteredImage.startsWith('https://')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Product image URL must start with https://')),
                            );
                            return;
                          }

                          final retailerState = context.read<RetailerBloc>().state;
                          final activeStoreId = (retailerState.profile?.id != null && retailerState.profile!.id.isNotEmpty)
                              ? retailerState.profile!.id
                              : (retailerState.storeProducts.isNotEmpty
                                  ? retailerState.storeProducts.first.storeId
                                  : '');

                          if (activeStoreId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Store profile not loaded. Please try again.'),
                                backgroundColor: Color(0xFFEF4444),
                              ),
                            );
                            return;
                          }

                          final finalImageUrl = enteredImage.isNotEmpty
                              ? enteredImage
                              : _getDefaultProductImageForCategory(selectedCategory);

                          final newProduct = ProductEntity(
                            id: 'prod_${DateTime.now().millisecondsSinceEpoch}',
                            storeId: activeStoreId,
                            categoryId: selectedCategory,
                            name: name,
                            description: 'Fresh item from store inventory.',
                            price: price,
                            originalPrice: mrp,
                            unit: unitCtrl.text.trim().isEmpty ? 'piece' : unitCtrl.text.trim(),
                            stock: stock,
                            isAvailable: true,
                            imageUrl: finalImageUrl,
                            barcode: barcodeCtrl.text.trim().isEmpty ? null : barcodeCtrl.text.trim(),
                            hsnCode: hsn.isNotEmpty ? hsn : null,
                            taxPercent: taxVal,
                          );

                          Navigator.pop(ctx);
                          context.read<RetailerBloc>().add(AddProductToInventoryEvent(newProduct));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('ADD ITEM TO STOCKS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditProductModal(BuildContext context, ProductEntity product) {
    final nameCtrl = TextEditingController(text: product.name);
    final priceCtrl = TextEditingController(text: product.price.toStringAsFixed(0));
    final mrpCtrl = TextEditingController(text: (product.originalPrice ?? (product.price + 30)).toStringAsFixed(0));
    final unitCtrl = TextEditingController(text: product.unit);
    final stockCtrl = TextEditingController(text: product.stock.toString());
    final imageCtrl = TextEditingController(text: product.imageUrl);
    String selectedCategory = product.categoryId;
    bool isAvailable = product.isAvailable;

    if (!_categories.any((c) => c['id'] == selectedCategory)) {
      selectedCategory = 'Grocery';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(modalCtx).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 26),
                        const SizedBox(width: 8),
                        const Text('Edit Item & Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 10),

                    // Item Name
                    const Text('Item / Dish Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Category & In-Stock Status
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Category *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedCategory,
                                    isExpanded: true,
                                    items: _categories
                                        .where((c) => c['id'] != 'all')
                                        .map((c) => DropdownMenuItem(value: c['id']!, child: Text(c['name']!, style: const TextStyle(fontSize: 12))))
                                        .toList(),
                                    onChanged: (v) => setModalState(() => selectedCategory = v!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Stock Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () => setModalState(() => isAvailable = !isAvailable),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                  decoration: BoxDecoration(
                                    color: isAvailable ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isAvailable ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.circle, size: 10, color: isAvailable ? Colors.green : Colors.red),
                                      const SizedBox(width: 6),
                                      Text(isAvailable ? 'IN STOCK' : 'OUT STOCK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isAvailable ? Colors.green : Colors.red)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Pricing (Selling vs MRP) & Unit
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Selling Price (₹) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: priceCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('MRP Price (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: mrpCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Unit / Size *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: unitCtrl,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Stock Count Units
                    const Text('Available Stock Units', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Responsive Product Image Upload Picker
                    RetailerProductImagePicker(
                      initialImageUrl: imageCtrl.text,
                      label: 'Update Product / Dish Image',
                      onImageChanged: (newImg) {
                        setModalState(() {
                          imageCtrl.text = newImg;
                        });
                      },
                    ),
                    const SizedBox(height: 18),

                    // Actions: Update & Delete
                    Row(
                      children: [
                        // Delete Button
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmDeleteProductDialog(context, product);
                          },
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                          label: const Text('DELETE', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Save Changes Button
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: () {
                                final name = nameCtrl.text.trim();
                                final price = double.tryParse(priceCtrl.text.trim());
                                final mrp = double.tryParse(mrpCtrl.text.trim());
                                final stock = int.tryParse(stockCtrl.text.trim()) ?? product.stock;
                                final effectiveStock = isAvailable ? (stock > 0 ? stock : 10) : 0;

                                if (name.isEmpty || price == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter valid name and price')),
                                  );
                                  return;
                                }

                                if (price <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Item price must be greater than zero')),
                                  );
                                  return;
                                }

                                if (mrp != null && mrp < price) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('MRP cannot be less than selling price')),
                                  );
                                  return;
                                }

                                if (stock < 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a valid stock quantity (0 or more)')),
                                  );
                                  return;
                                }

                                final editedImg = imageCtrl.text.trim();
                                if (editedImg.isNotEmpty && !editedImg.startsWith('https://')) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Product image URL must start with https://')),
                                  );
                                  return;
                                }

                                final updatedProduct = product.copyWith(
                                  name: name,
                                  categoryId: selectedCategory,
                                  price: price,
                                  originalPrice: mrp,
                                  unit: unitCtrl.text.trim().isEmpty ? product.unit : unitCtrl.text.trim(),
                                  stock: effectiveStock,
                                  isAvailable: isAvailable,
                                  imageUrl: imageCtrl.text.trim().isEmpty ? product.imageUrl : imageCtrl.text.trim(),
                                );

                                Navigator.pop(ctx);
                                context.read<RetailerBloc>().add(UpdateProductInInventoryEvent(updatedProduct));
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteProductDialog(BuildContext context, ProductEntity product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Delete Item?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently remove "${product.name}" from your store stocks and catalog?',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<RetailerBloc>().add(DeleteProductFromInventoryEvent(product.id, productName: product.name));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('DELETE ITEM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF10B981),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('ADD NEW ITEM', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        onPressed: () => _showAddProductModal(context),
      ),
      body: BlocBuilder<RetailerBloc, RetailerState>(
        builder: (context, state) {
          if (state.isLoading && state.storeProducts.isEmpty) {
            return const RetailerInventorySkeleton();
          }

          if (state.failureType != FailureType.none && state.storeProducts.isEmpty) {
            return NetworkAndServerErrorView(
              failureType: state.failureType,
              customMessage: state.errorMessage,
              isRetrying: state.isLoading,
              onRetry: () {
                final storeId = state.profile?.id ?? '';
                context.read<RetailerBloc>().add(LoadRetailerDataEvent(storeId: storeId));
              },
            );
          }

          // Filter by search query and category
          final filteredProducts = state.storeProducts.where((p) {
            final matchesQuery = _searchQuery.isEmpty ||
                p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                p.description.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchesCategory = _selectedCategory == 'all' || p.categoryId == _selectedCategory;
            return matchesQuery && matchesCategory;
          }).toList();

          return Column(
            children: [
              // 1. Search Bar & Filter Bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Store Inventory (${state.storeProducts.length})',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => RetailerBarcodeScannerSheet.show(
                            context,
                            onBarcodeScanned: _handleBarcodeScanResult,
                          ),
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Color(0xFF10B981)),
                          label: const Text(
                            'Scan Barcode',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF10B981)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showAddProductModal(context),
                          icon: const Icon(Icons.add, size: 16, color: Colors.white),
                          label: const Text(
                            'Add Item',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search products, items, units...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                            IconButton(
                              tooltip: 'Scan Barcode',
                              icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF10B981), size: 20),
                              onPressed: () => RetailerBarcodeScannerSheet.show(
                                context,
                                onBarcodeScanned: _handleBarcodeScanResult,
                              ),
                            ),
                          ],
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Category Filter Pills
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: _categories.map((c) {
                          final isSelected = _selectedCategory == c['id'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(c['name']!),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _selectedCategory = c['id']!),
                              selectedColor: const Color(0xFF10B981),
                              backgroundColor: const Color(0xFFF1F5F9),
                              labelStyle: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF475569),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              showCheckmark: false,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Products List or Empty View
              Expanded(
                child: filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty || _selectedCategory != 'all'
                                  ? 'No items matching your search'
                                  : 'No products in catalog yet',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 12),
                            if (_searchQuery.isNotEmpty || _selectedCategory != 'all')
                              TextButton(
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _selectedCategory = 'all';
                                  });
                                },
                                child: const Text('Clear Filters', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                              )
                            else
                              ElevatedButton(
                                onPressed: () => _showAddProductModal(context),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                                child: const Text('+ Add First Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: filteredProducts.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final product = filteredProducts[idx];
                          final isVeg = !product.name.toLowerCase().contains('chicken') &&
                              !product.name.toLowerCase().contains('egg') &&
                              !product.name.toLowerCase().contains('mutton') &&
                              !product.name.toLowerCase().contains('fish') &&
                              !product.name.toLowerCase().contains('meat');

                          return InkWell(
                            onTap: () => _showEditProductModal(context, product),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: _buildProductThumbnail(product),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 12,
                                                  height: 12,
                                                  padding: const EdgeInsets.all(1.5),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(color: isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626), width: 1.2),
                                                    borderRadius: BorderRadius.circular(2.5),
                                                  ),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    product.name,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A), height: 1.2),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              product.originalPrice != null
                                                  ? '${product.unit}  •  ₹${product.price.toStringAsFixed(0)} (MRP ₹${product.originalPrice!.toStringAsFixed(0)})'
                                                  : '${product.unit}  •  ₹${product.price.toStringAsFixed(0)}',
                                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                InkWell(
                                                  borderRadius: BorderRadius.circular(6),
                                                  onTap: () {
                                                    final nextState = !product.isAvailable;
                                                    context.read<RetailerBloc>().add(ToggleProductStockEvent(
                                                      product.id,
                                                      nextState,
                                                      currentStock: product.stock,
                                                    ));
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: product.isAvailable ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: product.isAvailable ? const Color(0xFF10B981) : const Color(0xFFEF4444), width: 0.8),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.circle, size: 6, color: product.isAvailable ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          product.isAvailable ? 'In Stock' : 'Out of Stock',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: product.isAvailable ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Edit & Delete Icons
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 19),
                                        tooltip: 'Edit Item',
                                        onPressed: () => _showEditProductModal(context, product),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 19),
                                        tooltip: 'Delete Item',
                                        onPressed: () => _confirmDeleteProductDialog(context, product),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 16, color: Color(0xFFF1F5F9)),

                                  // Quick Stock Quantity Stepper Bar
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Stock Count: ${product.stock} units',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                      ),
                                      Row(
                                        children: [
                                          InkWell(
                                            onTap: product.stock <= 0
                                                ? null
                                                : () {
                                                    final newStock = (product.stock - 5).clamp(0, 99999);
                                                    final updated = product.copyWith(stock: newStock, isAvailable: newStock > 0);
                                                    context.read<RetailerBloc>().add(UpdateProductInInventoryEvent(updated));
                                                  },
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                              ),
                                              child: const Text('-5', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF0F172A))),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          InkWell(
                                            onTap: () {
                                              final newStock = (product.stock + 5).clamp(0, 99999);
                                              final updated = product.copyWith(stock: newStock, isAvailable: true);
                                              context.read<RetailerBloc>().add(UpdateProductInInventoryEvent(updated));
                                            },
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFD1FAE5),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFF10B981)),
                                              ),
                                              child: const Text('+5', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF065F46))),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ====================================================
// 3. SETTLEMENTS & PAYMENTS FINANCIALS TAB
// ====================================================
class _RetailerFinancialsTab extends StatefulWidget {
  const _RetailerFinancialsTab();

  @override
  State<_RetailerFinancialsTab> createState() => _RetailerFinancialsTabState();
}

class _RetailerFinancialsTabState extends State<_RetailerFinancialsTab> {
  String _selectedPeriod = 'today';

  void _showUpdateBankAccountModal(BuildContext context, RetailerBankAccountEntity? currentBank) {
    final holderCtrl = TextEditingController(text: currentBank?.holderName ?? '');
    final bankCtrl = TextEditingController(text: currentBank?.bankName ?? '');
    final accCtrl = TextEditingController();
    final confirmAccCtrl = TextEditingController();
    final ifscCtrl = TextEditingController(text: currentBank?.ifscCode ?? '');
    final formKey = GlobalKey<FormState>();

    final String? currentMaskedAccount = (currentBank != null && currentBank.accountNumber.isNotEmpty)
        ? (currentBank.accountNumber.length > 4
            ? '•••• •••• ${currentBank.accountNumber.substring(currentBank.accountNumber.length - 4)}'
            : '•••• ••••')
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.account_balance, color: Color(0xFF0F172A), size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Update Bank Account',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  if (currentMaskedAccount != null) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Text(
                            'Active Linked Account: $currentMaskedAccount',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Text(
                    'Daily payouts will be credited directly to this verified account.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: holderCtrl,
                    decoration: InputDecoration(
                      labelText: 'Account Holder Name',
                      hintText: 'e.g. Ramesh Kumar',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Holder name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: bankCtrl,
                    decoration: InputDecoration(
                      labelText: 'Bank Name',
                      hintText: 'e.g. HDFC Bank',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.account_balance_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Bank name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: accCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'New Account Number',
                      hintText: 'Enter new account number',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.numbers),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Account number is required';
                      if (v.trim().length < 8) return 'Enter a valid account number (at least 8 digits)';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmAccCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Confirm Account Number',
                      hintText: 'Re-enter account number',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.check_circle_outline),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please confirm account number';
                      if (v.trim() != accCtrl.text.trim()) return 'Account numbers do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: ifscCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'IFSC Code',
                      hintText: 'e.g. HDFC0001234',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.pin_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'IFSC code is required';
                      if (v.trim().length != 11) return 'IFSC code must be 11 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (formKey.currentState?.validate() == true) {
                          final newAcc = accCtrl.text.trim();
                          final last4 = newAcc.length >= 4 ? newAcc.substring(newAcc.length - 4) : newAcc;
                          showDialog(
                            context: ctx,
                            builder: (confirmCtx) => AlertDialog(
                              title: const Text('Confirm Settlement Account'),
                              content: Text(
                                'Are you sure you want to update your payout bank account to ${bankCtrl.text.trim()} ending in •••• $last4? All future payouts will be routed to this account.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(confirmCtx),
                                  child: const Text('CANCEL'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(confirmCtx);
                                    context.read<RetailerBloc>().add(
                                      UpdateRetailerBankAccountEvent({
                                        'holderName': holderCtrl.text.trim(),
                                        'bankName': bankCtrl.text.trim(),
                                        'accountNumber': newAcc,
                                        'ifscCode': ifscCtrl.text.trim().toUpperCase(),
                                      }),
                                    );
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Bank account submitted for verification.'),
                                        backgroundColor: Color(0xFF10B981),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                                  child: const Text('CONFIRM UPDATE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      child: const Text('Save Bank Details', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showInstantPayoutModal(BuildContext context, double netPayout, RetailerStoreProfileEntity? profile) {
    const impsFee = 5.0;
    final netTransfer = (netPayout - impsFee).clamp(0.0, double.infinity);
    final upiId = 'freshmart@okhdfcbank';
    final bankInfo = 'HDFC Bank (A/C •••• 5012)';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewPadding.bottom;
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(ctx).size.height * 0.90,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.bolt, color: Colors.orange, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Express Instant Payout',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Direct IMPS 24x7 Settlement',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Amount breakdown container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text('Available Earnings', style: TextStyle(fontSize: 13, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              Text('₹${netPayout.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text('IMPS Instant Transfer Fee', style: TextStyle(fontSize: 13, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              SizedBox(width: 8),
                              Text('₹5.00', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange)),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Net Credit to Bank/UPI',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '₹${netTransfer.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Destination Info
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Payout Destination (Verified)',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$bankInfo • $upiId',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF047857)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Confirm Action Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Instant Payout of ₹${netTransfer.toStringAsFixed(0)} successfully initiated to registered merchant account!',
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        },
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.flash_on, color: Colors.orangeAccent, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Confirm & Transfer Now',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildPeriodChips() {
    final periods = [
      ('today', 'Today'),
      ('thisWeek', 'This Week'),
      ('thisMonth', 'This Month'),
      ('lifetime', 'Lifetime'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: periods.map((p) {
          final isSelected = _selectedPeriod == p.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(p.$2),
              selected: isSelected,
              selectedColor: const Color(0xFF0F172A),
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF475569),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
              side: BorderSide(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
              onSelected: (_) {
                setState(() => _selectedPeriod = p.$1);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RetailerBloc, RetailerState>(
      builder: (context, state) {
        if (state.isLoading && state.dashboardStats == null && state.earningsSummary == null) {
          return const RetailerFinancialsSkeleton();
        }

        if (state.failureType != FailureType.none && state.dashboardStats == null && state.earningsSummary == null) {
          return NetworkAndServerErrorView(
            failureType: state.failureType,
            customMessage: state.errorMessage,
            isRetrying: state.isLoading,
            onRetry: () {
              final storeId = state.profile?.id ?? '';
              context.read<RetailerBloc>().add(LoadRetailerDataEvent(storeId: storeId));
            },
          );
        }

        final summary = state.earningsSummary;
        final periodData = _selectedPeriod == 'thisWeek'
            ? (summary?.thisWeek ?? const RetailerEarningsPeriodEntity())
            : _selectedPeriod == 'thisMonth'
                ? (summary?.thisMonth ?? const RetailerEarningsPeriodEntity())
                : _selectedPeriod == 'lifetime'
                    ? (summary?.lifetime ?? const RetailerEarningsPeriodEntity())
                    : (summary?.today ?? const RetailerEarningsPeriodEntity());

        final hasRealSummary = summary != null;
        final stats = state.dashboardStats;
        final netPayout = hasRealSummary ? periodData.netPayout : (stats?.netPayout ?? 0.0);
        final grossSales = hasRealSummary ? periodData.subtotal : (stats?.todayEarnings ?? 0.0);
        final platformFee = hasRealSummary ? periodData.platformFee : (stats?.commissionDeducted ?? 0.0);
        final ordersCount = hasRealSummary ? periodData.ordersCount : (stats?.completedOrders ?? state.completedOrders.length);
        final profile = state.profile;
        final bankAccount = state.bankAccount;
        final settlements = state.settlements;
        final isCompact = MediaQuery.of(context).size.width < 380;
        final horizontalPadding = isCompact ? 12.0 : 16.0;

        final periodLabel = _selectedPeriod == 'thisWeek'
            ? 'THIS WEEK'
            : _selectedPeriod == 'thisMonth'
                ? 'THIS MONTH'
                : _selectedPeriod == 'lifetime'
                    ? 'LIFETIME'
                    : "TODAY'S";

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Period Selector Chips
                  _buildPeriodChips(),
                  const SizedBox(height: 12),

                  // Earnings Header Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF064E3B), Color(0xFF047857)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF059669).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                "$periodLabel NET MERCHANT PAYOUT",
                                style: const TextStyle(
                                  color: Color(0xFFA7F3D0),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                                maxLines: 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.autorenew_rounded, color: Colors.white, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'Auto-Settling T+1',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '₹${netPayout.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Gross Sales: ₹${grossSales.toStringAsFixed(0)} ($ordersCount Orders)',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Platform Fee: -₹${platformFee.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Color(0xFFFCA5A5),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Express Instant Payout Action
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.bolt, color: Colors.orangeAccent, size: 20),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Request Express Instant Payout (₹${netPayout.toStringAsFixed(0)})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      onPressed: () => _showInstantPayoutModal(context, netPayout, profile),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Automated T+1 Settlement Cycle Timeline
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_repeat_rounded, size: 18, color: Color(0xFF059669)),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Automated Settlement Schedule',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'T+1 Active',
                                style: TextStyle(
                                  color: Color(0xFF15803D),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTimelineStep(
                                icon: Icons.check_circle_rounded,
                                iconColor: const Color(0xFF059669),
                                title: 'Cut-off',
                                subtitle: '11:59 PM',
                                isDone: true,
                              ),
                            ),
                            Container(width: 16, height: 2, color: const Color(0xFF059669)),
                            Expanded(
                              child: _buildTimelineStep(
                                icon: Icons.sync_rounded,
                                iconColor: Colors.orange,
                                title: 'Reconcile',
                                subtitle: '03:00 AM',
                                isDone: false,
                              ),
                            ),
                            Container(width: 16, height: 2, color: const Color(0xFFCBD5E1)),
                            Expanded(
                              child: _buildTimelineStep(
                                icon: Icons.account_balance_rounded,
                                iconColor: const Color(0xFF64748B),
                                title: 'Bank Credit',
                                subtitle: '06:00 AM',
                                isDone: false,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '100% automated settlement. Daily sales are deposited directly into your verified bank account without manual requests.',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bank & Settlement Destination (Spec R5)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Settlement Destination',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF059669)),
                        label: Text(
                          bankAccount != null && bankAccount.accountNumber.isNotEmpty ? 'Edit Details' : 'Add Account',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                        onPressed: () => _showUpdateBankAccountModal(context, bankAccount),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _FinancialRow(
                          label: 'Bank Account Status',
                          value: bankAccount?.verified == true
                              ? 'Verified'
                              : (bankAccount != null && bankAccount.accountNumber.isNotEmpty
                                  ? 'Verification Pending'
                                  : 'Not Added'),
                          icon: Icons.account_balance,
                          isGreen: bankAccount?.verified == true,
                          isOrange: bankAccount != null && !bankAccount.verified && bankAccount.accountNumber.isNotEmpty,
                        ),
                        const Divider(height: 18),
                        _FinancialRow(
                          label: 'Account Number',
                          value: bankAccount != null && bankAccount.accountNumber.isNotEmpty
                              ? (bankAccount.accountNumber.length > 4
                                  ? '•••• •••• ${bankAccount.accountNumber.substring(bankAccount.accountNumber.length - 4)}'
                                  : bankAccount.accountNumber)
                              : 'Not Provided',
                          icon: Icons.numbers,
                        ),
                        const Divider(height: 18),
                        _FinancialRow(
                          label: 'Bank & IFSC',
                          value: bankAccount != null && bankAccount.bankName.isNotEmpty
                              ? '${bankAccount.bankName} (${bankAccount.ifscCode})'
                              : 'Not Provided',
                          icon: Icons.domain,
                        ),
                        const Divider(height: 18),
                        _FinancialRow(
                          label: 'Beneficiary Name',
                          value: (bankAccount?.holderName.isNotEmpty == true)
                              ? bankAccount!.holderName
                              : (profile?.ownerName.isNotEmpty == true ? profile!.ownerName : 'Retailer Partner'),
                          icon: Icons.badge_outlined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Recent Payouts History (Spec R4)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Recent Settlements',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.download_rounded, size: 15, color: Color(0xFF059669)),
                        label: const Text(
                          'Statement',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Monthly Settlement Statement downloaded to device.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: settlements.isNotEmpty
                        ? ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: settlements.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final s = settlements[idx];
                              final isSettled = s.status == 'COMPLETED' || s.status == 'SETTLED';
                              final ref = s.paymentReference.isNotEmpty
                                  ? 'Ref: ${s.paymentReference}'
                                  : 'Daily T+1 Direct Payout';
                              final dateStr = '${s.createdAt.day.toString().padLeft(2, '0')}/${s.createdAt.month.toString().padLeft(2, '0')}/${s.createdAt.year}';
                              return _buildRecentSettlementItem(
                                date: dateStr,
                                utr: ref,
                                amount: '₹${s.amount.toStringAsFixed(2)}',
                                type: s.status,
                                isSuccess: isSettled,
                              );
                            },
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.history_toggle_off, color: Colors.grey.shade400, size: 36),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No settlements processed yet',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Daily T+1 settlements occur automatically every morning at 06:00 AM.',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  // Payout Support Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.help_outline_rounded, color: Color(0xFF047857), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Payout or Settlement Dispute?',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF065F46)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Reach our 24x7 Merchant Support team for payout queries.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF047857)),
                                ),
                              ],
                            ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              SupportTicketsScreen.route(app: 'retailer'),
                            );
                          },
                          child: const Text('Support', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDone,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textPrimary),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          subtitle,
          style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildRecentSettlementItem({
    required String date,
    required String utr,
    required String amount,
    required String type,
    required bool isSuccess,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSuccess ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isSuccess ? Icons.arrow_downward_rounded : Icons.hourglass_top_rounded,
              size: 16,
              color: isSuccess ? const Color(0xFF16A34A) : Colors.amber.shade800,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      amount,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        type,
                        style: const TextStyle(fontSize: 9.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$date • $utr',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isSuccess ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isSuccess ? 'SETTLED' : 'PROCESSING',
              style: TextStyle(
                color: isSuccess ? const Color(0xFF15803D) : Colors.amber.shade900,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinancialRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isGreen;
  final bool isOrange;

  const _FinancialRow({
    required this.label,
    required this.value,
    required this.icon,
    this.isGreen = false,
    this.isOrange = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: (isGreen ? const Color(0xFF10B981) : isOrange ? Colors.orange : const Color(0xFF64748B)).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isGreen ? const Color(0xFF059669) : isOrange ? Colors.orange : AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 2,
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isGreen ? const Color(0xFF059669) : isOrange ? Colors.orange : const Color(0xFF0F172A),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

// ====================================================
// 4. FSSAI & STORE PROFILE TAB
// ====================================================
class _RetailerProfileTab extends StatelessWidget {
  const _RetailerProfileTab();

  void _showCertificatePreview(BuildContext context, String title, String fileName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewPadding.bottom;
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(ctx).size.height * 0.90,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, 12, 20, 18 + bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.verified, color: Color(0xFF10B981), size: 22),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Color(0xFF0F172A),
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              const Text('Government & Legal Record', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(6)),
                          child: const Text('GOVT VERIFIED', style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold, fontSize: 10)),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                          onPressed: () => Navigator.pop(ctx),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.picture_as_pdf_rounded, size: 52, color: Colors.redAccent),
                          const SizedBox(height: 10),
                          Text(
                            fileName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                              height: 1.25,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          const Text('License: #11223344556677 • Validity: 31 Dec 2028', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit_document, color: Colors.white, size: 18),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Update / Re-upload Document', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const RetailerRegistrationScreen()));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RetailerBloc, RetailerState>(
      builder: (context, state) {
        if (state.isLoading && state.profile == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            ),
          );
        }

        if (state.failureType != FailureType.none && state.profile == null) {
          return NetworkAndServerErrorView(
            failureType: state.failureType,
            customMessage: state.errorMessage,
            isRetrying: state.isLoading,
            onRetry: () {
              final storeId = state.profile?.id ?? '';
              context.read<RetailerBloc>().add(LoadRetailerDataEvent(storeId: storeId));
            },
          );
        }

        final profile = state.profile;
        final storeName = profile?.storeName ?? 'Fresh Mart Essentials';
        final storeAddress = profile?.address ?? 'Dark Store & Supermarket • Indiranagar';
        final fssaiNumber = profile?.fssaiNumber ?? '11223344556677';
        final gstin = profile?.gstin ?? '29ABCDE1234F1Z5';
        final isVerified = profile?.isVerified ?? true;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Store Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/images/retailer_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            storeName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            storeAddress,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(isVerified ? Icons.verified : Icons.hourglass_top, color: isVerified ? const Color(0xFF34D399) : const Color(0xFFFBBF24), size: 14),
                              const SizedBox(width: 4),
                              Text(isVerified ? 'FSSAI & GST Certified' : 'Verification In Review', style: TextStyle(color: isVerified ? const Color(0xFF34D399) : const Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Onboard / Edit Registration Button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.app_registration, color: Colors.white, size: 18),
                  label: const Text('Edit Store & FSSAI Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RetailerRegistrationScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Store Membership & Subscription Plan
              const Text('Store Membership & Subscription Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              _RetailerMyPlanCard(subscription: state.subscription),
              const SizedBox(height: 20),

              // FSSAI Compliance Section
              const Text('Government & Legal Compliance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _ComplianceRow(label: 'FSSAI License No.', value: fssaiNumber, isVerified: isVerified),
                    const Divider(height: 16),
                    _ComplianceRow(
                      label: 'FSSAI Certificate',
                      value: 'FSSAI_Certificate_2026.pdf',
                      isFile: true,
                      onTap: () => _showCertificatePreview(context, 'FSSAI Food Safety Certificate', 'FSSAI_Certificate_2026.pdf'),
                    ),
                    const Divider(height: 16),
                    const _ComplianceRow(label: 'FSSAI Expiry', value: '31/12/2028', isVerified: true),
                    const Divider(height: 16),
                    _ComplianceRow(label: 'GSTIN', value: gstin, isVerified: isVerified),
                    const Divider(height: 16),
                    const _ComplianceRow(label: 'Business PAN', value: 'ABCDE1234F', isVerified: true),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Operating & Settlement Details
              const Text('Location & Bank Settlements', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const _ComplianceRow(label: 'Store Coordinates', value: '12.9716° N, 77.5946° E'),
                    const Divider(height: 16),
                    const _ComplianceRow(label: 'Operating Hours', value: '07:00 AM – 11:30 PM'),
                    const Divider(height: 16),
                    _ComplianceRow(label: 'Store Phone', value: profile?.phone.isNotEmpty == true ? profile!.phone : '9876543210'),
                    const Divider(height: 16),
                    _ComplianceRow(label: 'Store Email', value: profile?.email.isNotEmpty == true ? profile!.email : 'store@quickmart.com'),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              // Legal & Compliance
              const Text('Legal & Compliance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    ListTile(
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
                      leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF10B981)),
                      title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: const Text('Merchant data privacy & security', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF64748B)),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LegalPolicyScreen(initialTabIndex: 0)),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(14))),
                      leading: const Icon(Icons.description_outlined, color: Color(0xFF38BDF8)),
                      title: const Text('Terms and Conditions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: const Text('Store partner service agreement', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF64748B)),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LegalPolicyScreen(initialTabIndex: 1)),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              // Help & Partner Support
              const Text('Help & Partner Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.support_agent_rounded, color: Color(0xFF10B981), size: 22),
                      ),
                      title: const Text('24x7 Merchant & Partner Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: const Text('Chat with support, report order disputes or account issues', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF64748B)),
                      onTap: () {
                        Navigator.of(context).push(
                          SupportTicketsScreen.route(app: 'retailer'),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _ComplianceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isVerified;
  final bool isFile;
  final VoidCallback? onTap;

  const _ComplianceRow({
    required this.label,
    required this.value,
    this.isVerified = false,
    this.isFile = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rowContent = Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        if (isVerified) ...[
          const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 14),
          const SizedBox(width: 4),
        ],
        if (isFile) ...[
          const Icon(Icons.picture_as_pdf, color: Colors.red, size: 14),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isFile ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
              decoration: isFile ? TextDecoration.underline : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: rowContent,
        ),
      );
    }

    return rowContent;
  }
}

// ====================================================
// MY SUBSCRIPTION PLAN CARD & DETAILS MODAL
// ====================================================
class _RetailerMyPlanCard extends StatelessWidget {
  final RetailerSubscriptionEntity? subscription;

  const _RetailerMyPlanCard({this.subscription});

  void _showSubscriptionModal(BuildContext context) {
    SubscriptionRenewalSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final sub = subscription ?? RetailerSubscriptionEntity.freeTier;
    final isFree = sub.isFreeTier;
    final isExpired = sub.isExpired;
    final isTrial = sub.isTrial;
    final isTrialExpiringSoon = sub.isTrialExpiringSoon;

    String expiryText;
    if (isExpired) {
      expiryText = 'Subscription Expired';
    } else if (isTrial) {
      expiryText = sub.daysRemaining <= 1
          ? 'Trial ends today (${sub.daysRemaining}d)'
          : '${sub.daysRemaining} days left in trial';
    } else if (isFree) {
      expiryText = 'Lifetime Active (Free Tier)';
    } else if (sub.expiresAt != null) {
      final exp = sub.expiresAt!;
      expiryText = 'Renews: ${exp.day.toString().padLeft(2, '0')}/${exp.month.toString().padLeft(2, '0')}/${exp.year}';
    } else {
      expiryText = 'Active Plan';
    }

    final String statusLabel = isExpired
        ? 'EXPIRED'
        : (isTrialExpiringSoon
            ? 'TRIAL EXPIRING'
            : (isTrial ? 'FREE TRIAL' : (isFree ? 'FREE TIER' : 'ACTIVE')));

    final Color statusBg = isExpired
        ? const Color(0xFF991B1B)
        : (isTrialExpiringSoon
            ? const Color(0xFF9A3412)
            : (isTrial || isFree ? const Color(0xFF1E3A8A) : const Color(0xFF065F46)));

    final Color statusFg = isExpired
        ? const Color(0xFFFCA5A5)
        : (isTrialExpiringSoon
            ? const Color(0xFFFED7AA)
            : (isTrial || isFree ? const Color(0xFF93C5FD) : const Color(0xFFA7F3D0)));

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isExpired
              ? [const Color(0xFF450A0A), const Color(0xFF1F2937)]
              : isTrialExpiringSoon
                  ? [const Color(0xFF431407), const Color(0xFF1F2937)]
                  : isFree || isTrial
                      ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                      : [const Color(0xFF064E3B), const Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpired
              ? const Color(0xFFEF4444).withValues(alpha: 0.4)
              : isTrialExpiringSoon
                  ? const Color(0xFFF97316).withValues(alpha: 0.4)
                  : isFree || isTrial
                      ? const Color(0xFF334155)
                      : const Color(0xFF10B981).withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with Icon, Label, and Status Chip
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isExpired
                      ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                      : isTrialExpiringSoon
                          ? const Color(0xFFF97316).withValues(alpha: 0.2)
                          : isFree || isTrial
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                              : const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isExpired
                      ? Icons.error_outline_rounded
                      : isTrialExpiringSoon
                          ? Icons.timer_outlined
                          : isFree || isTrial
                              ? Icons.workspace_premium_outlined
                              : Icons.verified_rounded,
                  color: isExpired
                      ? const Color(0xFFF87171)
                      : isTrialExpiringSoon
                          ? const Color(0xFFFB923C)
                          : isFree || isTrial
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF34D399),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'STORE SUBSCRIPTION PLAN',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusFg,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Plan Name & Price Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  sub.planName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isFree || isTrial ? '₹0' : '₹${sub.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Color(0xFF34D399),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                isTrial ? ' / Trial' : (isFree ? ' / Forever' : ' / Month'),
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Details grid: Commission rate & Expiry
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.percent_rounded, size: 14, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Commission Rate', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(
                              '${sub.commissionPercent.toStringAsFixed(1)}% per order',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 24, color: Colors.white12),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.event_available_rounded, size: 14, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Plan Status', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(
                              expiryText,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isExpired
                                    ? const Color(0xFFF87171)
                                    : (isTrialExpiringSoon ? const Color(0xFFFB923C) : Colors.white),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: 10),

          // Action button
          SizedBox(
            width: double.infinity,
            height: 34,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF34D399),
                side: const BorderSide(color: Color(0xFF34D399), width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              icon: const Icon(Icons.info_outline_rounded, size: 14),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('View Plan Details & Benefits', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
              onPressed: () => _showSubscriptionModal(context),
            ),
          ),
        ],
      ),
    );
  }
}
