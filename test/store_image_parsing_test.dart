import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/features/customer/data/models/store_model.dart';
import 'package:quicklink/features/retailer/data/datasources/retailer_remote_data_source.dart';
import 'package:quicklink/core/network/api_client.dart';
import 'package:dio/dio.dart';

import 'package:quicklink/core/security/secure_storage_service.dart';

class FakeSecureStorage extends Fake implements SecureStorageService {}

void main() {
  group('Store Image / Shop Photo Parsing Tests', () {
    test('StoreModel.fromJson resolves shopPhotoUrl as bannerUrl', () {
      final json = {
        '_id': 'store_123',
        'shopName': 'Chamundi Bakery',
        'category': 'Bakery',
        'shopPhotoUrl': 'https://res.cloudinary.com/sh2mu8mw/image/upload/v1792230216/quickclick/jkdn1knnfulaa70pvoya.jpg',
        'address': {
          'line1': 'MG Road',
          'city': 'Bengaluru',
        },
      };

      final store = StoreModel.fromJson(json);

      expect(store.id, equals('store_123'));
      expect(store.name, equals('Chamundi Bakery'));
      expect(
        store.bannerUrl,
        equals('https://res.cloudinary.com/sh2mu8mw/image/upload/v1792230216/quickclick/jkdn1knnfulaa70pvoya.jpg'),
      );
    });

    test('StoreModel.fromJson resolves SHOP_PHOTO from documents array when shopPhotoUrl is missing', () {
      final json = {
        '_id': 'store_456',
        'shopName': 'Namma Groceries',
        'category': 'Grocery',
        'documents': [
          {
            'type': 'PAN',
            'url': 'https://res.cloudinary.com/demo/pan.jpg',
          },
          {
            'type': 'SHOP_PHOTO',
            'url': 'https://res.cloudinary.com/demo/storefront_facade.jpg',
          },
        ],
      };

      final store = StoreModel.fromJson(json);

      expect(store.name, equals('Namma Groceries'));
      expect(
        store.bannerUrl,
        equals('https://res.cloudinary.com/demo/storefront_facade.jpg'),
      );
    });

    test('StoreModel.fromJson resolves nested retailer shopPhotoUrl', () {
      final json = {
        '_id': 'store_789',
        'retailer': {
          'shopName': 'Express Mart',
          'shopPhotoUrl': 'https://res.cloudinary.com/demo/express_store.png',
        },
      };

      final store = StoreModel.fromJson(json);

      expect(
        store.bannerUrl,
        equals('https://res.cloudinary.com/demo/express_store.png'),
      );
    });

    test('RetailerRemoteDataSourceImpl._parseStoreProfile resolves shopPhotoUrl', () {
      final apiClient = ApiClient(dio: Dio(), secureStorage: FakeSecureStorage());
      final ds = RetailerRemoteDataSourceImpl(apiClient);

      final json = {
        '_id': 'retailer_001',
        'shopName': 'My Store',
        'shopPhotoUrl': 'https://res.cloudinary.com/demo/my_store_front.png',
        'ownerName': 'Ramesh',
        'phone': '9876543210',
      };

      final profile = ds.parseStoreProfileForTesting(json);

      expect(profile.storeName, equals('My Store'));
      expect(profile.shopPhotoUrl, equals('https://res.cloudinary.com/demo/my_store_front.png'));
    });
  });
}
