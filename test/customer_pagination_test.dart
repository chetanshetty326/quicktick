import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/core/storage/local_cache_service.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/customer/domain/entities/customer_address_entity.dart';
import 'package:quicklink/features/customer/domain/repositories/catalog_repository.dart';
import 'package:quicklink/features/customer/presentation/bloc/customer_bloc.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';

class FakePaginationCatalogRepo extends Fake implements ICatalogRepository {
  @override
  Stream<List<ProductEntity>> get productsStream => const Stream.empty();
  @override
  Stream<List<StoreEntity>> get storesStream => const Stream.empty();

  int lastRequestedPage = 0;

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories() async =>
      const Right([CategoryEntity(id: 'cat_all', name: 'All', icon: '', colorHex: '#000000')]);

  @override
  Future<Either<Failure, List<ProductEntity>>> searchProducts(
    String query, {
    String? category,
    int? page,
    int? limit,
  }) async {
    lastRequestedPage = page ?? 1;
    if (lastRequestedPage == 1) {
      return Right(List.generate(
        20,
        (i) => ProductEntity(
          id: 'prod_$i',
          storeId: 's1',
          name: 'Product $i',
          description: '',
          price: 10.0 + i,
          unit: '1 pc',
          imageUrl: '',
          categoryId: 'cat_all',
          isAvailable: true,
          stock: 10,
        ),
      ));
    } else if (lastRequestedPage == 2) {
      return Right(List.generate(
        5,
        (i) => ProductEntity(
          id: 'prod_p2_$i',
          storeId: 's1',
          name: 'Product Page 2 - $i',
          description: '',
          price: 20.0 + i,
          unit: '1 pc',
          imageUrl: '',
          categoryId: 'cat_all',
          isAvailable: true,
          stock: 5,
        ),
      ));
    }
    return const Right([]);
  }

  @override
  Future<Either<Failure, List<StoreEntity>>> getNearbyStores({double? lat, double? lng}) async =>
      const Right([]);

  @override
  Future<Either<Failure, List<CustomerAddressEntity>>> getAddresses() async =>
      const Right([]);
}

class FakePaginationOrderRepo extends Fake implements IOrderRepository {
  @override
  Stream<List<OrderEntity>> get ordersStream => const Stream.empty();
  @override
  Future<Either<Failure, List<OrderEntity>>> getCustomerOrders(String customerId) async =>
      const Right([]);
}

class FakePaginationLocalCache extends Fake implements ILocalCacheService {
  @override
  List<Map<String, dynamic>> getCartItems() => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('LoadMoreProductsEvent requests next page and appends products without resetting existing list', () async {
    final catalogRepo = FakePaginationCatalogRepo();
    final bloc = CustomerBloc(
      catalogRepo: catalogRepo,
      orderRepo: FakePaginationOrderRepo(),
      localCache: FakePaginationLocalCache(),
    );

    // Initial load
    bloc.add(const LoadCustomerDataEvent());
    await Future.delayed(const Duration(milliseconds: 30));

    expect(bloc.state.allProducts.length, 20);
    expect(bloc.state.currentPage, 1);
    expect(bloc.state.hasReachedMaxProducts, isFalse);

    // Load next page
    bloc.add(const LoadMoreProductsEvent());
    await Future.delayed(const Duration(milliseconds: 30));

    expect(catalogRepo.lastRequestedPage, 2);
    expect(bloc.state.allProducts.length, 25); // 20 + 5 from page 2
    expect(bloc.state.currentPage, 2);
    expect(bloc.state.hasReachedMaxProducts, isTrue); // < 20 items returned

    await bloc.close();
  });
}
