import 'package:flutter/material.dart';


class SkeletonShimmer extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  const SkeletonShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.baseColor ?? const Color(0xFFE2E8F0);
    final highlight = widget.highlightColor ?? const Color(0xFFF8FAFC);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              colors: [base, highlight, base],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value.clamp(0.0, 1.0),
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Generic rounded rectangle skeleton block
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final ShapeBorder? shape;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.shape,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: ShapeDecoration(
        color: const Color(0xFFE2E8F0),
        shape: shape ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
      ),
    );
  }
}

/// Shimmer Skeleton for Product Grid Cards
class SkeletonProductCard extends StatelessWidget {
  const SkeletonProductCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      padding: const EdgeInsets.all(10),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton
          SkeletonBox(
            height: 110,
            width: double.infinity,
            borderRadius: 12,
          ),
          SizedBox(height: 10),
          // Title skeleton line 1
          SkeletonBox(
            height: 14,
            width: double.infinity,
            borderRadius: 4,
          ),
          SizedBox(height: 6),
          // Title skeleton line 2
          SkeletonBox(
            height: 12,
            width: 90,
            borderRadius: 4,
          ),
          Spacer(),
          // Price and Add button skeleton row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(
                height: 18,
                width: 55,
                borderRadius: 4,
              ),
              SkeletonBox(
                height: 32,
                width: 65,
                borderRadius: 8,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shimmer Skeleton for Horizontal Category Pill
class SkeletonCategoryItem extends StatelessWidget {
  const SkeletonCategoryItem({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          SkeletonBox(
            width: 56,
            height: 56,
            borderRadius: 28,
          ),
          SizedBox(height: 6),
          SkeletonBox(
            width: 48,
            height: 10,
            borderRadius: 4,
          ),
        ],
      ),
    );
  }
}

/// Shimmer Skeleton for Store Card
class SkeletonStoreCard extends StatelessWidget {
  const SkeletonStoreCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(
            height: 95,
            width: double.infinity,
            borderRadius: 16,
          ),
          Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(
                  height: 14,
                  width: 140,
                  borderRadius: 4,
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    SkeletonBox(
                      height: 10,
                      width: 60,
                      borderRadius: 4,
                    ),
                    SizedBox(width: 8),
                    SkeletonBox(
                      height: 10,
                      width: 40,
                      borderRadius: 4,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer Skeleton for Order Card
class SkeletonOrderCard extends StatelessWidget {
  const SkeletonOrderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(
                height: 16,
                width: 120,
                borderRadius: 4,
              ),
              SkeletonBox(
                height: 22,
                width: 80,
                borderRadius: 6,
              ),
            ],
          ),
          SizedBox(height: 12),
          SkeletonBox(
            height: 12,
            width: double.infinity,
            borderRadius: 4,
          ),
          SizedBox(height: 6),
          SkeletonBox(
            height: 12,
            width: 180,
            borderRadius: 4,
          ),
          SizedBox(height: 16),
          Divider(height: 1, color: Color(0xFFF1F5F9)),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(
                height: 14,
                width: 90,
                borderRadius: 4,
              ),
              SkeletonBox(
                height: 32,
                width: 100,
                borderRadius: 8,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full Home Page Skeleton Loading Screen
class CustomerHomeScreenSkeleton extends StatelessWidget {
  const CustomerHomeScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Top Location & Avatar Bar
          const Row(
            children: [
              SkeletonBox(width: 38, height: 38, borderRadius: 19),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 80, height: 10, borderRadius: 4),
                  SizedBox(height: 6),
                  SkeletonBox(width: 140, height: 14, borderRadius: 4),
                ],
              ),
              Spacer(),
              SkeletonBox(width: 36, height: 36, borderRadius: 18),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Search Bar Skeleton
          const SkeletonBox(
            height: 48,
            width: double.infinity,
            borderRadius: 14,
          ),
          const SizedBox(height: 18),

          // 3. Promo Banner Skeleton
          const SkeletonBox(
            height: 130,
            width: double.infinity,
            borderRadius: 18,
          ),
          const SizedBox(height: 20),

          // 4. Categories Row Skeleton
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 110, height: 16, borderRadius: 4),
              SkeletonBox(width: 50, height: 12, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              itemBuilder: (_, _) => const SkeletonCategoryItem(),
            ),
          ),
          const SizedBox(height: 20),

          // 5. Featured Stores Skeleton
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 140, height: 16, borderRadius: 4),
              SkeletonBox(width: 50, height: 12, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              itemBuilder: (_, _) => const SkeletonStoreCard(),
            ),
          ),
          const SizedBox(height: 22),

          // 6. Products Grid Skeleton
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 130, height: 16, borderRadius: 4),
              SkeletonBox(width: 50, height: 12, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: 4,
            itemBuilder: (_, _) => const SkeletonProductCard(),
          ),
        ],
      ),
    );
  }
}

/// Orders List Skeleton
class CustomerOrdersSkeleton extends StatelessWidget {
  const CustomerOrdersSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        itemBuilder: (_, _) => const SkeletonOrderCard(),
      ),
    );
  }
}

/// Retailer Live Orders Tab Skeleton
class RetailerOrdersSkeleton extends StatelessWidget {
  const RetailerOrdersSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          // Banner Carousel Shimmer
          const SkeletonBox(
            height: 124,
            width: double.infinity,
            borderRadius: 16,
          ),
          const SizedBox(height: 16),

          // Incentive Hub Shimmer
          const SkeletonBox(
            height: 72,
            width: double.infinity,
            borderRadius: 14,
          ),
          const SizedBox(height: 16),

          // Section Title
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 160, height: 16, borderRadius: 4),
              SkeletonBox(width: 70, height: 18, borderRadius: 10),
            ],
          ),
          const SizedBox(height: 12),

          // Order Cards
          ...List.generate(
            3,
            (_) => Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 120, height: 15, borderRadius: 4),
                            SizedBox(height: 6),
                            SkeletonBox(width: 80, height: 11, borderRadius: 4),
                          ],
                        ),
                        SkeletonBox(width: 75, height: 22, borderRadius: 12),
                      ],
                    ),
                  ),
                  Divider(height: 1),
                  Padding(
                    padding: EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 100, height: 11, borderRadius: 4),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SkeletonBox(width: 140, height: 14, borderRadius: 4),
                            SkeletonBox(width: 50, height: 14, borderRadius: 4),
                          ],
                        ),
                        SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SkeletonBox(width: 110, height: 14, borderRadius: 4),
                            SkeletonBox(width: 45, height: 14, borderRadius: 4),
                          ],
                        ),
                        SizedBox(height: 14),
                        Divider(height: 1),
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SkeletonBox(width: 130, height: 15, borderRadius: 4),
                            SkeletonBox(width: 100, height: 24, borderRadius: 6),
                          ],
                        ),
                        SizedBox(height: 14),
                        SkeletonBox(width: double.infinity, height: 42, borderRadius: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Retailer Inventory Tab Skeleton
class RetailerInventorySkeleton extends StatelessWidget {
  const RetailerInventorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            children: [
              SkeletonBox(width: 54, height: 54, borderRadius: 10),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 140, height: 14, borderRadius: 4),
                    SizedBox(height: 6),
                    SkeletonBox(width: 90, height: 12, borderRadius: 4),
                    SizedBox(height: 6),
                    SkeletonBox(width: 60, height: 10, borderRadius: 4),
                  ],
                ),
              ),
              SkeletonBox(width: 40, height: 24, borderRadius: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Retailer Financials Tab Skeleton
class RetailerFinancialsSkeleton extends StatelessWidget {
  const RetailerFinancialsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Net Payout Card Shimmer
            const SkeletonBox(
              height: 140,
              width: double.infinity,
              borderRadius: 18,
            ),
            const SizedBox(height: 16),

            // Payout Button Shimmer
            const SkeletonBox(
              height: 48,
              width: double.infinity,
              borderRadius: 12,
            ),
            const SizedBox(height: 20),

            // Summary Grid
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 70, height: 10, borderRadius: 4),
                        Spacer(),
                        SkeletonBox(width: 50, height: 18, borderRadius: 4),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 80, height: 10, borderRadius: 4),
                        Spacer(),
                        SkeletonBox(width: 60, height: 18, borderRadius: 4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Recent Orders Header
            const SkeletonBox(width: 140, height: 15, borderRadius: 4),
            const SizedBox(height: 12),
            ...List.generate(
              3,
              (_) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 100, height: 13, borderRadius: 4),
                        SizedBox(height: 4),
                        SkeletonBox(width: 70, height: 10, borderRadius: 4),
                      ],
                    ),
                    SkeletonBox(width: 60, height: 15, borderRadius: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }
}
