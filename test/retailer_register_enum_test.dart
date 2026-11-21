import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/features/retailer/data/datasources/retailer_remote_data_source.dart';

void main() {
  group('Retailer Category Backend Enum Mapping Tests', () {
    test('UI categories correctly map to valid Mongoose backend enum', () {
      const allowedBackendEnums = {
        'General',
        'Grocery',
        'Pharmacy',
        'Restaurant',
        'Bakery',
        'Dairy',
        'Electronics',
        'Other',
      };

      final uiCategories = [
        'Restaurant (Dine-in / Cloud Kitchen)',
        'Grocery & Dark Store',
        'Bakery & Confectionery',
        'Cafe & Beverages',
        'Pharmacy & Wellness',
        'Fresh Meat & Seafood',
        'General Retail & Electronics',
        'Pet Supplies & Care',
      ];

      for (final cat in uiCategories) {
        final mapped = RetailerRemoteDataSourceImpl.mapCategoryToBackendEnum(cat);
        expect(allowedBackendEnums.contains(mapped), isTrue,
            reason: 'Category "$cat" mapped to "$mapped" which is not a valid backend enum!');
      }

      expect(RetailerRemoteDataSourceImpl.mapCategoryToBackendEnum('Restaurant (Dine-in / Cloud Kitchen)'), 'Restaurant');
      expect(RetailerRemoteDataSourceImpl.mapCategoryToBackendEnum('Grocery & Dark Store'), 'Grocery');
      expect(RetailerRemoteDataSourceImpl.mapCategoryToBackendEnum('Pharmacy & Wellness'), 'Pharmacy');
      expect(RetailerRemoteDataSourceImpl.mapCategoryToBackendEnum('Bakery & Confectionery'), 'Bakery');
      expect(RetailerRemoteDataSourceImpl.mapCategoryToBackendEnum('General Retail & Electronics'), 'Electronics');
    });
  });
}
