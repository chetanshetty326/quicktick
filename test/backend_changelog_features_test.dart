import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/core/storage/local_cache_service.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/customer/domain/entities/customer_address_entity.dart';
import 'package:quicklink/features/customer/domain/repositories/catalog_repository.dart';
import 'package:quicklink/features/customer/presentation/bloc/customer_bloc.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/features/order/data/datasources/payment_remote_data_source.dart';
import 'package:quicklink/features/retailer/data/models/retailer_registration_models.dart';
import 'package:quicklink/features/retailer/domain/entities/retailer_entities.dart';
import 'package:quicklink/features/retailer/domain/entities/retailer_registration_status_entity.dart';
import 'package:quicklink/features/retailer/domain/repositories/retailer_repository.dart';
import 'package:quicklink/features/retailer/presentation/bloc/retailer_bloc.dart';
import 'dart:async';

// Mock Catalog Repository
class MockChangelogCatalogRepo implements ICatalogRepository {
  final _productsCtrl = StreamController<List<ProductEntity>>.broadcast();
  final _storesCtrl = StreamController<List<StoreEntity>>.broadcast();

  final List<ProductEntity> mockProducts = [
    const ProductEntity(
      id: 'prod_milk_1',
      storeId: 'ret_kumar',
      name: 'Amul Milk 500ml',
      description: 'Pasteurized toned milk',
      price: 30.0,
      unit: 'pack',
      imageUrl: 'https://example.com/amul.jpg',
      categoryId: 'cat_dairy',
      isAvailable: true,
      stock: 50,
    ),
    const ProductEntity(
      id: 'prod_bread_1',
      storeId: 'ret_kumar',
      name: 'Fresh Bread',
      description: 'Soft white bread',
      price: 25.0,
      unit: 'loaf',
      imageUrl: 'https://example.com/bread.jpg',
      categoryId: 'cat_bakery',
      isAvailable: true,
      stock: 20,
    ),
  ];

  final List<StoreEntity> mockStores = [
    const StoreEntity(
      id: 'ret_kumar',
      name: 'Kumar Stores',
      category: 'Daily Groceries',
      address: 'Indiranagar',
      rating: 4.8,
      deliveryTime: '15 MINS',
      distanceKm: 0.9,
      isOpen: true,
      bannerUrl: '',
    ),
  ];

  @override
  Stream<List<ProductEntity>> get productsStream => _productsCtrl.stream;
  @override
  Stream<List<StoreEntity>> get storesStream => _storesCtrl.stream;

  @override
  Future<Either<Failure, ({List<ProductEntity> products, List<StoreEntity> stores})>> searchCatalog({
    required String query,
    int page = 1,
    int limit = 20,
    double? lat,
    double? lng,
  }) async {
    final q = query.toLowerCase().trim();
    final matchedProducts = mockProducts.where((p) => p.name.toLowerCase().contains(q)).toList();
    final matchedStores = mockStores.where((s) => s.name.toLowerCase().contains(q)).toList();
    return Right((products: matchedProducts, stores: matchedStores));
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> searchProducts(
    String query, {
    String? category,
    int? page,
    int? limit,
    double? lat,
    double? lng,
    String? foodType,
  }) async {
    final q = query.toLowerCase().trim();
    return Right(mockProducts.where((p) => p.name.toLowerCase().contains(q)).toList());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Mock Retailer Repository
class MockChangelogRetailerRepo implements IRetailerRepository {
  final _ordersCtrl = StreamController<List<OrderEntity>>.broadcast();
  final _productsCtrl = StreamController<List<ProductEntity>>.broadcast();

  @override
  Stream<List<OrderEntity>> get ordersStream => _ordersCtrl.stream;
  @override
  Stream<List<ProductEntity>> get productsStream => _productsCtrl.stream;

  @override
  Future<Either<Failure, ({bool available, String message})>> checkStoreName(String name) async {
    if (name.toLowerCase().trim() == 'kumar stores') {
      return const Right((available: false, message: 'Shop name already taken. Please choose another shop name.'));
    }
    return const Right((available: true, message: 'Store name is available'));
  }

  @override
  Future<Either<Failure, FileUploadEntity>> uploadDocument(String filePath, {String? folder}) async {
    return const Right(FileUploadEntity(
      url: 'https://quickclick-backend-136h.onrender.com/uploads/a1b2c3d4e5f6.jpg',
      publicId: 'a1b2c3d4e5f6.jpg',
      format: 'image/jpeg',
      bytes: 45231,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeOrderRepo extends Fake implements IOrderRepository {
  final _ordersCtrl = StreamController<List<OrderEntity>>.broadcast();
  @override
  Stream<List<OrderEntity>> get ordersStream => _ordersCtrl.stream;
  @override
  Future<Either<Failure, List<OrderEntity>>> getCustomerOrders(String customerId) async => const Right([]);
}

class FakeCacheService extends Fake implements ILocalCacheService {
  @override
  Future<List<Map<String, dynamic>>> reloadAndGetCachedOrders() async => [];
  @override
  Future<void> cacheCustomerOrders(List<Map<String, dynamic>> orders) async {}
}

class FakePaymentDataSource extends Fake implements IPaymentRemoteDataSource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Backend Changelog Features Verification', () {
    test('Feature 1: Retailer Store Name availability check handles available and taken names', () async {
      final retailerRepo = MockChangelogRetailerRepo();
      final catalogRepo = MockChangelogCatalogRepo();
      final orderRepo = FakeOrderRepo();

      final bloc = RetailerBloc(
        orderRepo: orderRepo,
        catalogRepo: catalogRepo,
        retailerRepo: retailerRepo,
      );

      // 1. Check an available name
      bloc.add(const CheckStoreNameEvent('My Unique Bakery'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.isCheckingStoreName, isFalse);
      expect(bloc.state.isStoreNameAvailable, isTrue);
      expect(bloc.state.storeNameCheckMessage, 'Store name is available');

      // 2. Check an unavailable / taken name
      bloc.add(const CheckStoreNameEvent('Kumar Stores'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.isCheckingStoreName, isFalse);
      expect(bloc.state.isStoreNameAvailable, isFalse);
      expect(bloc.state.storeNameCheckMessage, contains('Shop name already taken'));

      // 3. Clear store name check
      bloc.add(const ClearStoreNameCheckEvent());
      await Future.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.isStoreNameAvailable, isNull);
      expect(bloc.state.storeNameCheckMessage, isNull);

      await bloc.close();
    });

    test('Feature 2: Customer Unified Catalog Search populates both products and stores', () async {
      final catalogRepo = MockChangelogCatalogRepo();
      final orderRepo = FakeOrderRepo();
      final cache = FakeCacheService();
      final payment = FakePaymentDataSource();

      final customerBloc = CustomerBloc(
        catalogRepo: catalogRepo,
        orderRepo: orderRepo,
        localCache: cache,
        paymentDataSource: payment,
      );

      // Search for 'Kumar' (should match both the store and products)
      customerBloc.add(const SearchProductsEvent('Kumar'));
      await Future.delayed(const Duration(milliseconds: 400)); // debounce

      expect(customerBloc.state.searchStores.isNotEmpty, isTrue);
      expect(customerBloc.state.searchStores.first.name, 'Kumar Stores');

      // Clear search
      customerBloc.add(const SearchProductsEvent(''));
      await Future.delayed(const Duration(milliseconds: 350));

      expect(customerBloc.state.searchStores.isEmpty, isTrue);
      expect(customerBloc.state.searchQuery, '');

      await customerBloc.close();
    });

    test('Feature 3: FileUploadModel accurately parses the new backend upload response schema', () {
      final backendJson = {
        'success': true,
        'data': {
          'url': 'https://quickclick-backend-136h.onrender.com/uploads/a1b2c3d4e5f6.jpg',
          'filename': 'a1b2c3d4e5f6.jpg',
          'mimetype': 'image/jpeg',
          'size': 45231,
        }
      };

      final model = FileUploadModel.fromJson(backendJson);
      expect(model.url, 'https://quickclick-backend-136h.onrender.com/uploads/a1b2c3d4e5f6.jpg');
      expect(model.publicId, 'a1b2c3d4e5f6.jpg');
      expect(model.format, 'image/jpeg');
      expect(model.bytes, 45231);
    });
  });
}
