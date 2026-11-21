import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../domain/entities/retailer_entities.dart';
import '../bloc/retailer_bloc.dart';

/// Responsive, real-time merchant order statistics dashboard card.
/// Displays today's order count, total revenue amount earned, top/most ordered product,
/// and live order pipeline breakdown in Clean Architecture with BLoC.
class RetailerOrderStatsCard extends StatelessWidget {
  const RetailerOrderStatsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RetailerBloc, RetailerState>(
      buildWhen: (prev, curr) =>
          prev.orders != curr.orders ||
          prev.dashboardStats != curr.dashboardStats ||
          prev.orderListVersion != curr.orderListVersion,
      builder: (context, state) {
        final analytics = state.orderAnalytics;
        final formattedDate = DateFormat('d MMM • EEEE').format(DateTime.now());

        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 350;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x080F172A),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header with live status badge & date
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 3.5,
                                  backgroundColor: Color(0xFF10B981),
                                ),
                                SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    'TODAY\'S METRICS',
                                    style: TextStyle(
                                      color: Color(0xFF065F46),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                  // 2. Primary KPI Cards Row: Orders Today & Revenue Got
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    child: isCompact
                        ? Column(
                            children: [
                              _buildKpiTile(
                                icon: Icons.shopping_bag_outlined,
                                iconColor: const Color(0xFF10B981),
                                iconBg: const Color(0xFFD1FAE5),
                                value: '${analytics.todayOrdersCount}',
                                label: 'Orders Today',
                                hint: analytics.todayOrdersCount == 1 ? '1 order placed' : '${analytics.todayOrdersCount} orders placed',
                              ),
                              const SizedBox(height: 10),
                              _buildKpiTile(
                                icon: Icons.currency_rupee_rounded,
                                iconColor: const Color(0xFF2563EB),
                                iconBg: const Color(0xFFDBEAFE),
                                value: '₹${analytics.todayRevenue.toStringAsFixed(0)}',
                                label: 'Amount Got Today',
                                hint: 'Gross sales value',
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _buildKpiTile(
                                  icon: Icons.shopping_bag_outlined,
                                  iconColor: const Color(0xFF10B981),
                                  iconBg: const Color(0xFFD1FAE5),
                                  value: '${analytics.todayOrdersCount}',
                                  label: 'Orders Today',
                                  hint: analytics.todayOrdersCount == 1 ? '1 order placed' : '${analytics.todayOrdersCount} orders placed',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildKpiTile(
                                  icon: Icons.currency_rupee_rounded,
                                  iconColor: const Color(0xFF2563EB),
                                  iconBg: const Color(0xFFDBEAFE),
                                  value: '₹${analytics.todayRevenue.toStringAsFixed(0)}',
                                  label: 'Amount Got Today',
                                  hint: 'Gross sales value',
                                ),
                              ),
                            ],
                          ),
                  ),

                  // 3. Highlighted Most Ordered Item Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: _buildMostOrderedSection(analytics.mostOrderedItem),
                  ),

                  // 4. Live Order Pipeline Status Quick Chips
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: _buildStatusPipelineStrip(analytics),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKpiTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    required String label,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMostOrderedSection(TopOrderedItemEntity? topItem) {
    if (topItem == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.insights_rounded, color: Color(0xFF94A3B8), size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Top selling item will highlight here when orders arrive today.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final resolvedImageUrl = ImageUrlHelper.optimize(topItem.imageUrl);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCD34D), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0AF59E0B),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department_rounded, size: 12, color: Colors.white),
                    SizedBox(width: 3),
                    Text(
                      'MOST ORDERED ITEM',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFBBF24), width: 0.8),
                ),
                child: Text(
                  '${topItem.totalQuantity} units sold',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Product Image / Thumbnail
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                clipBehavior: Clip.antiAlias,
                child: resolvedImageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: resolvedImageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFD97706)),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.fastfood_outlined,
                          color: Color(0xFFD97706),
                          size: 22,
                        ),
                      )
                    : const Icon(
                        Icons.fastfood_outlined,
                        color: Color(0xFFD97706),
                        size: 22,
                      ),
              ),
              const SizedBox(width: 10),
              // Product Name & Total Sales
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topItem.name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '₹${topItem.totalRevenue.toStringAsFixed(0)} generated',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPipelineStrip(RetailerOrderAnalyticsEntity analytics) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMiniPipelineChip(
              count: analytics.pendingOrdersCount,
              label: 'New',
              color: const Color(0xFFF59E0B),
              isAlert: analytics.pendingOrdersCount > 0,
            ),
          ),
          _buildMiniDivider(),
          Expanded(
            child: _buildMiniPipelineChip(
              count: analytics.preparingOrdersCount,
              label: 'Preparing',
              color: const Color(0xFF3B82F6),
            ),
          ),
          _buildMiniDivider(),
          Expanded(
            child: _buildMiniPipelineChip(
              count: analytics.readyOrdersCount,
              label: 'Ready',
              color: const Color(0xFF10B981),
            ),
          ),
          _buildMiniDivider(),
          Expanded(
            child: _buildMiniPipelineChip(
              count: analytics.deliveredOrdersCount,
              label: 'Done',
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniDivider() {
    return Container(
      width: 1,
      height: 18,
      color: const Color(0xFFCBD5E1),
    );
  }

  Widget _buildMiniPipelineChip({
    required int count,
    required String label,
    required Color color,
    bool isAlert = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isAlert ? const Color(0xFFB45309) : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }
}
