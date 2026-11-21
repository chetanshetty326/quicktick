import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/core/storage/local_cache_service.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/customer/domain/entities/customer_address_entity.dart';
import 'package:quicklink/features/customer/domain/repositories/catalog_repository.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/customer/presentation/bloc/customer_bloc.dart';
import 'package:quicklink/features/customer/presentation/bloc/customer_event.dart';
import 'package:quicklink/features/customer/presentation/bloc/customer_state.dart';

class TestMockCacheService implements ILocalCacheService {
  @override
  Future<void> init() async {}
  @override
  List<Map<String, dynamic>> getCartItems() => [];
  @override
  Future<void> saveCartItems(List<Map<String, dynamic>> items) async {}
  @override
  Future<void> clearCart() async {}
  @override
  Future<void> cacheStores(List<Map<String, dynamic>> stores) async {}
  @override
  List<Map<String, dynamic>> getCachedStores() => [];
  @override
  Future<void> cacheProducts(List<Map<String, dynamic>> products) async {}
  @override
  List<Map<String, dynamic>> getCachedProducts() => [];
  @override
  Future<void> cacheAddresses(List<Map<String, dynamic>> addresses) async {}
  @override
  List<Map<String, dynamic>> getCachedAddresses() => [];
  @override
  Future<void> cacheActiveOrders(List<Map<String, dynamic>> orders) async {}
  @override
  List<Map<String, dynamic>> getCachedActiveOrders() => [];
  @override
  Future<List<Map<String, dynamic>>> reloadAndGetCachedOrders() async => [];
  @override
  Future<void> setDarkMode(bool isDark) async {}
  @override
  bool isDarkMode() => false;
  @override
  Future<void> setDevRole(String role) async {}
  @override
  String? getDevRole() => null;
}

class TestMockCatalogRepo implements ICatalogRepository {
  final _productsCtrl = StreamController<List<ProductEntity>>.broadcast();
  final _storesCtrl = StreamController<List<StoreEntity>>.broadcast();

  final List<CustomerAddressEntity> addresses = [];

  @override
  Stream<List<ProductEntity>> get productsStream => _productsCtrl.stream;
  @override
  Stream<List<StoreEntity>> get storesStream => _storesCtrl.stream;
  Future<Either<Failure, List<ProductEntity>>> getProducts({String? categoryId, String? query, double? maxPrice, String? storeId}) async => const Right([]);
  @override
  Future<Either<Failure, StoreEntity>> getStoreDetails(String storeId) async => throw UnimplementedError();
  @override
  Future<Either<Failure, List<ProductEntity>>> getStoreProducts(String storeId) async => const Right([]);
  @override
  Future<Either<Failure, List<ProductEntity>>> searchProducts(String query, {String? category, int? page, int? limit}) async => const Right([]);
  @override
  Future<Either<Failure, ({List<ProductEntity> products, List<StoreEntity> stores})>> searchCatalog({
    required String query,
    int page = 1,
    int limit = 20,
  }) async => const Right((products: [], stores: []));
  @override
  Future<Either<Failure, List<StoreEntity>>> getNearbyStores({double? lat, double? lng}) async => const Right([]);
  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories() async => const Right([]);
  @override
  Future<Either<Failure, List<CustomerAddressEntity>>> getAddresses() async => Right(addresses);
  @override
  Future<Either<Failure, CustomerAddressEntity>> addAddress(CustomerAddressEntity address) async {
    addresses.add(address);
    return Right(address);
  }
  @override
  Future<Either<Failure, CustomerAddressEntity>> updateAddress(String addressId, CustomerAddressEntity address) async {
    final idx = addresses.indexWhere((a) => a.id == addressId);
    if (idx >= 0) {
      addresses[idx] = address;
    } else {
      addresses.add(address);
    }
    return Right(address);
  }
  @override
  Future<Either<Failure, bool>> deleteAddress(String addressId) async => const Right(true);
  @override
  Future<Either<Failure, bool>> setDefaultAddress(String addressId) async => const Right(true);
  @override
  Future<Either<Failure, List<ProductEntity>>> getWishlist() async => const Right([]);
  @override
  Future<Either<Failure, bool>> addToWishlist(String productId) async => const Right(true);
  @override
  Future<Either<Failure, bool>> removeFromWishlist(String productId) async => const Right(true);
  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getNotifications() async => const Right([]);
  @override
  Future<Either<Failure, bool>> markNotificationRead(String notificationId) async => const Right(true);
  @override
  Future<Either<Failure, bool>> markAllNotificationsRead() async => const Right(true);
  @override
  Future<Either<Failure, bool>> registerDeviceToken({required String fcmToken, required String platform, required String deviceId}) async => const Right(true);
  @override
  Future<Either<Failure, ProductEntity>> toggleProductStock(String productId, bool isAvailable) async => throw UnimplementedError();
  @override
  Future<Either<Failure, ProductEntity>> updateProductPrice(String productId, double newPrice) async => throw UnimplementedError();
  @override
  Future<Either<Failure, StoreEntity>> toggleStoreOpenStatus(String storeId, bool isOpen) async => throw UnimplementedError();
  @override
  Future<Either<Failure, ProductEntity>> createProduct(Map<String, dynamic> productData) async => throw UnimplementedError();
  @override
  Future<Either<Failure, ProductEntity>> addProduct(ProductEntity product) async => throw UnimplementedError();
  @override
  Future<Either<Failure, ProductEntity>> updateProduct(ProductEntity product) async => throw UnimplementedError();
  @override
  Future<Either<Failure, String>> deleteProduct(String productId) async => throw UnimplementedError();
  @override
  Future<Either<Failure, List<ProductEntity>>> getRecommendations() async => const Right([]);
  @override
  Future<Either<Failure, Map<String, dynamic>>> validateCart(List<Map<String, dynamic>> items) async => const Right({'valid': true});
}

class TestMockOrderRepo implements IOrderRepository {
  final _ctrl = StreamController<List<OrderEntity>>.broadcast();
  OrderEntity? Function(String deliveryAddress)? orderBuilder;
  String? lastPassedDeliveryAddress;

  @override
  Stream<List<OrderEntity>> get ordersStream => _ctrl.stream;

  @override
  Future<Either<Failure, OrderEntity>> createOrder({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required String storeId,
    required String storeName,
    required String storeAddress,
    required List<OrderItemEntity> items,
    required double deliveryFee,
    required double platformFee,
    String paymentMethod = 'COD',
  }) async {
    lastPassedDeliveryAddress = deliveryAddress;
    if (orderBuilder != null) {
      final custom = orderBuilder!(deliveryAddress);
      if (custom != null) return Right(custom);
    }
    return Right(OrderEntity(
      id: 'ord_1',
      orderNumber: 'QM-001',
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      storeId: storeId,
      storeName: storeName,
      storeAddress: storeAddress,
      items: items,
      subtotal: 100,
      deliveryFee: deliveryFee,
      platformFee: platformFee,
      grandTotal: 120,
      status: OrderStatus.placed,
      deliveryOtp: '4521',
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getCustomerOrders(String customerId) async => const Right([]);
  @override
  Future<Either<Failure, List<OrderEntity>>> getRetailerOrders(String storeId) async => const Right([]);
  @override
  Future<Either<Failure, List<OrderEntity>>> getDeliveryJobs(String deliveryPartnerId) async => const Right([]);
  @override
  Future<Either<Failure, List<OrderEntity>>> getAvailableDeliveryRequests() async => const Right([]);
  @override
  Future<Either<Failure, OrderEntity>> updateOrderStatus({required String orderId, required OrderStatus nextStatus, String? reason}) async => throw UnimplementedError();
  @override
  Future<Either<Failure, OrderEntity>> updatePaymentStatus({required String orderId, required String paymentStatus}) async => throw UnimplementedError();
  @override
  Future<Either<Failure, OrderEntity>> assignDeliveryPartner({required String orderId, required String deliveryPartnerId, required String deliveryPartnerName, required String deliveryPartnerPhone}) async => throw UnimplementedError();
  @override
  Future<Either<Failure, OrderEntity>> verifyDeliveryOtp({required String orderId, required String enteredOtp}) async => throw UnimplementedError();
  @override
  Future<Either<Failure, bool>> cancelOrder(String orderId, String reason) async => const Right(true);
  @override
  Future<Either<Failure, bool>> reviewOrder(String orderId, int storeRating, int deliveryRating, String comment) async => const Right(true);
  @override
  Future<Either<Failure, Map<String, dynamic>>> trackOrder(String orderId) async => const Right({});
}

void main() {
  late TestMockCatalogRepo fakeCatalog;
  late TestMockOrderRepo fakeOrderRepo;
  late TestMockCacheService fakeCache;
  late CustomerBloc bloc;

  setUp(() {
    fakeCatalog = TestMockCatalogRepo();
    fakeOrderRepo = TestMockOrderRepo();
    fakeCache = TestMockCacheService();

    bloc = CustomerBloc(
      catalogRepo: fakeCatalog,
      orderRepo: fakeOrderRepo,
      localCache: fakeCache,
    );
  });

  tearDown(() {
    bloc.close();
  });

  const testProduct = ProductEntity(
    id: 'prod_apple',
    storeId: 'store_01',
    name: 'Fresh Red Apples',
    description: 'Crisp apples',
    price: 100,
    unit: '1 kg',
    imageUrl: 'https://example.com/apple.jpg',
    categoryId: 'cat_fruits',
    stock: 10,
    isAvailable: true,
  );

  group('Order Confirmation Screen Delivery Address Verification', () {
    test('PlaceOrderEvent propagates explicit deliveryAddress to order and latestPlacedOrder', () async {
      const chosenAddress = 'Flat 402, Sunshine Apartments, 12th Main, Indiranagar, Bangalore 560038';

      // 1. Add item to cart so cart is non-empty
      bloc.add(const AddToCartEvent(testProduct));
      await Future.delayed(const Duration(milliseconds: 40));

      // 2. Place order with explicit deliveryAddress
      bloc.add(const PlaceOrderEvent(
        customerId: 'cust_01',
        customerName: 'Chetan',
        customerPhone: '+91 98765 43210',
        storeId: 'store_01',
        storeName: 'QuickMart Central',
        storeAddress: 'Indiranagar',
        deliveryAddress: chosenAddress,
        paymentMethod: 'COD',
      ));

      await expectLater(
        bloc.stream,
        emitsThrough(predicate<CustomerState>((s) {
          return s.latestPlacedOrder != null &&
              s.latestPlacedOrder!.deliveryAddress == chosenAddress;
        })),
      );

      expect(fakeOrderRepo.lastPassedDeliveryAddress, chosenAddress);
    });

    test('If orderRepo returns raw ObjectId or Default Address, latestPlacedOrder deliveryAddress is safely restored to displayAddress', () async {
      const chosenAddress = 'Villa 14, Palm Meadows, Whitefield, Bangalore';

      // 1. Add item to cart
      bloc.add(const AddToCartEvent(testProduct));
      await Future.delayed(const Duration(milliseconds: 40));

      fakeOrderRepo.orderBuilder = (addr) {
        return OrderEntity(
          id: 'ord_12346',
          orderNumber: 'QT-8888',
          customerId: 'cust_01',
          customerName: 'Chetan',
          customerPhone: '+91 98765 43210',
          deliveryAddress: '65f2a1b9c8d7e6f5a4b3c2d1', // Raw ObjectId returned from backend
          storeId: 'store_01',
          storeName: 'QuickMart Central',
          storeAddress: 'Indiranagar',
          items: const [],
          subtotal: 100,
          deliveryFee: 15,
          platformFee: 5,
          grandTotal: 120,
          status: OrderStatus.placed,
          deliveryOtp: '1234',
          paymentMethod: 'COD',
          paymentStatus: 'PENDING',
          createdAt: DateTime.now(),
        );
      };

      bloc.add(const PlaceOrderEvent(
        customerId: 'cust_01',
        customerName: 'Chetan',
        customerPhone: '+91 98765 43210',
        storeId: 'store_01',
        storeName: 'QuickMart Central',
        storeAddress: 'Indiranagar',
        deliveryAddress: chosenAddress,
        paymentMethod: 'COD',
      ));

      await expectLater(
        bloc.stream,
        emitsThrough(predicate<CustomerState>((s) {
          return s.latestPlacedOrder != null &&
              s.latestPlacedOrder!.deliveryAddress == chosenAddress;
        })),
      );
    });

    test('UpdateAddressEvent updates selectedAddress when active address is edited', () async {
      const oldAddress = CustomerAddressEntity(
        id: 'addr_100',
        label: 'HOME',
        line1: 'Old Street 1',
        city: 'Bangalore',
        state: 'Karnataka',
        pincode: '560001',
        lat: 12.97,
        lng: 77.59,
        isDefault: false,
      );

      const updatedAddress = CustomerAddressEntity(
        id: 'addr_100',
        label: 'HOME',
        line1: 'New Street 99',
        city: 'Bangalore',
        state: 'Karnataka',
        pincode: '560001',
        lat: 12.98,
        lng: 77.60,
        isDefault: false,
      );

      fakeCatalog.addresses.add(oldAddress);

      // Load addresses into state
      bloc.add(LoadAddressesEvent());
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<CustomerState>((s) => s.savedAddresses.isNotEmpty)),
      );

      // 1. Select old address
      bloc.add(SelectAddressEvent(oldAddress.formattedFullAddress));
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<CustomerState>((s) => s.selectedAddress == oldAddress.formattedFullAddress)),
      );

      // 2. Update the address
      bloc.add(const UpdateAddressEvent(addressId: 'addr_100', address: updatedAddress));
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<CustomerState>((s) => s.selectedAddress == updatedAddress.formattedFullAddress)),
      );
    });
  });
}
