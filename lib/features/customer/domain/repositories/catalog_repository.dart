import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/catalog_entities.dart';
import '../entities/customer_address_entity.dart';
import '../entities/hero_banner_entity.dart';
import '../entities/coupon_entity.dart';
import '../entities/cart_pricing_entity.dart';

abstract class ICatalogRepository {
  Stream<List<ProductEntity>> get productsStream;
  Stream<List<StoreEntity>> get storesStream;

  // Catalog & Store Discovery
  Future<Either<Failure, List<CategoryEntity>>> getCategories();
  Future<Either<Failure, List<StoreEntity>>> getNearbyStores({double? lat, double? lng});
  Future<Either<Failure, StoreEntity>> getStoreDetails(String storeId);
  Future<Either<Failure, List<ProductEntity>>> getStoreProducts(String storeId);
  Future<Either<Failure, List<ProductEntity>>> searchProducts(
    String query, {
    String? category,
    int? page,
    int? limit,
    double? lat,
    double? lng,
    String? foodType,
  });
  Future<Either<Failure, ({List<ProductEntity> products, List<StoreEntity> stores})>> searchCatalog({
    required String query,
    int page = 1,
    int limit = 20,
    double? lat,
    double? lng,
  });
  Future<Either<Failure, List<ProductEntity>>> getRecommendations();
  Future<Either<Failure, List<HeroBannerEntity>>> getHeroBanners({String app = 'CUSTOMER'});

  // Coupons Module
  Future<Either<Failure, List<CouponEntity>>> getAvailableCoupons({String? retailerId});
  Future<Either<Failure, CouponValidationEntity>> validateCoupon({
    required String code,
    String? cartId,
    String? retailerId,
  });

  // Cart Validation & Pricing
  Future<Either<Failure, CartPricingEntity>> getCartPricing({
    String? couponCode,
    double tip = 0.0,
    String? zoneId,
    double? lat,
    double? lng,
  });
  Future<Either<Failure, CartPricingEntity?>> addCartItem({required String productId, required int quantity});
  Future<Either<Failure, bool>> removeCartItem(String productId);
  Future<Either<Failure, bool>> clearBackendCart();
  Future<Either<Failure, Map<String, dynamic>>> validateCart(List<Map<String, dynamic>> items);

  // Address Management
  Future<Either<Failure, List<CustomerAddressEntity>>> getAddresses();
  Future<Either<Failure, CustomerAddressEntity>> addAddress(CustomerAddressEntity address);
  Future<Either<Failure, CustomerAddressEntity>> updateAddress(String addressId, CustomerAddressEntity address);
  Future<Either<Failure, bool>> deleteAddress(String addressId);
  Future<Either<Failure, bool>> setDefaultAddress(String addressId);

  // Customer Wishlist
  Future<Either<Failure, List<ProductEntity>>> getWishlist();
  Future<Either<Failure, bool>> addToWishlist(String productId);
  Future<Either<Failure, bool>> removeFromWishlist(String productId);

  // Zone / Location Validation
  Future<Either<Failure, CustomerZoneEntity>> checkLocation({required double lat, required double lng});

  // Customer Notifications
  Future<Either<Failure, List<Map<String, dynamic>>>> getNotifications();
  Future<Either<Failure, int>> getUnreadNotificationCount();
  Future<Either<Failure, bool>> markNotificationRead(String notificationId);
  Future<Either<Failure, bool>> markAllNotificationsRead();
  Future<Either<Failure, bool>> registerDeviceToken({required String fcmToken, required String platform, String? deviceId});

  // Search History
  List<String> getSearchHistory();
  Future<void> saveSearchHistory(List<String> queries);

  // Retailer Catalog & Store Controls
  Future<Either<Failure, ProductEntity>> toggleProductStock(String productId, bool isAvailable);
  Future<Either<Failure, ProductEntity>> updateProductPrice(String productId, double newPrice);
  Future<Either<Failure, StoreEntity>> toggleStoreOpenStatus(String storeId, bool isOpen);
  Future<Either<Failure, ProductEntity>> addProduct(ProductEntity product);
  Future<Either<Failure, ProductEntity>> updateProduct(ProductEntity product);
  Future<Either<Failure, String>> deleteProduct(String productId);
}
