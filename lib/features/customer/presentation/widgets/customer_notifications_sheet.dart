import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/customer_bloc.dart';

enum _NotifFilter { all, unread }

class CustomerNotificationsSheet extends StatefulWidget {
  final void Function(String orderId)? onTrackOrder;

  const CustomerNotificationsSheet({super.key, this.onTrackOrder});

  static Future<void> show(BuildContext context, {void Function(String orderId)? onTrackOrder}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<CustomerBloc>(),
        child: CustomerNotificationsSheet(onTrackOrder: onTrackOrder),
      ),
    );
  }

  @override
  State<CustomerNotificationsSheet> createState() => _CustomerNotificationsSheetState();
}

class _CustomerNotificationsSheetState extends State<CustomerNotificationsSheet> {
  _NotifFilter _selectedFilter = _NotifFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CustomerBloc>().add(LoadNotificationsEvent());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final isLandscape = mediaQuery.orientation == Orientation.landscape;

    // Responsive sheet height calculation: landscape vs portrait
    final sheetHeight = isLandscape
        ? (screenHeight * 0.94)
        : (screenHeight * 0.82).clamp(420.0, 720.0);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: screenWidth > 640 ? 580 : double.infinity,
        constraints: BoxConstraints(
          maxHeight: sheetHeight,
          maxWidth: 640,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          child: BlocBuilder<CustomerBloc, CustomerState>(
            builder: (context, state) {
              final unreadCount = state.unreadNotificationsCount > 0
                  ? state.unreadNotificationsCount
                  : state.notifications.where((n) => n['read'] != true && n['isRead'] != true).length;

              final allNotifs = state.notifications;
              final filteredNotifs = _selectedFilter == _NotifFilter.unread
                  ? allNotifs.where((n) => n['read'] != true && n['isRead'] != true).toList()
                  : allNotifs;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Responsive Header
                  _buildHeader(context, unreadCount),

                  // Responsive Filter Bar & Actions
                  _buildFilterAndActionsBar(context, allNotifs.length, unreadCount),

                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Notifications List or Responsive Empty State
                  Flexible(
                    child: filteredNotifs.isEmpty
                        ? _buildEmptyState(isUnreadFilter: _selectedFilter == _NotifFilter.unread)
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: () async {
                              context.read<CustomerBloc>().add(LoadNotificationsEvent());
                            },
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                              itemCount: filteredNotifs.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = filteredNotifs[index];
                                return _buildNotificationCard(context, item);
                              },
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int unreadCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 10, 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Flexible(
                      child: Text(
                        'Notifications',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          letterSpacing: -0.2,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$unreadCount new',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Live updates on your orders and offers',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF475569), size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndActionsBar(BuildContext context, int totalCount, int unreadCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          // Filter: All
          _buildFilterChip(
            label: 'All',
            count: totalCount,
            isSelected: _selectedFilter == _NotifFilter.all,
            onTap: () => setState(() => _selectedFilter = _NotifFilter.all),
          ),
          const SizedBox(width: 8),
          // Filter: Unread
          _buildFilterChip(
            label: 'Unread',
            count: unreadCount,
            isSelected: _selectedFilter == _NotifFilter.unread,
            onTap: () => setState(() => _selectedFilter = _NotifFilter.unread),
          ),
          const Spacer(),
          // Action: Mark all read
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: () {
                context.read<CustomerBloc>().add(MarkAllNotificationsReadEvent());
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.done_all_rounded, size: 15, color: AppColors.primary),
              label: const Text(
                'Mark all read',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, Map<String, dynamic> item) {
    final isRead = item['read'] == true || item['isRead'] == true;
    final notifId = item['_id']?.toString() ?? item['id']?.toString();
    final title = item['title']?.toString() ?? 'Order Notification';
    final body = item['body']?.toString() ?? item['message']?.toString() ?? '';
    final type = item['type']?.toString().toUpperCase() ?? 'ORDER';
    final timeStr = item['time']?.toString() ?? 'Just now';
    final orderId = item['orderId']?.toString();

    return InkWell(
      onTap: () {
        if (!isRead && notifId != null && notifId.isNotEmpty) {
          context.read<CustomerBloc>().add(MarkNotificationReadEvent(notifId));
        }
        if (orderId != null && orderId.isNotEmpty && widget.onTrackOrder != null) {
          Navigator.pop(context);
          widget.onTrackOrder!(orderId);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRead ? const Color(0xFFF8FAFC) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead ? const Color(0xFFE2E8F0) : AppColors.primary.withValues(alpha: 0.3),
            width: isRead ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _getNotifIconBg(type, isRead),
                shape: BoxShape.circle,
              ),
              child: Icon(_getNotifIcon(type), size: 18, color: _getNotifIconColor(type)),
            ),
            const SizedBox(width: 12),
            // Text Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
                            fontSize: 13,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeStr,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isRead ? const Color(0xFF64748B) : const Color(0xFF334155),
                        height: 1.25,
                      ),
                    ),
                  ],
                  if (orderId != null && orderId.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Track Order',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 12, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (!isRead) ...[
              const SizedBox(width: 6),
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool isUnreadFilter}) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUnreadFilter ? Icons.mark_email_read_rounded : Icons.notifications_none_rounded,
                size: 38,
                color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isUnreadFilter ? 'No Unread Notifications' : 'All Caught Up!',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15.5,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isUnreadFilter
                  ? 'You have viewed all of your notifications.'
                  : 'You do not have any new notifications right now. Order updates will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getNotifIcon(String type) {
    if (type.contains('DELIVERED')) return Icons.check_circle_rounded;
    if (type.contains('OUT_FOR_DELIVERY') || type.contains('PICKED_UP')) return Icons.delivery_dining_rounded;
    if (type.contains('PREPARING') || type.contains('ACCEPTED')) return Icons.outdoor_grill_rounded;
    if (type.contains('PROMO') || type.contains('OFFER')) return Icons.local_offer_rounded;
    return Icons.receipt_long_rounded;
  }

  Color _getNotifIconBg(String type, bool isRead) {
    if (type.contains('DELIVERED')) return const Color(0xFFDCFCE7);
    if (type.contains('OUT_FOR_DELIVERY')) return const Color(0xFFFEF3C7);
    if (type.contains('PROMO')) return const Color(0xFFEDE9FE);
    return const Color(0xFFE0F2FE);
  }

  Color _getNotifIconColor(String type) {
    if (type.contains('DELIVERED')) return const Color(0xFF16A34A);
    if (type.contains('OUT_FOR_DELIVERY')) return const Color(0xFFD97706);
    if (type.contains('PROMO')) return const Color(0xFF7C3AED);
    return const Color(0xFF0284C7);
  }
}
