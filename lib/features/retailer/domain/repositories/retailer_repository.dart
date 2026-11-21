import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../customer/domain/entities/catalog_entities.dart';
import '../../../customer/domain/entities/hero_banner_entity.dart';
import '../../../order/domain/entities/order_entity.dart';
import '../entities/retailer_entities.dart';
import '../entities/retailer_registration_status_entity.dart';
import '../entities/retailer_finance_entities.dart';

abstract class IRetailerRepository {
  Stream<List<OrderEntity>> get ordersStream;
  Stream<List<ProductEntity>> get productsStream;

  Future<Either<Failure, RetailerStoreProfileEntity>> registerStore(Map<String, dynamic> data);
  Future<Either<Failure, RetailerStoreProfileEntity>> updateStoreProfile(Map<String, dynamic> data);
  Future<Either<Failure, RetailerStoreProfileEntity>> getStoreProfile();
  Future<Either<Failure, bool>> toggleStoreStatus(bool isOpen);

  // Verification & Registration Status Methods
  Future<Either<Failure, ({bool available, String message})>> checkStoreName(String name);
  Future<Either<Failure, RetailerCheckRegisteredEntity>> checkRetailerRegistration();
  Future<Either<Failure, RetailerRejectionEntity>> getRejectionReason();
  Future<Either<Failure, FileUploadEntity>> uploadDocument(String filePath, {String? folder});
  Future<Either<Failure, bool>> updateShopPhoto(String shopPhotoUrl) async =>
      const Left(ServerFailure(message: 'Unimplemented'));

  Future<Either<Failure, List<OrderEntity>>> getLiveOrders();
  Future<Either<Failure, List<OrderEntity>>> getOrderHistory();
  Future<Either<Failure, OrderEntity>> acceptOrder(String orderId);
  Future<Either<Failure, OrderEntity>> markPreparing(String orderId);
  Future<Either<Failure, OrderEntity>> markReady(String orderId);
  Future<Either<Failure, OrderEntity>> rejectOrder(String orderId, String reason);

  Future<Either<Failure, List<ProductEntity>>> getCatalogItems();
  Future<Either<Failure, ProductEntity>> addProduct(ProductEntity product);
  Future<Either<Failure, ProductEntity>> updateProduct(ProductEntity product);
  Future<Either<Failure, bool>> deleteProduct(String productId);
  Future<Either<Failure, bool>> toggleProductStock(String productId, bool isAvailable, {int? currentStock});

  Future<Either<Failure, RetailerDashboardStatsEntity>> getDashboardStats();
  Future<Either<Failure, bool>> registerDeviceToken({required String fcmToken, required String platform, required String deviceId});

  // Notifications Module
  Future<Either<Failure, List<Map<String, dynamic>>>> getNotifications();
  Future<Either<Failure, int>> getUnreadNotificationCount();
  Future<Either<Failure, bool>> markNotificationRead(String notificationId);
  Future<Either<Failure, bool>> markAllNotificationsRead();

  // Subscription Module
  Future<Either<Failure, RetailerSubscriptionEntity?>> getSubscription();

  // Earnings, Settlements & Bank Account (Finance Module)
  Future<Either<Failure, RetailerEarningsSummaryEntity>> getEarningsSummary();
  Future<Either<Failure, List<RetailerEarningEntity>>> getEarnings({String? status, int limit = 50, int skip = 0});
  Future<Either<Failure, List<RetailerSettlementEntity>>> getSettlements({int limit = 50, int skip = 0});
  Future<Either<Failure, RetailerBankAccountEntity>> updateBankAccount(Map<String, dynamic> data);

  // Hero Banners Module (Retailer Announcements)
  Future<Either<Failure, List<HeroBannerEntity>>> getHeroBanners({String app = 'RETAILER'});
}
