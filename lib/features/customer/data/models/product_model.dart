import '../../domain/entities/catalog_entities.dart';

class ProductModel extends ProductEntity {
  const ProductModel({
    required super.id,
    required super.storeId,
    super.storeName,
    required super.categoryId,
    super.categoryName,
    required super.name,
    required super.description,
    required super.price,
    super.originalPrice,
    required super.unit,
    required super.stock,
    required super.isAvailable,
    required super.imageUrl,
    super.rating,
    super.zoneId,
    super.foodType,
    super.barcode,
    super.hsnCode,
    super.taxPercent,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // StoreId, StoreName, and ZoneId can be a String or nested object (storeId or retailerId)
    String sId = '';
    String? sName;
    String? zId;
    if (json['retailerId'] is Map) {
      sId = json['retailerId']['_id']?.toString() ?? json['retailerId']['id']?.toString() ?? '';
      sName = json['retailerId']['shopName']?.toString() ?? json['retailerId']['name']?.toString();
      zId = json['retailerId']['zoneId']?.toString();
    } else if (json['retailerId'] is String) {
      sId = json['retailerId'];
    } else if (json['storeId'] is Map) {
      sId = json['storeId']['_id']?.toString() ?? json['storeId']['id']?.toString() ?? '';
      sName = json['storeId']['shopName']?.toString() ?? json['storeId']['name']?.toString();
      zId = json['storeId']['zoneId']?.toString();
    } else if (json['storeId'] is String) {
      sId = json['storeId'];
    }
    if (sName == null && json['storeName'] != null) {
      sName = json['storeName'].toString();
    }

    // Category: Extract categoryId (ID) and categoryName (Name)
    String catId = 'cat_all';
    String? catName;
    if (json['categoryId'] is Map) {
      catId = json['categoryId']['_id']?.toString() ??
          json['categoryId']['id']?.toString() ??
          'cat_all';
      catName = json['categoryId']['name']?.toString();
    } else if (json['categoryId'] != null) {
      catId = json['categoryId'].toString();
    } else if (json['category'] != null) {
      if (json['category'] is Map) {
        catId = json['category']['_id']?.toString() ??
            json['category']['id']?.toString() ??
            'cat_all';
        catName = json['category']['name']?.toString();
      } else {
        final catStr = json['category'].toString();
        if (RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(catStr)) {
          catId = catStr;
        } else {
          catName = catStr;
          catId = catStr;
        }
      }
    }

    // Stock & Availability
    final stockVal = (json['stockQty'] as num?)?.toInt() ??
        (json['stock'] as num?)?.toInt() ??
        (json['quantity'] as num?)?.toInt() ??
        0;
    final stockStatus = json['status']?.toString().toUpperCase() ?? json['stockStatus']?.toString().toUpperCase();
    final bool available = (stockStatus == null || stockStatus == 'ACTIVE' || stockStatus == 'IN_STOCK') &&
        (json['isAvailable'] != false) &&
        stockVal > 0;

    // Image extraction helper
    String extractUrl(dynamic val) {
      if (val == null) return '';
      if (val is String) return val.trim();
      if (val is Map) {
        final u = val['url'] ?? val['secure_url'] ?? val['imageUrl'] ?? val['fileUrl'] ?? val['path'];
        if (u != null && u.toString().trim().isNotEmpty) {
          return u.toString().trim();
        }
      }
      if (val is List && val.isNotEmpty) {
        return extractUrl(val.first);
      }
      return '';
    }

    String img = extractUrl(json['imageUrl']);
    if (img.isEmpty) {
      img = extractUrl(json['image']);
    }
    if (img.isEmpty) {
      img = extractUrl(json['images']);
    }

    if (img.isEmpty) {
      final nameLower = (json['name']?.toString() ?? '').toLowerCase();
      if (nameLower.contains('milk') || nameLower.contains('dairy')) {
        img = 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400&q=80';
      } else if (nameLower.contains('bread') || nameLower.contains('bakery') || nameLower.contains('toast')) {
        img = 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400&q=80';
      } else if (nameLower.contains('apple') || nameLower.contains('fruit') || nameLower.contains('banana')) {
        img = 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=400&q=80';
      } else if (nameLower.contains('egg')) {
        img = 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=400&q=80';
      } else if (nameLower.contains('snack') || nameLower.contains('chips') || nameLower.contains('biscuit')) {
        img = 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=400&q=80';
      } else {
        img = 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400&q=80';
      }
    }

    // Pricing
    final currentPrice = (json['price'] as num?)?.toDouble() ?? 0.0;
    final mrpPrice = (json['mrp'] as num?)?.toDouble() ?? (json['originalPrice'] as num?)?.toDouble();
    final discountPrice = (json['discountPrice'] as num?)?.toDouble();

    // Selling price: currentPrice (or discountPrice if valid and lower than currentPrice)
    double finalPrice = currentPrice;
    if (discountPrice != null && discountPrice > 0 && discountPrice < currentPrice) {
      finalPrice = discountPrice;
    } else if (finalPrice == 0.0 && discountPrice != null && discountPrice > 0) {
      finalPrice = discountPrice;
    }

    // Strike-through original MRP price (if higher than selling price)
    double? originalPrice = mrpPrice;
    if (originalPrice == null || originalPrice <= finalPrice) {
      if (discountPrice != null && discountPrice < currentPrice && currentPrice > finalPrice) {
        originalPrice = currentPrice;
      } else {
        originalPrice = null;
      }
    }

    return ProductModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      storeId: sId,
      storeName: sName,
      categoryId: catId,
      categoryName: catName,
      name: json['name']?.toString() ?? 'Essential Product',
      description: json['description']?.toString() ?? '',
      price: finalPrice,
      originalPrice: originalPrice,
      unit: json['unit']?.toString() ?? '1 unit',
      stock: stockVal,
      isAvailable: available,
      imageUrl: img,
      zoneId: json['zoneId']?.toString() ?? zId,
      foodType: json['foodType']?.toString(),
      barcode: json['barcode']?.toString(),
      hsnCode: json['hsnCode']?.toString(),
      taxPercent: (json['taxPercent'] as num?)?.toDouble(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'storeId': storeId,
        'storeName': storeName,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'name': name,
        'description': description,
        'price': price,
        'originalPrice': originalPrice,
        'unit': unit,
        'stock': stock,
        'isAvailable': isAvailable,
        'imageUrl': imageUrl,
        'foodType': foodType,
        if (barcode != null) 'barcode': barcode,
        if (hsnCode != null) 'hsnCode': hsnCode,
        if (taxPercent != null) 'taxPercent': taxPercent,
      };
}
