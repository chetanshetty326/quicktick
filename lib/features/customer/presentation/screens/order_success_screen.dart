import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../order/domain/entities/order_entity.dart';
import '../../../../core/localization/app_strings.dart';
import '../bloc/customer_bloc.dart';
import 'customer_live_tracking_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  final OrderEntity order;
  final String? paymentId;
  final String paymentMethod;
  final VoidCallback? onTrackOrder;
  final VoidCallback? onBackToHome;

  const OrderSuccessScreen({
    super.key,
    required this.order,
    this.paymentId,
    required this.paymentMethod,
    this.onTrackOrder,
    this.onBackToHome,
  });

  @override
  Widget build(BuildContext context) {
    final isOnlinePayment = paymentMethod != 'COD';
    final isPendingPayment = order.paymentStatus.toUpperCase() == 'PENDING' && isOnlinePayment;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Icon(
              isPendingPayment ? Icons.hourglass_top_rounded : Icons.bolt,
              color: isPendingPayment ? const Color(0xFFD97706) : const Color(0xFF0F766E),
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              isPendingPayment ? 'Order Registered' : 'Order Confirmed',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
            onPressed: () {
              Navigator.of(context).pop();
              if (onBackToHome != null) onBackToHome!();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                // 1. Success / Pending Animation Badge
                Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPendingPayment
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFF10B981).withValues(alpha: 0.15),
                      border: Border.all(
                        color: isPendingPayment ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isPendingPayment ? const Color(0xFFF59E0B) : const Color(0xFF10B981))
                              .withValues(alpha: 0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        isPendingPayment ? Icons.hourglass_top_rounded : Icons.check_rounded,
                        color: isPendingPayment ? const Color(0xFFD97706) : const Color(0xFF059669),
                        size: 50,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Congratulations / Pending Header
                Center(
                  child: Text(
                    isPendingPayment
                        ? 'Payment Under Verification'
                        : (isOnlinePayment ? 'Payment Successful!' : 'Order Placed Successfully!'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    isPendingPayment
                        ? 'Your order #${order.orderNumber.isNotEmpty ? order.orderNumber : (order.id.length > 8 ? order.id.substring(order.id.length - 8) : order.id)} is received and awaiting bank clearance.'
                        : 'Your order #${order.orderNumber.isNotEmpty ? order.orderNumber : (order.id.length > 8 ? order.id.substring(order.id.length - 8) : order.id)} has been received.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (isPendingPayment) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'If money was deducted from your bank, the payment will automatically update within 1–2 minutes. Please do not attempt to pay again.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // 3. Hyperlocal ETA Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.timer_outlined, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ESTIMATED DELIVERY',
                              style: TextStyle(
                                color: Color(0xFF99F6E4),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '15 - 20 Minutes',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.bolt, color: Color(0xFF0F766E), size: 16),
                            SizedBox(width: 2),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: Color(0xFF0F766E),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 4. Payment & Order Details Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Summary',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildDetailRow(
                        'Payment Method',
                        isOnlinePayment ? 'Online (Razorpay / UPI)' : 'Cash on Delivery (COD)',
                        icon: isOnlinePayment ? Icons.credit_card_rounded : Icons.payments_rounded,
                        isHighlight: true,
                      ),
                      if (paymentId != null && paymentId!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          'Payment ID',
                          paymentId!,
                          icon: Icons.receipt_rounded,
                        ),
                      ],
                      const SizedBox(height: 10),
                      _buildDetailRow(
                        'Payment Status',
                        isOnlinePayment ? 'CAPTURED & VERIFIED' : 'PENDING ON ARRIVAL',
                        badgeColor: isOnlinePayment ? const Color(0xFF059669) : const Color(0xFFD97706),
                      ),
                      const Divider(height: 20, color: Color(0xFFE2E8F0)),
                      _buildDetailRow(
                        'Item Subtotal',
                        '₹${order.subtotal.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'Delivery Fee',
                        order.deliveryFee == 0 ? 'FREE' : '₹${order.deliveryFee.toStringAsFixed(2)}',
                        valueColor: order.deliveryFee == 0 ? const Color(0xFF059669) : null,
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'Platform Fee',
                        '₹${order.platformFee.toStringAsFixed(2)}',
                      ),
                      if (order.tax > 0 || order.taxBreakdown.hasBreakdown) ...[
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          'Taxes & Charges (GST)',
                          '₹${(order.tax > 0 ? order.tax : order.taxBreakdown.total).toStringAsFixed(2)}',
                        ),
                        if (order.taxBreakdown.hasBreakdown) ...[
                          if (order.taxBreakdown.cgst > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 16, top: 4),
                              child: _buildDetailRow(
                                '• CGST',
                                '₹${order.taxBreakdown.cgst.toStringAsFixed(2)}',
                              ),
                            ),
                          if (order.taxBreakdown.sgst > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 16, top: 4),
                              child: _buildDetailRow(
                                '• SGST',
                                '₹${order.taxBreakdown.sgst.toStringAsFixed(2)}',
                              ),
                            ),
                          if (order.taxBreakdown.igst > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 16, top: 4),
                              child: _buildDetailRow(
                                '• IGST',
                                '₹${order.taxBreakdown.igst.toStringAsFixed(2)}',
                              ),
                            ),
                        ],
                      ],
                      if (order.retailerGstinSnapshot != null && order.retailerGstinSnapshot!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          'Store GSTIN',
                          order.retailerGstinSnapshot!,
                          icon: Icons.receipt_long_outlined,
                        ),
                      ],
                      if (order.retailerStateSnapshot != null && order.retailerStateSnapshot!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          'Store State',
                          order.retailerStateSnapshot!,
                        ),
                      ],
                      if (order.discount > 0) ...[
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          'Coupon Discount${order.couponCode != null && order.couponCode!.isNotEmpty ? ' (${order.couponCode})' : ''}',
                          '- ₹${order.discount.toStringAsFixed(2)}',
                          valueColor: const Color(0xFF059669),
                        ),
                      ],
                      if (order.tip > 0) ...[
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          'Rider Tip',
                          '+ ₹${order.tip.toStringAsFixed(2)}',
                        ),
                      ],
                      const Divider(height: 24, color: Color(0xFFE2E8F0)),
                      _buildDetailRow(
                        'Total Amount Paid',
                        '₹${order.grandTotal.toStringAsFixed(2)}',
                        isBold: true,
                        valueColor: const Color(0xFF0F766E),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Delivery Address Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.location_on_rounded, color: Color(0xFF0F766E), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Delivering To',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        (order.deliveryAddress.isNotEmpty &&
                                !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(order.deliveryAddress) &&
                                order.deliveryAddress != 'Default Address')
                            ? order.deliveryAddress
                            : 'Customer Delivery Address',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Recipient: ${order.customerName} • ${order.customerPhone}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 6. Ordered Items Card
                if (order.items.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Items Ordered (${order.items.length})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...order.items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.quantity}x  ${item.nameSnapshot}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF334155),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '₹${(item.priceSnapshot * item.quantity).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                const SizedBox(height: 28),

                // 7. Action Buttons
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => CustomerLiveTrackingScreen(order: order),
                        ),
                      );
                      if (onTrackOrder != null) onTrackOrder!();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.radar_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          context.isKannada ? 'ಆರ್ಡರ್ ಲೈವ್ ಟ್ರ್ಯಾಕ್ ಮಾಡಿ' : 'Track Live Order',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Download Invoice Button
                BlocConsumer<CustomerBloc, CustomerState>(
                  listenWhen: (prev, curr) =>
                      prev.lastDownloadedInvoicePath != curr.lastDownloadedInvoicePath ||
                      prev.errorMessage != curr.errorMessage,
                  listener: (context, state) {
                    if (state.lastDownloadedInvoicePath != null && state.successMessage != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.successMessage!),
                          backgroundColor: const Color(0xFF0F766E),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } else if (state.errorMessage != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.errorMessage!),
                          backgroundColor: const Color(0xFFDC2626),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  builder: (context, state) {
                    final isDownloading = state.isDownloadingInvoice;
                    return SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: isDownloading
                            ? null
                            : () {
                                context.read<CustomerBloc>().add(
                                      DownloadOrderInvoiceEvent(order.id),
                                    );
                              },
                        icon: isDownloading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF0F766E),
                                ),
                              )
                            : const Icon(Icons.picture_as_pdf_rounded, size: 20, color: Color(0xFF0F766E)),
                        label: Text(
                          isDownloading
                              ? state.strings.downloadingInvoice
                              : (state.language == AppLanguage.kannada ? 'ಇನ್‌ವಾಯ್ಸ್ ಡೌನ್‌ಲೋಡ್ (PDF)' : 'Download Invoice (PDF)'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (onBackToHome != null) onBackToHome!();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      context.isKannada ? 'ಶಾಪಿಂಗ್ ಮುಂದುವರಿಸಿ' : 'Continue Shopping',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    IconData? icon,
    bool isHighlight = false,
    bool isBold = false,
    Color? valueColor,
    Color? badgeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: const Color(0xFF64748B)),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Align(
              alignment: Alignment.centerRight,
              child: badgeColor != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        value,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: badgeColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : Text(
                      value,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: isBold ? 16 : 13,
                        fontWeight: isBold ? FontWeight.w900 : (isHighlight ? FontWeight.w700 : FontWeight.w600),
                        color: valueColor ?? const Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
