import 'package:equatable/equatable.dart';

class CategoryEntity extends Equatable {
  final String id;
  final String name;
  final String icon;
  final String colorHex;
  final String slug;
  final String imageUrl;
  final String description;
  final bool isActive;
  final bool isFeatured;
  final int sortOrder;

  final String? foodType;
  final bool dietaryBadge;

  const CategoryEntity({
    required this.id,
    required this.name,
    this.icon = 'category',
    this.colorHex = '#2E7D32',
    this.slug = '',
    this.imageUrl = '',
    this.description = '',
    this.isActive = true,
    this.isFeatured = false,
    this.sortOrder = 0,
    this.foodType,
    this.dietaryBadge = false,
  });

  @override
  List<Object?> get props => [id, name, icon, colorHex, slug, imageUrl, description, isActive, isFeatured, sortOrder, foodType, dietaryBadge];
}

class StoreEntity extends Equatable {
  final String id;
  final String name;
  final String category;
  final String address;
  final double rating;
  final String deliveryTime;
  final double distanceKm;
  final bool isOpen;
  final String bannerUrl;
  final String? zoneId;

  const StoreEntity({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.rating,
    required this.deliveryTime,
    required this.distanceKm,
    required this.isOpen,
    required this.bannerUrl,
    this.zoneId,
  });

  /// True if store is within the quick-commerce 10km delivery radius
  bool get isExpress => distanceKm <= 10.0;

  StoreEntity copyWith({
    String? id,
    String? name,
    String? category,
    String? address,
    double? rating,
    String? deliveryTime,
    double? distanceKm,
    bool? isOpen,
    String? bannerUrl,
    String? zoneId,
  }) {
    return StoreEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      address: address ?? this.address,
      rating: rating ?? this.rating,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      distanceKm: distanceKm ?? this.distanceKm,
      isOpen: isOpen ?? this.isOpen,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      zoneId: zoneId ?? this.zoneId,
    );
  }

  @override
  List<Object?> get props => [id, name, category, address, rating, deliveryTime, distanceKm, isOpen, bannerUrl, zoneId];
}

class ProductEntity extends Equatable {
  final String id;
  final String storeId;
  final String? storeName;
  final String categoryId;
  final String? categoryName;
  final String name;
  final String description;
  final double price;
  final double? originalPrice;
  final String unit; // e.g. "500g", "1 L", "1 kg"
  final int stock;
  final bool isAvailable;
  final String imageUrl;
  final double? rating;
  final String? zoneId;
  final String? foodType;
  final String? barcode;
  final String? hsnCode;
  final double? taxPercent;

  const ProductEntity({
    required this.id,
    required this.storeId,
    this.storeName,
    required this.categoryId,
    this.categoryName,
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.unit,
    required this.stock,
    required this.isAvailable,
    required this.imageUrl,
    this.rating,
    this.zoneId,
    this.foodType,
    this.barcode,
    this.hsnCode,
    this.taxPercent,
  });

  ProductEntity copyWith({
    String? id,
    String? storeId,
    String? storeName,
    String? categoryId,
    String? categoryName,
    String? name,
    String? description,
    double? price,
    double? originalPrice,
    String? unit,
    int? stock,
    bool? isAvailable,
    String? imageUrl,
    double? rating,
    String? zoneId,
    String? foodType,
    String? barcode,
    String? hsnCode,
    double? taxPercent,
  }) {
    return ProductEntity(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      unit: unit ?? this.unit,
      stock: stock ?? this.stock,
      isAvailable: isAvailable ?? this.isAvailable,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      zoneId: zoneId ?? this.zoneId,
      foodType: foodType ?? this.foodType,
      barcode: barcode ?? this.barcode,
      hsnCode: hsnCode ?? this.hsnCode,
      taxPercent: taxPercent ?? this.taxPercent,
    );
  }

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
        'rating': rating,
        'zoneId': zoneId,
        if (foodType != null) 'foodType': foodType,
        if (barcode != null) 'barcode': barcode,
        if (hsnCode != null) 'hsnCode': hsnCode,
        if (taxPercent != null) 'taxPercent': taxPercent,
      };

  /// Domain business logic: Resolves dietary food type with fallback inference
  String get resolvedFoodType {
    if (foodType != null && foodType!.trim().isNotEmpty) {
      final f = foodType!.trim().toUpperCase();
      if (f.contains('NON') || f == 'NON_VEG') return 'NON_VEG';
      if (f == 'EGG') return 'EGG';
      if (f == 'VEG') return 'VEG';
    }
    final lowerName = name.toLowerCase();
    final lowerDesc = description.toLowerCase();

    // 1. Egg detection
    if (lowerName.contains('egg') ||
        lowerName.contains('anda') ||
        lowerName.contains('omlette') ||
        lowerDesc.contains('egg')) {
      return 'EGG';
    }

    // 2. Non-Veg detection
    if (lowerName.contains('chicken') ||
        lowerName.contains('chiken') ||
        lowerName.contains('mutton') ||
        lowerName.contains('meat') ||
        lowerName.contains('fish') ||
        lowerName.contains('koli') ||
        lowerName.contains('prawn') ||
        lowerName.contains('kabab') ||
        lowerName.contains('seafood') ||
        lowerDesc.contains('chicken') ||
        lowerDesc.contains('meat') ||
        lowerDesc.contains('fish')) {
      return 'NON_VEG';
    }

    // 3. Veg default
    return 'VEG';
  }

  /// Domain business logic: Matches dietary preference
  bool matchesDietaryPreference(String? preference) {
    if (preference == null || preference.isEmpty || preference.toUpperCase() == 'ALL') {
      return true;
    }
    return resolvedFoodType == preference.toUpperCase();
  }

  /// Domain business logic: Matches category with smart semantic inference for legacy null categories
  bool matchesCategory(String selectedCatId, List<CategoryEntity> categories) {
    if (selectedCatId == 'cat_all') return true;

    // Direct ID match
    if (categoryId.toLowerCase() == selectedCatId.toLowerCase() ||
        (categoryId.toLowerCase().replaceAll('cat_', '') == selectedCatId.toLowerCase().replaceAll('cat_', ''))) {
      return true;
    }

    // Direct Category Name match
    if (categoryName != null && categoryName!.toLowerCase() == selectedCatId.toLowerCase()) {
      return true;
    }

    // Check matching against category entity list
    final selectedCat = categories.firstWhere(
      (c) => c.id.toLowerCase() == selectedCatId.toLowerCase() || c.name.toLowerCase() == selectedCatId.toLowerCase(),
      orElse: () => CategoryEntity(id: selectedCatId, name: selectedCatId),
    );

    final catNameLower = selectedCat.name.toLowerCase();

    if (categoryName != null && categoryName!.toLowerCase() == catNameLower) {
      return true;
    }

    // Semantic keyword fallback for unlinked products
    final lowerName = name.toLowerCase();
    final lowerDesc = description.toLowerCase();

    if (catNameLower.contains('cold drink') || catNameLower.contains('juice') || catNameLower.contains('beverage')) {
      return lowerName.contains('7up') ||
          lowerName.contains('7 up') ||
          lowerName.contains('red bull') ||
          lowerName.contains('juice') ||
          lowerName.contains('soda') ||
          lowerName.contains('drink') ||
          lowerName.contains('water') ||
          lowerDesc.contains('drink') ||
          lowerDesc.contains('beverage');
    }

    if (catNameLower.contains('hot meal') || catNameLower.contains('biryani')) {
      return lowerName.contains('biriyani') ||
          lowerName.contains('biryani') ||
          lowerName.contains('mudde') ||
          lowerName.contains('roti') ||
          lowerName.contains('saaru') ||
          lowerName.contains('gheerice') ||
          lowerName.contains('rice') ||
          lowerName.contains('curry') ||
          lowerDesc.contains('biryani') ||
          lowerDesc.contains('meal');
    }

    if (catNameLower.contains('meat') || catNameLower.contains('poultry') || catNameLower.contains('fish')) {
      return lowerName.contains('chicken') ||
          lowerName.contains('chiken') ||
          lowerName.contains('koli') ||
          lowerName.contains('mutton') ||
          lowerName.contains('fish') ||
          lowerName.contains('prawn') ||
          lowerDesc.contains('chicken') ||
          lowerDesc.contains('meat');
    }

    if (catNameLower.contains('personal care') || catNameLower.contains('wellness')) {
      return lowerName.contains('patanjali') ||
          lowerName.contains('balm') ||
          lowerName.contains('hand wash') ||
          lowerName.contains('tulsi') ||
          lowerName.contains('soap') ||
          lowerName.contains('shampoo') ||
          lowerDesc.contains('wellness') ||
          lowerDesc.contains('ayurvedic');
    }

    if (catNameLower.contains('dairy') || catNameLower.contains('bread') || catNameLower.contains('egg')) {
      return lowerName.contains('milk') ||
          lowerName.contains('paneer') ||
          lowerName.contains('panner') ||
          lowerName.contains('curd') ||
          lowerName.contains('butter') ||
          lowerName.contains('cheese') ||
          lowerName.contains('bread') ||
          lowerName.contains('egg') ||
          lowerDesc.contains('dairy');
    }

    if (catNameLower.contains('snack') || catNameLower.contains('munch')) {
      return lowerName.contains('puff') ||
          lowerName.contains('chips') ||
          lowerName.contains('biscuit') ||
          lowerName.contains('snack') ||
          lowerName.contains('namkeen') ||
          lowerName.contains('cookie') ||
          lowerDesc.contains('snack');
    }

    if (catNameLower.contains('grocer') || catNameLower.contains('staple')) {
      return lowerName.contains('honey') ||
          lowerName.contains('oil') ||
          lowerName.contains('atta') ||
          lowerName.contains('flour') ||
          lowerName.contains('dal') ||
          lowerName.contains('sugar') ||
          lowerName.contains('salt') ||
          lowerName.contains('spice') ||
          lowerName.contains('masala') ||
          lowerDesc.contains('grocery');
    }

    if (catNameLower.contains('fruit') || catNameLower.contains('veg')) {
      return lowerName.contains('apple') ||
          lowerName.contains('banana') ||
          lowerName.contains('mango') ||
          lowerName.contains('onion') ||
          lowerName.contains('potato') ||
          lowerName.contains('tomato') ||
          lowerName.contains('chilli');
    }

    return false;
  }

  @override
  List<Object?> get props => [
        id,
        storeId,
        storeName,
        categoryId,
        categoryName,
        name,
        description,
        price,
        originalPrice,
        unit,
        stock,
        isAvailable,
        imageUrl,
        rating,
        zoneId,
        foodType,
        barcode,
        hsnCode,
        taxPercent,
      ];
}

class CustomerZoneEntity extends Equatable {
  final bool inZone;
  final String? zoneId;
  final String? zoneName;
  final String? message;
  final double? deliveryFee;
  final double? platformFee;
  final double? freeDeliveryThreshold;
  final double? minOrderAmount;

  const CustomerZoneEntity({
    required this.inZone,
    this.zoneId,
    this.zoneName,
    this.message,
    this.deliveryFee,
    this.platformFee,
    this.freeDeliveryThreshold,
    this.minOrderAmount,
  });

  @override
  List<Object?> get props => [
        inZone,
        zoneId,
        zoneName,
        message,
        deliveryFee,
        platformFee,
        freeDeliveryThreshold,
        minOrderAmount,
      ];
}

