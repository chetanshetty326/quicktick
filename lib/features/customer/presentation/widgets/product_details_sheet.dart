import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../core/localization/app_strings.dart';
import '../../domain/entities/catalog_entities.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../bloc/customer_bloc.dart';

class ProductDetailsSheet extends StatelessWidget {
  final ProductEntity product;
  final StoreEntity? store;

  const ProductDetailsSheet({
    super.key,
    required this.product,
    this.store,
  });

  static Future<void> show(
    BuildContext context, {
    required ProductEntity product,
    StoreEntity? store,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<CustomerBloc>(),
        child: ProductDetailsSheet(product: product, store: store),
      ),
    );
  }

  static Widget buildDietaryBadge(String name, String categoryId, {String? foodType}) {
    final lower = name.toLowerCase();
    final isEgg = (foodType != null && foodType.toUpperCase() == 'EGG') ||
        lower.contains('egg') ||
        lower.contains('anda') ||
        lower.contains('omlette');
    final isNonVeg = (foodType != null && foodType.toUpperCase().contains('NON')) ||
        lower.contains('chicken') ||
        lower.contains('chiken') ||
        lower.contains('mutton') ||
        lower.contains('meat') ||
        lower.contains('fish') ||
        lower.contains('koli') ||
        lower.contains('prawn');

    final Color color = isNonVeg
        ? const Color(0xFFDC2626) // Red
        : (isEgg ? const Color(0xFFF59E0B) : const Color(0xFF16A34A)); // Amber / Green

    return Container(
      width: 14,
      height: 14,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Container(
          width: 5.5,
          height: 5.5,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  String _getStoreName(String storeId, {bool isKannada = false}) {
    return AppStrings.resolveStoreName(storeId, store?.name ?? '', isKannada: isKannada);
  }

  @override
  Widget build(BuildContext context) {
    final isKn = context.isKannada;
    final storeName = _getStoreName(product.storeId, isKannada: isKn);
    final hasDiscount = product.originalPrice != null && product.originalPrice! > product.price;
    final discountPercent = hasDiscount
        ? (((product.originalPrice! - product.price) / product.originalPrice!) * 100).round()
        : 0;

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
        bottom: false,
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

            // Scrollable Product Details Content
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                shrinkWrap: true,
                children: [
                  // 1. High-Res Product Image Showcase & Floating Actions
                  Stack(
                    children: [
                      Container(
                        height: (MediaQuery.of(context).size.height * 0.25).clamp(160.0, 220.0),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: CachedNetworkImage(
                            imageUrl: ImageUrlHelper.optimize(product.imageUrl, width: 600, height: 600),
                            fit: BoxFit.contain,
                            memCacheWidth: 600,
                            placeholder: (_, _) => const SkeletonShimmer(
                              child: SkeletonBox(
                                width: double.infinity,
                                height: double.infinity,
                                borderRadius: 22,
                              ),
                            ),
                            errorWidget: (_, _, _) => Container(
                              color: Colors.grey.shade100,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.shopping_bag_outlined, size: 54, color: Colors.grey),
                                  SizedBox(height: 6),
                                  Text('Product Image', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Close Button (Top-Right)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withValues(alpha: 0.55),
                          radius: 16,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),

                      // Discount Tag Badge (Top-Left)
                      if (hasDiscount && discountPercent > 0)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F766E).withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_offer_rounded, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  '$discountPercent% OFF',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Wishlist Heart Button (Bottom-Right)
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: BlocBuilder<CustomerBloc, CustomerState>(
                          builder: (context, state) {
                            final isFavorite = state.wishlistProductIds.contains(product.id);
                            return InkWell(
                              onTap: () {
                                context.read<CustomerBloc>().add(ToggleWishlistEvent(product.id));
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: isFavorite ? const Color(0xFFE11D48) : const Color(0xFF64748B),
                                  size: 20,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Responsive Tags & Availability Row (Wrap to avoid overflows)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Store Name Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.storefront_rounded, size: 12, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              storeName.toUpperCase(),
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 10.5, letterSpacing: 0.4),
                            ),
                          ],
                        ),
                      ),

                      // Unit Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.unit,
                          style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w700, fontSize: 10.5),
                        ),
                      ),

                      // Stock Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: product.isAvailable && product.stock > 0
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              product.isAvailable && product.stock > 0
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              size: 12,
                              color: product.isAvailable && product.stock > 0
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              product.isAvailable && product.stock > 0
                                  ? (isKn ? 'ಸ್ಟಾಕ್‌ನಲ್ಲಿದೆ (${product.stock} ಯೂನಿಟ್)' : 'In Stock (${product.stock} units)')
                                  : (isKn ? 'ಸ್ಟಾಕ್‌ನಲ್ಲಿಲ್ಲ' : 'Out of Stock'),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: product.isAvailable && product.stock > 0
                                    ? const Color(0xFF166534)
                                    : const Color(0xFF991B1B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 3. Product Title Row with Dietary Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      buildDietaryBadge(product.name, product.categoryId),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF0F172A), height: 1.25),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 4. Responsive Price & Tax Line (Wrap to prevent overflowing on small devices)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        '₹${product.price.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: AppColors.primary),
                      ),
                      if (hasDiscount)
                        Text(
                          '₹${product.originalPrice!.toStringAsFixed(0)}',
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Color(0xFF94A3B8),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isKn ? 'ಎಲ್ಲಾ ತೆರಿಗೆಗಳು ಸೇರಿವೆ' : 'Inclusive of all taxes',
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 14),

                  // 5. Product Description & Highlights
                  Text(
                    isKn ? 'ಉತ್ಪನ್ನದ ವಿವರಗಳು' : 'PRODUCT DETAILS',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.description.isNotEmpty
                        ? product.description
                        : (isKn ? 'ಪರಿಶೀಲಿಸಿದ ಸ್ಥಳೀಯ ಪಾಲುದಾರ ಚಿಲ್ಲರೆ ವ್ಯಾಪಾರಿಗಳಿಂದ ನೇರವಾಗಿ ತರಿಸಲಾದ ತಾಜಾ, 100% ಅಸಲಿ ದಿನಸಿ.' : 'Fresh, 100% genuine daily essential sourced directly from verified local partner retailers.'),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.45),
                  ),
                  const SizedBox(height: 16),

                  // 6. Retailer Store Information Card (Responsive Layout)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.storefront_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              isKn ? 'ಪರಿಶೀಲಿಸಿದ ಮಾರಾಟಗಾರರಿಂದ ಮಾರಾಟ' : 'Sold By Verified Partner',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    storeName,
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF1E293B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    store?.address ?? 'Indiranagar 100ft Road, Bangalore, Karnataka',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade700,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, color: Colors.white, size: 14),
                                  const SizedBox(width: 3),
                                  Text(
                                    (store?.rating ?? 4.8).toStringAsFixed(1),
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Row(
                          children: [
                            Icon(Icons.bolt_rounded, size: 14, color: Colors.amber),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Fast 15-Minute Local Delivery Guarantee',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 7. Sticky Bottom Add to Cart / Quantity Bar with Safe Inset Protection
            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                14 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: BlocBuilder<CustomerBloc, CustomerState>(
                builder: (context, state) {
                  final cartItem = state.cartItems.firstWhere(
                    (c) => c.product.id == product.id,
                    orElse: () => CartItemEntity(product: product, quantity: 0),
                  );

                  if (!product.isAvailable || product.stock <= 0) {
                    return Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.remove_shopping_cart_rounded, color: Color(0xFF94A3B8), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Item Currently Unavailable',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    );
                  }

                  if (cartItem.quantity > 0) {
                    return Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_rounded, color: Colors.white),
                            onPressed: () {
                              if (cartItem.quantity <= 1) {
                                HapticFeedback.mediumImpact();
                              } else {
                                HapticFeedback.selectionClick();
                              }
                              context.read<CustomerBloc>().add(
                                    UpdateCartQuantityEvent(product.id, cartItem.quantity - 1),
                                  );
                            },
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isKn ? '${cartItem.quantity} ಕಾರ್ಟ್‌ನಲ್ಲಿದೆ' : '${cartItem.quantity} in Cart',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                              ),
                              Text(
                                '${isKn ? 'ಒಟ್ಟು' : 'Total'}: ₹${(product.price * cartItem.quantity).toStringAsFixed(0)}',
                                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_rounded, color: Colors.white),
                            onPressed: () {
                              if (cartItem.quantity < product.stock) {
                                HapticFeedback.lightImpact();
                                context.read<CustomerBloc>().add(
                                      UpdateCartQuantityEvent(product.id, cartItem.quantity + 1),
                                  );
                              } else {
                                HapticFeedback.heavyImpact();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isKn ? 'ಗರಿಷ್ಠ ಲಭ್ಯವಿರುವ ಸ್ಟಾಕ್ ${product.stock} ಯೂನಿಟ್‌ಗಳು' : 'Maximum available stock is ${product.stock} units'),
                                    backgroundColor: const Color(0xFF0F172A),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }

                  final isStoreClosed = (store != null && !store!.isOpen) ||
                      (state.stores.where((s) => s.id == product.storeId).firstOrNull?.isOpen == false);
                  if (isStoreClosed) {
                    return SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.grey.shade600,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              isKn ? 'ಅಂಗಡಿ ಪ್ರಸ್ತುತ ಮುಚ್ಚಿದೆ' : 'Store is Currently Closed',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      onPressed: () {
                        if (product.stock <= 0) {
                          HapticFeedback.heavyImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isKn ? '${product.name} ಪ್ರಸ್ತುತ ಸ್ಟಾಕ್‌ನಲ್ಲಿಲ್ಲ' : '${product.name} is currently out of stock'),
                              backgroundColor: const Color(0xFFEF4444),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        HapticFeedback.lightImpact();
                        context.read<CustomerBloc>().add(AddToCartEvent(product));
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_shopping_cart_rounded, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${isKn ? 'ಕಾರ್ಟ್‌ಗೆ ಸೇರಿಸಿ' : 'Add to Cart'} • ₹${product.price.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
