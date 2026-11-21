import 'dart:async';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../customer/domain/entities/catalog_entities.dart';
import '../../../customer/domain/entities/hero_banner_entity.dart';
import '../../../order/domain/entities/order_entity.dart';
import '../../domain/entities/retailer_entities.dart';
import '../../domain/entities/retailer_finance_entities.dart';
import '../../domain/entities/retailer_registration_status_entity.dart';
import '../../domain/repositories/retailer_repository.dart';
import '../datasources/retailer_remote_data_source.dart';

import '../../../../core/storage/local_cache_service.dart';
import '../../../customer/data/models/product_model.dart';

class RetailerRepositoryImpl implements IRetailerRepository {
  final IRetailerRemoteDataSource _remoteDataSource;
  final ILocalCacheService? _localCache;

  final StreamController<List<OrderEntity>> _ordersController =
      StreamController<List<OrderEntity>>.broadcast();
  final StreamController<List<ProductEntity>> _productsController =
      StreamController<List<ProductEntity>>.broadcast();

  final List<OrderEntity> _orders = [];
  final List<ProductEntity> _products = [];

  RetailerRepositoryImpl(this._remoteDataSource, [this._localCache]) {
    if (_localCache != null) {
      final cached = _localCache.getCachedProducts();
      if (cached.isNotEmpty) {
        _products.addAll(cached.map((j) => ProductModel.fromJson(j)));
      }
    }
  }

  @override
  Stream<List<OrderEntity>> get ordersStream => _ordersController.stream;

  @override
  Stream<List<ProductEntity>> get productsStream => _productsController.stream;

  void _emitOrders() {
    _ordersController.add(List.unmodifiable(_orders));
    if (_localCache != null) {
      _localCache.cacheActiveOrders(_orders.map((e) => e.toJson()).toList());
    }
  }

  void _emitProducts() {
    _productsController.add(List.unmodifiable(_products));
    if (_localCache != null) {
      _localCache.cacheProducts(_products.map((e) => e.toJson()).toList());
    }
  }

  @override
  Future<Either<Failure, RetailerStoreProfileEntity>> registerStore(Map<String, dynamic> data) async {
    try {
      final profile = await _remoteDataSource.registerStore(data);
      return Right(profile);
    } on DuplicateResourceException catch (e) {
      return Left(DuplicateResourceFailure(message: e.message, code: e.code, statusCode: e.statusCode));
    } on DuplicateResourceFailure catch (e) {
      if (e.message.toLowerCase().contains('already registered')) {
        try {
          final profile = await _remoteDataSource.getStoreProfile();
          return Right(profile);
        } catch (_) {}
      }
      return Left(e);
    } on Failure catch (f) {
      if (f.message.toLowerCase().contains('already registered')) {
        try {
          final profile = await _remoteDataSource.getStoreProfile();
          return Right(profile);
        } catch (_) {}
      }
      return Left(f);
    } catch (e) {
      try {
        final profile = await _remoteDataSource.updateStoreProfile(data);
        return Right(profile);
      } catch (_) {}
      return Left(ServerFailure(message: 'Failed to register store: $e'));
    }
  }

  @override
  Future<Either<Failure, RetailerCheckRegisteredEntity>> checkRetailerRegistration() async {
    try {
      final res = await _remoteDataSource.checkRetailerRegistration();
      return Right(res);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to check registration status: $e'));
    }
  }

  @override
  Future<Either<Failure, RetailerRejectionEntity>> getRejectionReason() async {
    try {
      final res = await _remoteDataSource.getRejectionReason();
      return Right(res);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get rejection details: $e'));
    }
  }

  @override
  Future<Either<Failure, ({bool available, String message})>> checkStoreName(String name) async {
    try {
      final res = await _remoteDataSource.checkStoreName(name);
      return Right(res);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to check store name: $e'));
    }
  }

  @override
  Future<Either<Failure, FileUploadEntity>> uploadDocument(String filePath, {String? folder}) async {
    try {
      final res = await _remoteDataSource.uploadFile(filePath: filePath, folder: folder);
      return Right(res);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to upload document: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> updateShopPhoto(String shopPhotoUrl) async {
    try {
      final res = await _remoteDataSource.updateShopPhoto(shopPhotoUrl);
      return Right(res);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to update shop photo: $e'));
    }
  }

  @override
  Future<Either<Failure, RetailerStoreProfileEntity>> updateStoreProfile(Map<String, dynamic> data) async {
    try {
      final profile = await _remoteDataSource.updateStoreProfile(data);
      return Right(profile);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to update store profile: $e'));
    }
  }

  @override
  Future<Either<Failure, RetailerStoreProfileEntity>> getStoreProfile() async {
    try {
      final profile = await _remoteDataSource.getStoreProfile();
      return Right(profile);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load store profile: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> toggleStoreStatus(bool isOpen) async {
    try {
      final res = await _remoteDataSource.toggleStoreStatus(isOpen);
      return Right(res);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to toggle store status: $e'));
    }
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getLiveOrders() async {
    List<OrderEntity> liveOrders = [];

    try {
      liveOrders = await _remoteDataSource.getLiveOrders();
    } catch (_) {
      // Network failure — fall through to cache
    }

    if (liveOrders.isNotEmpty) {
      // Replace the in-memory live window entirely with the fresh API response.
      // Do NOT merge indefinitely — completed/cancelled orders should not linger.
      _orders
        ..clear()
        ..addAll(liveOrders);
    } else if (_localCache != null) {
      // Offline fallback: load from cache
      final cached = await _localCache.reloadAndGetCachedOrders();
      for (final json in cached) {
        try {
          final ord = OrderEntity.fromJson(json);
          final idx = _orders.indexWhere((o) => o.id == ord.id || o.orderNumber == ord.orderNumber);
          if (idx == -1) {
            _orders.add(ord);
          } else {
            _orders[idx] = ord;
          }
        } catch (_) {}
      }
    }

    _emitOrders();
    return Right(List.unmodifiable(_orders));
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getOrderHistory() async {
    try {
      final history = await _remoteDataSource.getOrderHistory();
      return Right(history);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load order history: $e'));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> acceptOrder(String orderId) async {
    try {
      final updated = await _remoteDataSource.acceptOrder(orderId);
      final idx = _orders.indexWhere((o) => o.id == orderId);
      final finalOrder = idx != -1
          ? _orders[idx].copyWith(status: OrderStatus.accepted)
          : updated;
      if (idx != -1) {
        _orders[idx] = finalOrder;
      } else {
        _orders.add(finalOrder);
      }
      _emitOrders();
      return Right(finalOrder);
    } catch (e) {
      final idx = _orders.indexWhere((o) => o.id == orderId);
      if (idx != -1) {
        final current = _orders[idx];
        final localUpdated = current.copyWith(status: OrderStatus.accepted);
        _orders[idx] = localUpdated;
        _emitOrders();
        return Right(localUpdated);
      }
      return Left(ServerFailure(message: 'Failed to accept order: $e'));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> markPreparing(String orderId) async {
    try {
      final updated = await _remoteDataSource.markPreparing(orderId);
      final idx = _orders.indexWhere((o) => o.id == orderId);
      final finalOrder = idx != -1
          ? _orders[idx].copyWith(status: OrderStatus.preparing)
          : updated;
      if (idx != -1) {
        _orders[idx] = finalOrder;
      } else {
        _orders.add(finalOrder);
      }
      _emitOrders();
      return Right(finalOrder);
    } catch (e) {
      final idx = _orders.indexWhere((o) => o.id == orderId);
      if (idx != -1) {
        final current = _orders[idx];
        final localUpdated = current.copyWith(status: OrderStatus.preparing);
        _orders[idx] = localUpdated;
        _emitOrders();
        return Right(localUpdated);
      }
      return Left(ServerFailure(message: 'Failed to mark order preparing: $e'));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> markReady(String orderId) async {
    try {
      final updated = await _remoteDataSource.markReady(orderId);
      final idx = _orders.indexWhere((o) => o.id == orderId);
      final finalOrder = idx != -1
          ? _orders[idx].copyWith(status: OrderStatus.readyForPickup)
          : updated;
      if (idx != -1) {
        _orders[idx] = finalOrder;
      } else {
        _orders.add(finalOrder);
      }
      _emitOrders();
      return Right(finalOrder);
    } catch (e) {
      final idx = _orders.indexWhere((o) => o.id == orderId);
      if (idx != -1) {
        final current = _orders[idx];
        final localUpdated = current.copyWith(status: OrderStatus.readyForPickup);
        _orders[idx] = localUpdated;
        _emitOrders();
        return Right(localUpdated);
      }
      return Left(ServerFailure(message: 'Failed to mark order ready: $e'));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> rejectOrder(String orderId, String reason) async {
    try {
      final updated = await _remoteDataSource.rejectOrder(orderId, reason);
      final idx = _orders.indexWhere((o) => o.id == orderId);
      final finalOrder = idx != -1
          ? _orders[idx].copyWith(status: OrderStatus.rejected, rejectionReason: reason)
          : updated;
      if (idx != -1) {
        _orders[idx] = finalOrder;
      } else {
        _orders.add(finalOrder);
      }
      _emitOrders();
      return Right(finalOrder);
    } catch (e) {
      final idx = _orders.indexWhere((o) => o.id == orderId);
      if (idx != -1) {
        final current = _orders[idx];
        final localUpdated = current.copyWith(
          status: OrderStatus.rejected,
          rejectionReason: reason,
        );
        _orders[idx] = localUpdated;
        _emitOrders();
        return Right(localUpdated);
      }
      return Left(ServerFailure(message: 'Failed to reject order: $e'));
    }
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> getCatalogItems() async {
    // 1. Ensure local cached items are loaded if in-memory list was empty
    if (_products.isEmpty && _localCache != null) {
      final cached = _localCache.getCachedProducts();
      if (cached.isNotEmpty) {
        _products.addAll(cached.map((j) => ProductModel.fromJson(j)));
      }
    }

    try {
      final items = await _remoteDataSource.getCatalogItems();
      if (items.isNotEmpty) {
        // Merge remote items into _products so locally added items are never discarded
        for (final item in items) {
          final idx = _products.indexWhere((p) => p.id == item.id);
          if (idx >= 0) {
            _products[idx] = item;
          } else {
            _products.add(item);
          }
        }
      }
      _emitProducts();
      return Right(List.unmodifiable(_products));
    } catch (e) {
      if (_products.isNotEmpty) {
        _emitProducts();
        return Right(List.unmodifiable(_products));
      }
      return Left(ServerFailure(message: 'Failed to load catalog items: $e'));
    }
  }

  @override
  Future<Either<Failure, ProductEntity>> addProduct(ProductEntity product) async {
    try {
      final created = await _remoteDataSource.addProduct(product);
      final idx = _products.indexWhere((p) =>
          p.id == created.id ||
          (p.name.toLowerCase() == created.name.toLowerCase() && p.price == created.price));
      if (idx >= 0) {
        _products[idx] = created;
      } else {
        _products.insert(0, created);
      }
      _emitProducts();
      return Right(created);
    } catch (e) {
      final idx = _products.indexWhere((p) => p.id == product.id);
      if (idx >= 0) {
        _products[idx] = product;
      } else {
        _products.insert(0, product);
      }
      _emitProducts();
      return Right(product);
    }
  }

  @override
  Future<Either<Failure, ProductEntity>> updateProduct(ProductEntity product) async {
    try {
      final updated = await _remoteDataSource.updateProduct(product);
      final finalProduct = updated.id.isNotEmpty
          ? updated
          : updated.copyWith(id: product.id, imageUrl: updated.imageUrl.isNotEmpty ? updated.imageUrl : product.imageUrl);
      final idx = _products.indexWhere((p) => p.id == product.id || p.id == finalProduct.id);
      if (idx != -1) {
        _products[idx] = finalProduct;
      } else {
        _products.add(finalProduct);
      }
      _emitProducts();
      return Right(finalProduct);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to update product: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteProduct(String productId) async {
    try {
      final ok = await _remoteDataSource.deleteProduct(productId);
      if (ok) {
        _products.removeWhere((p) => p.id == productId);
        _emitProducts();
      }
      return Right(ok);
    } catch (e) {
      _products.removeWhere((p) => p.id == productId);
      _emitProducts();
      return const Right(true);
    }
  }

  @override
  Future<Either<Failure, bool>> toggleProductStock(String productId, bool isAvailable, {int? currentStock}) async {
    try {
      final ok = await _remoteDataSource.toggleProductStock(productId, isAvailable, currentStock: currentStock);
      final idx = _products.indexWhere((p) => p.id == productId);
      if (idx != -1) {
        final p = _products[idx];
        final newStock = (currentStock != null && currentStock >= 0)
            ? currentStock
            : p.stock;
        _products[idx] = p.copyWith(
          stock: newStock,
          isAvailable: isAvailable,
        );
        _emitProducts();
      }
      return Right(ok);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to update stock status: $e'));
    }
  }

  @override
  Future<Either<Failure, RetailerDashboardStatsEntity>> getDashboardStats() async {
    try {
      final stats = await _remoteDataSource.getDashboardStats();
      return Right(stats);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load dashboard stats: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> registerDeviceToken({
    required String fcmToken,
    required String platform,
    required String deviceId,
  }) async {
    try {
      final ok = await _remoteDataSource.registerDeviceToken(
        fcmToken: fcmToken,
        platform: platform,
        deviceId: deviceId,
      );
      return Right(ok);
    } catch (e) {
      return const Right(true); // Graceful fallback
    }
  }

  // Notifications Module
  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getNotifications() async {
    try {
      final notifs = await _remoteDataSource.getNotifications();
      return Right(notifs);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to fetch notifications: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> getUnreadNotificationCount() async {
    try {
      final count = await _remoteDataSource.getUnreadNotificationCount();
      return Right(count);
    } catch (e) {
      return const Right(0);
    }
  }

  @override
  Future<Either<Failure, bool>> markNotificationRead(String notificationId) async {
    try {
      final ok = await _remoteDataSource.markNotificationRead(notificationId);
      return Right(ok);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to mark notification as read: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> markAllNotificationsRead() async {
    try {
      final ok = await _remoteDataSource.markAllNotificationsRead();
      return Right(ok);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to mark all notifications read: $e'));
    }
  }

  @override
  Future<Either<Failure, RetailerSubscriptionEntity?>> getSubscription() async {
    try {
      final sub = await _remoteDataSource.getSubscription();
      return Right(sub ?? RetailerSubscriptionEntity.freeTier);
    } catch (_) {
      return const Right(RetailerSubscriptionEntity.freeTier);
    }
  }

  @override
  Future<Either<Failure, RetailerEarningsSummaryEntity>> getEarningsSummary() async {
    try {
      final summary = await _remoteDataSource.getEarningsSummary();
      return Right(summary);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to fetch earnings summary: $e'));
    }
  }

  @override
  Future<Either<Failure, List<RetailerEarningEntity>>> getEarnings({String? status, int limit = 50, int skip = 0}) async {
    try {
      final earnings = await _remoteDataSource.getEarnings(status: status, limit: limit, skip: skip);
      return Right(earnings);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to fetch earnings: $e'));
    }
  }

  @override
  Future<Either<Failure, List<RetailerSettlementEntity>>> getSettlements({int limit = 50, int skip = 0}) async {
    try {
      final settlements = await _remoteDataSource.getSettlements(limit: limit, skip: skip);
      return Right(settlements);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to fetch settlements: $e'));
    }
  }

  @override
  Future<Either<Failure, RetailerBankAccountEntity>> updateBankAccount(Map<String, dynamic> data) async {
    try {
      final bankAccount = await _remoteDataSource.updateBankAccount(data);
      return Right(bankAccount);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to update bank account: $e'));
    }
  }

  @override
  Future<Either<Failure, List<HeroBannerEntity>>> getHeroBanners({String app = 'RETAILER'}) async {
    try {
      final banners = await _remoteDataSource.getHeroBanners(app: app);
      return Right(banners);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to fetch retailer banners: $e'));
    }
  }
}
