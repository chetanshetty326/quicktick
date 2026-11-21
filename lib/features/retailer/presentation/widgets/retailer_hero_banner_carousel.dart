import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../customer/domain/entities/hero_banner_entity.dart';
import '../bloc/retailer_bloc.dart';

class RetailerHeroBannerCarousel extends StatefulWidget {
  final double? height;
  final EdgeInsetsGeometry padding;

  const RetailerHeroBannerCarousel({
    super.key,
    this.height,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<RetailerHeroBannerCarousel> createState() => _RetailerHeroBannerCarouselState();
}

class _RetailerHeroBannerCarouselState extends State<RetailerHeroBannerCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  // Fallback banners shown if no backend hero banners are active
  final List<Map<String, dynamic>> _fallbackBanners = const [
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
  void initState() {
    super.initState();
    _startAutoScroll(4);
  }

  void _startAutoScroll(int totalCount) {
    _timer?.cancel();
    if (totalCount <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !_pageController.hasClients) return;
      final nextPage = (_currentPage + 1) % totalCount;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleHeroBannerTap(HeroBannerEntity banner) async {
    final link = banner.ctaLink;
    if (link == null || link.trim().isEmpty) return;
    final uri = Uri.tryParse(link.trim());
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  void _showFallbackModal(BuildContext context, Map<String, dynamic> banner) {
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
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${banner['title']} acknowledged for kitchen staff!'),
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
    return BlocConsumer<RetailerBloc, RetailerState>(
      listenWhen: (prev, curr) => prev.heroBanners.length != curr.heroBanners.length,
      listener: (context, state) {
        final count = state.heroBanners.isNotEmpty ? state.heroBanners.length : _fallbackBanners.length;
        _startAutoScroll(count);
      },
      builder: (context, state) {
        final liveBanners = state.heroBanners.where((b) => b.isActive).toList();
        final hasLiveBanners = liveBanners.isNotEmpty;
        final totalCount = hasLiveBanners ? liveBanners.length : _fallbackBanners.length;

        final screenWidth = MediaQuery.of(context).size.width;
        final bannerHeight = widget.height ?? (screenWidth > 600 ? 165.0 : (screenWidth * 0.42).clamp(135.0, 160.0));

        return Padding(
          padding: widget.padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: bannerHeight,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  itemCount: totalCount,
                  itemBuilder: (context, index) {
                    if (hasLiveBanners) {
                      final banner = liveBanners[index];
                      final hasImage = banner.imageUrl != null && banner.imageUrl!.trim().isNotEmpty;
                      final hasBadge = banner.badge != null && banner.badge!.trim().isNotEmpty;
                      final hasSubtitle = banner.subtitle != null && banner.subtitle!.trim().isNotEmpty;
                      final hasCta = banner.ctaLabel != null && banner.ctaLabel!.trim().isNotEmpty;

                      return GestureDetector(
                        onTap: () => _handleHeroBannerTap(banner),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (hasImage)
                                CachedNetworkImage(
                                  imageUrl: banner.imageUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: const Color(0xFF1E293B),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF064E3B), Color(0xFF0F172A)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: const Icon(Icons.storefront_rounded, color: Colors.white24, size: 36),
                                  ),
                                )
                              else
                                Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF0F172A)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                ),

                              // Dark overlay for legibility
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.1),
                                      Colors.black.withValues(alpha: 0.35),
                                      Colors.black.withValues(alpha: 0.8),
                                    ],
                                    stops: const [0.0, 0.45, 1.0],
                                  ),
                                ),
                              ),

                              // Text content
                              Positioned(
                                left: 14,
                                right: 14,
                                bottom: 12,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (hasBadge)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          banner.badge!.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    if (banner.title.isNotEmpty)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: RichText(
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              text: TextSpan(
                                                text: banner.title,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 15,
                                                  shadows: [
                                                    Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
                                                  ],
                                                ),
                                                children: [
                                                  if (banner.titleAccent != null && banner.titleAccent!.isNotEmpty) ...[
                                                    const TextSpan(text: ' '),
                                                    TextSpan(
                                                      text: banner.titleAccent,
                                                      style: const TextStyle(
                                                        color: Color(0xFFFBBF24),
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (hasCta) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                banner.ctaLabel!,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    if (hasSubtitle) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        banner.subtitle!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Fallback local incentive card
                    final b = _fallbackBanners[index];
                    final List<Color> gradientColors = b['gradient'] as List<Color>;

                    return InkWell(
                      onTap: () => _showFallbackModal(context, b),
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
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              if (totalCount > 1) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(totalCount, (index) {
                    final isSelected = index == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isSelected ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
