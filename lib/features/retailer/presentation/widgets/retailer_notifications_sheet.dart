import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/retailer_bloc.dart';

enum _RetailerNotifFilter { all, unread }

class RetailerNotificationsSheet extends StatefulWidget {
  const RetailerNotificationsSheet({super.key});

  static Future<void> show(BuildContext context) {
    final bloc = context.read<RetailerBloc>();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const RetailerNotificationsSheet(),
      ),
    );
  }

  @override
  State<RetailerNotificationsSheet> createState() => _RetailerNotificationsSheetState();
}

class _RetailerNotificationsSheetState extends State<RetailerNotificationsSheet> {
  _RetailerNotifFilter _selectedFilter = _RetailerNotifFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RetailerBloc>().add(const LoadRetailerNotificationsEvent());
      }
    });
  }

  ({IconData icon, Color color}) _resolveStyle(String type) {
    final upper = type.toUpperCase();
    if (upper.contains('CANCEL') || upper.contains('REJECT')) {
      return (icon: Icons.cancel_outlined, color: const Color(0xFFEF4444));
    }
    if (upper.contains('DRIVER') || upper.contains('DELIVERY')) {
      return (icon: Icons.delivery_dining_rounded, color: const Color(0xFF3B82F6));
    }
    if (upper.contains('PICKUP')) {
      return (icon: Icons.check_circle_outline_rounded, color: const Color(0xFF8B5CF6));
    }
    if (upper.contains('DELIVERED') || upper.contains('READY')) {
      return (icon: Icons.task_alt_rounded, color: const Color(0xFF059669));
    }
    if (upper.contains('PAYOUT') || upper.contains('WALLET') || upper.contains('SETTLEMENT')) {
      return (icon: Icons.account_balance_wallet_rounded, color: const Color(0xFFD97706));
    }
    if (upper.contains('COMPLIANCE') || upper.contains('VERIFIED') || upper.contains('STORE') || upper.contains('DOCUMENT')) {
      return (icon: Icons.verified_rounded, color: const Color(0xFF0D9488));
    }
    return (icon: Icons.receipt_long_rounded, color: const Color(0xFF10B981));
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final sheetHeight = isLandscape ? (screenHeight * 0.94) : (screenHeight * 0.85).clamp(420.0, 750.0);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: sheetHeight,
          maxWidth: 680,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 24,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: BlocBuilder<RetailerBloc, RetailerState>(
            builder: (context, state) {
              final unreadCount = state.unreadNotificationsCount > 0
                  ? state.unreadNotificationsCount
                  : state.notifications.where((n) => n['read'] != true && n['isRead'] != true).length;

              final allNotifs = state.notifications;
              final filteredNotifs = _selectedFilter == _RetailerNotifFilter.unread
                  ? allNotifs.where((n) => n['read'] != true && n['isRead'] != true).toList()
                  : allNotifs;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                  // Header Row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 16, 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF10B981), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Store Notification Alerts',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                              ),
                              Text(
                                unreadCount > 0 ? '$unreadCount unread alert${unreadCount > 1 ? 's' : ''}' : 'All caught up',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: unreadCount > 0 ? const Color(0xFF059669) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (allNotifs.isNotEmpty && unreadCount > 0)
                          TextButton.icon(
                            onPressed: () {
                              context.read<RetailerBloc>().add(const MarkAllRetailerNotificationsReadEvent());
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('All notifications marked as read'),
                                  backgroundColor: Color(0xFF10B981),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF10B981)),
                            label: const Text(
                              'Mark all read',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Filter Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: Text('All (${allNotifs.length})'),
                          selected: _selectedFilter == _RetailerNotifFilter.all,
                          onSelected: (_) => setState(() => _selectedFilter = _RetailerNotifFilter.all),
                          selectedColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _selectedFilter == _RetailerNotifFilter.all ? const Color(0xFF059669) : const Color(0xFF64748B),
                          ),
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: BorderSide(
                            color: _selectedFilter == _RetailerNotifFilter.all ? const Color(0xFF10B981) : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text('Unread ($unreadCount)'),
                          selected: _selectedFilter == _RetailerNotifFilter.unread,
                          onSelected: (_) => setState(() => _selectedFilter = _RetailerNotifFilter.unread),
                          selectedColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _selectedFilter == _RetailerNotifFilter.unread ? const Color(0xFF059669) : const Color(0xFF64748B),
                          ),
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: BorderSide(
                            color: _selectedFilter == _RetailerNotifFilter.unread ? const Color(0xFF10B981) : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Notifications List
                  Flexible(
                    child: filteredNotifs.isEmpty
                        ? RefreshIndicator(
                            color: const Color(0xFF10B981),
                            onRefresh: () async {
                              context.read<RetailerBloc>().add(const LoadRetailerNotificationsEvent());
                            },
                            child: ListView(
                              children: [
                                SizedBox(height: MediaQuery.of(context).size.height * 0.12),
                                Container(
                                  padding: const EdgeInsets.all(40),
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey.shade400),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _selectedFilter == _RetailerNotifFilter.unread
                                            ? 'No Unread Alerts'
                                            : 'No Notifications Yet',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _selectedFilter == _RetailerNotifFilter.unread
                                            ? 'You\'re all caught up with your store notifications.'
                                            : 'Incoming orders, driver pickup alerts, and payouts will appear here in real time.',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFF10B981),
                            onRefresh: () async {
                              context.read<RetailerBloc>().add(const LoadRetailerNotificationsEvent());
                            },
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              itemCount: filteredNotifs.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final notif = filteredNotifs[index];
                                final isRead = notif['read'] == true || notif['isRead'] == true;
                                final type = (notif['type'] ?? 'ORDER').toString();
                                final style = _resolveStyle(type);
                                final title = notif['title']?.toString() ?? 'Store Notification';
                                final body = (notif['body'] ?? notif['message'] ?? '').toString();
                                final timeStr = notif['time']?.toString() ??
                                    (notif['createdAt'] != null
                                        ? notif['createdAt'].toString().substring(0, 10)
                                        : 'Recent');
                                final notifId = (notif['_id'] ?? notif['id'] ?? '').toString();
                                final orderId = notif['orderId']?.toString();

                                return InkWell(
                                  onTap: () {
                                    if (!isRead && notifId.isNotEmpty) {
                                      context.read<RetailerBloc>().add(MarkRetailerNotificationReadEvent(notifId));
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isRead ? const Color(0xFFF8FAFC) : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isRead ? const Color(0xFFE2E8F0) : const Color(0xFF10B981).withValues(alpha: 0.35),
                                        width: isRead ? 1 : 1.5,
                                      ),
                                      boxShadow: isRead
                                          ? []
                                          : [
                                              BoxShadow(
                                                color: const Color(0xFF10B981).withValues(alpha: 0.06),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: style.color.withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(style.icon, color: style.color, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      title,
                                                      style: TextStyle(
                                                        fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
                                                        fontSize: 13.5,
                                                        color: const Color(0xFF0F172A),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    timeStr,
                                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                              if (orderId != null && orderId.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    'Order #$orderId',
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(height: 4),
                                              Text(
                                                body,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isRead ? const Color(0xFF64748B) : const Color(0xFF334155),
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!isRead) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 8,
                                            height: 8,
                                            margin: const EdgeInsets.only(top: 6),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF10B981),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
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
}
