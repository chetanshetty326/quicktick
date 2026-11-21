import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../order/domain/entities/order_entity.dart';
import '../bloc/retailer_bloc.dart';
import 'retailer_reject_dialog.dart';
import '../../../support/presentation/screens/support_tickets_screen.dart';

class RetailerOrderDetailsSheet extends StatelessWidget {
  final OrderEntity order;

  const RetailerOrderDetailsSheet({super.key, required this.order});

  static Future<void> show(BuildContext context, {required OrderEntity order}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<RetailerBloc>(),
        child: RetailerOrderDetailsSheet(order: order),
      ),
    );
  }

  Widget _buildResponsiveStepItem({
    required bool isCompleted,
    required bool isActive,
    required IconData icon,
    required String label,
    required bool hasLeftLine,
    required bool isLeftCompleted,
    required bool hasRightLine,
    required bool isRightCompleted,
  }) {
    Color bg;
    Color iconColor;
    if (isCompleted) {
      bg = const Color(0xFF10B981);
      iconColor = Colors.white;
    } else if (isActive) {
      bg = const Color(0xFF3B82F6);
      iconColor = Colors.white;
    } else {
      bg = const Color(0xFFE2E8F0);
      iconColor = const Color(0xFF94A3B8);
    }

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: hasLeftLine
                    ? Container(
                        height: 3,
                        color: isLeftCompleted ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                      )
                    : const SizedBox.shrink(),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Icon(icon, color: iconColor, size: 15),
              ),
              Expanded(
                child: hasRightLine
                    ? Container(
                        height: 3,
                        color: isRightCompleted ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: (isActive || isCompleted) ? FontWeight.w800 : FontWeight.w500,
                color: (isActive || isCompleted) ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = order.status.color;
    final isPlaced = order.status == OrderStatus.placed;
    final isAccepted = order.status == OrderStatus.accepted;
    final isPreparing = order.status == OrderStatus.preparing;
    final isReady = order.status == OrderStatus.readyForPickup;
    final isAssigned = order.status == OrderStatus.assigned;
    final isPickedUp = order.status == OrderStatus.pickedUp;
    final isOutForDelivery = order.status == OrderStatus.outForDelivery;
    final isDelivered = order.status == OrderStatus.delivered;
    final isCancelled = order.status == OrderStatus.cancelled;

    final stepPlacedCompleted = !isCancelled;
    final stepAcceptedCompleted = isAccepted || isPreparing || isReady || isAssigned || isPickedUp || isOutForDelivery || isDelivered;
    final stepReadyCompleted = isReady || isAssigned || isPickedUp || isOutForDelivery || isDelivered;
    final stepDeliveredCompleted = isDelivered;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
        maxWidth: 680,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle
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

            // Modal Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      order.status.label.toUpperCase(),
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order.orderNumber}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          order.createdAt.toLocal().toString().split('.')[0],
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.support_agent_rounded, color: Color(0xFF10B981), size: 22),
                    tooltip: 'Order Support',
                    onPressed: () {
                      Navigator.push(
                        context,
                        SupportTicketsScreen.route(
                          app: 'retailer',
                          prefilledOrderId: order.orderNumber,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Scrollable Content
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                shrinkWrap: true,
                children: [
                  // 1. Order Status Stepper Progress Bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ORDER LIFECYCLE PROGRESS',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _buildResponsiveStepItem(
                              isCompleted: stepPlacedCompleted,
                              isActive: isPlaced,
                              icon: Icons.receipt_rounded,
                              label: 'Placed',
                              hasLeftLine: false,
                              isLeftCompleted: false,
                              hasRightLine: true,
                              isRightCompleted: stepAcceptedCompleted,
                            ),
                            _buildResponsiveStepItem(
                              isCompleted: stepAcceptedCompleted,
                              isActive: isAccepted || isPreparing,
                              icon: Icons.soup_kitchen_rounded,
                              label: 'Preparing',
                              hasLeftLine: true,
                              isLeftCompleted: stepAcceptedCompleted,
                              hasRightLine: true,
                              isRightCompleted: stepReadyCompleted,
                            ),
                            _buildResponsiveStepItem(
                              isCompleted: stepReadyCompleted,
                              isActive: isReady || isAssigned || isPickedUp || isOutForDelivery,
                              icon: Icons.inventory_2_rounded,
                              label: 'Ready',
                              hasLeftLine: true,
                              isLeftCompleted: stepReadyCompleted,
                              hasRightLine: true,
                              isRightCompleted: stepDeliveredCompleted,
                            ),
                            _buildResponsiveStepItem(
                              isCompleted: stepDeliveredCompleted,
                              isActive: isDelivered,
                              icon: Icons.task_alt_rounded,
                              label: 'Delivered',
                              hasLeftLine: true,
                              isLeftCompleted: stepDeliveredCompleted,
                              hasRightLine: false,
                              isRightCompleted: false,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (order.rejectionReason != null && order.rejectionReason!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Order Rejection Reason:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF991B1B)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  order.rejectionReason!,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C), height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 2. Customer Delivery & Address Information Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.person_pin_circle_rounded, color: AppColors.primary, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Customer & Delivery Address',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.customerName.isNotEmpty ? order.customerName : 'Customer',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    order.deliveryAddress.isNotEmpty ? order.deliveryAddress : 'Address not provided',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2b. Delivery Partner Card (when assigned or later)
                  if (order.deliveryPartner != null ||
                      (order.deliveryPartnerName != null && order.deliveryPartnerName!.isNotEmpty)) ...[
                    Builder(builder: (context) {
                      final dp = order.deliveryPartner;
                      final partnerName = dp?.name ?? order.deliveryPartnerName!;
                      final partnerPhone = dp?.phone ?? order.deliveryPartnerPhone;
                      final vehicleBadge = dp != null && (dp.vehicleType.isNotEmpty || dp.vehicleNumber.isNotEmpty)
                          ? '${dp.vehicleType} • ${dp.vehicleNumber}'.trim()
                          : null;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF059669), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'ASSIGNED DELIVERY PARTNER',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF047857),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      if (dp != null && dp.rating > 0) ...[
                                        const SizedBox(width: 6),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.star_rounded, size: 12, color: Color(0xFFEAB308)),
                                            Text(
                                              dp.rating.toStringAsFixed(1),
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF854D0E)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    partnerName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF065F46)),
                                  ),
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    children: [
                                      if (vehicleBadge != null)
                                        Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFF86EFAC)),
                                          ),
                                          child: Text(
                                            vehicleBadge,
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                          ),
                                        ),
                                      if (partnerPhone != null && partnerPhone.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            partnerPhone,
                                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF059669)),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (partnerPhone != null && partnerPhone.isNotEmpty)
                              IconButton(
                                onPressed: () async {
                                  final uri = Uri.parse('tel:$partnerPhone');
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri);
                                  }
                                },
                                icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF059669)),
                                tooltip: 'Call Driver',
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFF86EFAC)),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ] else if (order.status == OrderStatus.readyForPickup ||
                      order.status == OrderStatus.preparing ||
                      order.status == OrderStatus.accepted) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFFD97706), size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Awaiting Delivery Partner',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF92400E)),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  'Rider dispatching automatically once order is ready',
                                  style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 3. Items to Pack Checklist
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'ITEMS TO PACK',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.8),
                            ),
                            Text(
                              '${order.items.length} unique items',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...order.items.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Text(
                                      '${item.quantity}x',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.nameSnapshot,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                                        ),
                                        Text(
                                          '₹${item.priceSnapshot.toStringAsFixed(0)} each',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₹${(item.priceSnapshot * item.quantity).toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Financial & Bill Summary
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Items Subtotal', style: TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                            Text('₹${order.subtotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Delivery Fee', style: TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                            Text('₹${order.deliveryFee.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                          ],
                        ),
                        if (order.platformFee > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Platform & Handling Fee', style: TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                              Text('₹${order.platformFee.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                            ],
                          ),
                        ],
                        if (order.tax > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Taxes & Charges (GST)', style: TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                              Text('₹${order.tax.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                            ],
                          ),
                          if (order.taxBreakdown.hasBreakdown) ...[
                            if (order.taxBreakdown.cgst > 0)
                              Padding(
                                padding: const EdgeInsets.only(left: 12, top: 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('• CGST', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                    Text('₹${order.taxBreakdown.cgst.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                            if (order.taxBreakdown.sgst > 0)
                              Padding(
                                padding: const EdgeInsets.only(left: 12, top: 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('• SGST', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                    Text('₹${order.taxBreakdown.sgst.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                            if (order.taxBreakdown.igst > 0)
                              Padding(
                                padding: const EdgeInsets.only(left: 12, top: 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('• IGST', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                    Text('₹${order.taxBreakdown.igst.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                          ],
                        ],
                        if (order.discount > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Coupon Discount${order.couponCode != null && order.couponCode!.isNotEmpty ? ' (${order.couponCode})' : ''}', style: const TextStyle(fontSize: 12.5, color: Color(0xFF059669))),
                              Text('-₹${order.discount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                            ],
                          ),
                        ],
                        const Divider(height: 16, color: Color(0xFFE2E8F0)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Order Total', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A))),
                                  const SizedBox(height: 2),
                                  Builder(builder: (ctx) {
                                    final isOnline = order.paymentMethod.toUpperCase() == 'ONLINE' ||
                                        order.paymentMethod.toUpperCase() == 'RAZORPAY';
                                    final isCompleted = order.paymentStatus.toUpperCase() == 'COMPLETED' ||
                                        order.paymentStatus.toUpperCase() == 'PAID';
                                    final badgeColor = (isOnline && isCompleted) || (!isOnline && isCompleted)
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFF59E0B);
                                    final badgeText = isOnline
                                        ? (isCompleted ? 'PAID ONLINE (COMPLETED)' : 'ONLINE (PENDING)')
                                        : (isCompleted ? 'COD (CASH COLLECTED)' : 'COD (PENDING COLLECTION)');

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        badgeText,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: badgeColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '₹${order.grandTotal.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF10B981)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        SupportTicketsScreen.route(
                          app: 'retailer',
                          prefilledOrderId: order.orderNumber,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.support_agent_rounded, size: 18, color: Color(0xFF10B981)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Issue with this order? Contact Support',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF0F172A)),
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 16, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons Bar at bottom
            if (isPlaced) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          RetailerRejectDialog.show(context, order: order);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFDC2626)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('REJECT ORDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.read<RetailerBloc>().add(AcceptOrderEvent(order.id));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('ACCEPT & CONFIRM', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (isAccepted) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.read<RetailerBloc>().add(MarkPreparingEvent(order.id));
                    },
                    icon: const Icon(Icons.soup_kitchen_rounded, color: Colors.white, size: 20),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('START PREPARING ORDER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Colors.white)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ] else if (isPreparing) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.read<RetailerBloc>().add(MarkReadyForPickupEvent(order.id));
                    },
                    icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('MARK READY FOR PICKUP', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Colors.white)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ] else if (isReady || isAssigned || isPickedUp || isOutForDelivery) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.delivery_dining_rounded, color: Color(0xFF059669), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isReady
                              ? 'Order packed & ready • Waiting for driver pickup'
                              : 'Delivery partner assigned • Order on the way',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF065F46)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (isDelivered) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.task_alt_rounded, color: Color(0xFF10B981), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Order Delivered Successfully ✨',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
