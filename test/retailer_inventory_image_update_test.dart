import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/features/customer/data/models/product_model.dart';
import 'package:quicklink/features/retailer/data/models/retailer_registration_models.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';

void main() {
  group('Retailer Inventory & Stock Image Updates', () {
    test('ProductModel parses various backend image schemas without falling back', () {
      // 1. Direct imageUrl string
      final p1 = ProductModel.fromJson({
        '_id': 'prod_001',
        'name': 'Fresh Apples',
        'price': 120,
        'imageUrl': 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
      });
      expect(p1.imageUrl, 'https://res.cloudinary.com/demo/image/upload/sample.jpg');

      // 2. Field named "image" (string)
      final p2 = ProductModel.fromJson({
        '_id': 'prod_002',
        'name': 'Organic Milk',
        'price': 65,
        'image': 'https://res.cloudinary.com/demo/image/upload/milk.jpg',
      });
      expect(p2.imageUrl, 'https://res.cloudinary.com/demo/image/upload/milk.jpg');

      // 3. Field named "images" (array of strings)
      final p3 = ProductModel.fromJson({
        '_id': 'prod_003',
        'name': 'Whole Bread',
        'price': 40,
        'images': ['https://res.cloudinary.com/demo/image/upload/bread1.jpg', 'https://res.cloudinary.com/demo/image/upload/bread2.jpg'],
      });
      expect(p3.imageUrl, 'https://res.cloudinary.com/demo/image/upload/bread1.jpg');

      // 4. Nested object in "image" with "url"
      final p4 = ProductModel.fromJson({
        '_id': 'prod_004',
        'name': 'Greek Yogurt',
        'price': 90,
        'image': {'url': 'https://res.cloudinary.com/demo/image/upload/yogurt.jpg'},
      });
      expect(p4.imageUrl, 'https://res.cloudinary.com/demo/image/upload/yogurt.jpg');

      // 5. Nested object in "imageUrl" with "secure_url"
      final p5 = ProductModel.fromJson({
        '_id': 'prod_005',
        'name': 'Eggs 12pk',
        'price': 85,
        'imageUrl': {'secure_url': 'https://res.cloudinary.com/demo/image/upload/eggs.jpg'},
      });
      expect(p5.imageUrl, 'https://res.cloudinary.com/demo/image/upload/eggs.jpg');
    });

    test('FileUploadModel.fromJson handles Cloudinary and custom S3 upload payloads', () {
      // 1. Direct Cloudinary response with secure_url
      final upload1 = FileUploadModel.fromJson({
        'secure_url': 'https://res.cloudinary.com/demo/image/upload/v1234/test.png',
        'public_id': 'v1234/test',
      });
      expect(upload1.url, 'https://res.cloudinary.com/demo/image/upload/v1234/test.png');

      // 2. Wrapped under data.file
      final upload2 = FileUploadModel.fromJson({
        'status': 'success',
        'data': {
          'file': {
            'url': 'https://res.cloudinary.com/demo/image/upload/v5678/test2.png',
            'public_id': 'v5678/test2',
          },
        },
      });
      expect(upload2.url, 'https://res.cloudinary.com/demo/image/upload/v5678/test2.png');

      // 3. Standard file payload with fileUrl
      final upload3 = FileUploadModel.fromJson({
        'fileUrl': 'https://s3.amazonaws.com/mybucket/item.jpg',
        'fileName': 'item.jpg',
      });
      expect(upload3.url, 'https://s3.amazonaws.com/mybucket/item.jpg');
    });

    test('Updating stock image in product list updates existing product in-place', () {
      final initialProducts = [
        const ProductEntity(
          id: 'prod_101',
          name: 'Classic Potato Chips',
          description: 'Crunchy potato chips',
          price: 20,
          originalPrice: 20,
          unit: 'pack',
          stock: 50,
          isAvailable: true,
          imageUrl: 'https://images.unsplash.com/chips_old.jpg',
          storeId: 'store_1',
          categoryId: 'snacks',
        ),
        const ProductEntity(
          id: 'prod_102',
          name: 'Dark Chocolate',
          description: 'Dark chocolate bar',
          price: 100,
          originalPrice: 120,
          unit: 'bar',
          stock: 15,
          isAvailable: true,
          imageUrl: 'https://images.unsplash.com/chocolate.jpg',
          storeId: 'store_1',
          categoryId: 'snacks',
        ),
      ];

      final updatedProduct = initialProducts[0].copyWith(
        imageUrl: 'https://res.cloudinary.com/demo/image/upload/new_chips.jpg',
        price: 25,
      );

      final list = List<ProductEntity>.from(initialProducts);
      final idx = list.indexWhere((p) => p.id == updatedProduct.id);
      expect(idx, 0);

      list[idx] = updatedProduct;
      expect(list.length, 2);
      expect(list[0].imageUrl, 'https://res.cloudinary.com/demo/image/upload/new_chips.jpg');
      expect(list[0].price, 25);
      expect(list[1].imageUrl, 'https://images.unsplash.com/chocolate.jpg');
    });
  });
}
