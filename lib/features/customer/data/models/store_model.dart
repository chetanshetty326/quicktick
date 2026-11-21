import 'dart:math';
import '../../domain/entities/catalog_entities.dart';

class StoreModel extends StoreEntity {
  const StoreModel({
    required super.id,
    required super.name,
    required super.category,
    required super.address,
    required super.rating,
    required super.deliveryTime,
    required super.distanceKm,
    required super.isOpen,
    required super.bannerUrl,
    super.zoneId,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json, {double? userLat, double? userLng}) {
    // Address can be an object or string
    String formattedAddress = 'Local';
    if (json['address'] is Map) {
      final addr = json['address'] as Map;
      final line1 = addr['line1'] ?? '';
      final city = addr['city'] ?? '';
      formattedAddress = [line1, city].where((s) => s.isNotEmpty).join(', ');
    } else if (json['address'] is String) {
      formattedAddress = json['address'];
    }

    // Rating can be an object with average or a num
    double ratingVal = 4.5;
    if (json['rating'] is Map) {
      ratingVal = (json['rating']['average'] as num?)?.toDouble() ?? 4.5;
    } else if (json['rating'] is num) {
      final r = (json['rating'] as num).toDouble();
      ratingVal = r > 0 ? r : 4.5;
    }

    // Status parsing: check all closed/offline flags first before defaulting to open
    bool? parseBool(dynamic val) {
      if (val == null) return null;
      if (val is bool) return val;
      if (val is num) return val == 1;
      final s = val.toString().trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'open' || s == 'online' || s == 'active') return true;
      if (s == 'false' || s == '0' || s == 'closed' || s == 'offline' || s == 'inactive' || s == 'suspended' || s == 'disabled') return false;
      return null;
    }

    bool isStoreOpen = true;
    final isOpenBool = parseBool(json['isOpen']);
    final isStoreOpenBool = parseBool(json['isStoreOpen']);
    final isOnlineBool = parseBool(json['isOnline']);
    final storeStatusBool = parseBool(json['storeStatus']);
    final statusStr = json['status']?.toString().toUpperCase();

    if (isOpenBool == false ||
        isStoreOpenBool == false ||
        isOnlineBool == false ||
        storeStatusBool == false ||
        statusStr == 'CLOSED' ||
        statusStr == 'OFFLINE' ||
        statusStr == 'INACTIVE' ||
        statusStr == 'SUSPENDED' ||
        statusStr == 'DISABLED') {
      isStoreOpen = false;
    } else if (isOpenBool == true ||
        isStoreOpenBool == true ||
        isOnlineBool == true ||
        storeStatusBool == true ||
        statusStr == 'OPEN' ||
        statusStr == 'APPROVED' ||
        statusStr == 'ACTIVE') {
      isStoreOpen = true;
    }

    // Distance calculation: prioritize exact geospatial distance from user coordinates
    double dist = 1.0;
    if (userLat != null && userLng != null && json['location'] is Map) {
      final coords = json['location']['coordinates'];
      if (coords is List && coords.length >= 2) {
        final storeLng = (coords[0] as num?)?.toDouble() ?? 0.0;
        final storeLat = (coords[1] as num?)?.toDouble() ?? 0.0;
        if (storeLat != 0.0 && storeLng != 0.0) {
          dist = _calculateHaversine(userLat, userLng, storeLat, storeLng);
        }
      }
    } else if (json['distance'] != null) {
      dist = double.tryParse(json['distance'].toString()) ?? 1.0;
    } else if (json['distanceKm'] != null) {
      dist = (json['distanceKm'] as num).toDouble();
    }

    // Delivery time estimation: Express for <= 10km, Extended for > 10km
    final deliveryTimeStr = json['deliveryTime']?.toString() ??
        (dist <= 10.0
            ? '${(dist * 1.5 + 15).round()}-${(dist * 1.5 + 25).round()} min'
            : '${(dist * 1.2 + 20).round()}-${(dist * 1.2 + 30).round()} min');

    // Resolve storefront image from backend:
    // 1. Direct fields: shopPhotoUrl, storePhotoUrl, storeImageUrl, storeImage, imageUrl, photoUrl, bannerImage, bannerUrl, photo, image, logo
    String? resolvedBanner = json['shopPhotoUrl']?.toString() ??
        json['storePhotoUrl']?.toString() ??
        json['storeImageUrl']?.toString() ??
        json['storeImage']?.toString() ??
        json['imageUrl']?.toString() ??
        json['photoUrl']?.toString() ??
        json['bannerImage']?.toString() ??
        json['bannerUrl']?.toString() ??
        json['photo']?.toString() ??
        json['image']?.toString() ??
        json['logo']?.toString();

    // 2. Documents array lookup for SHOP_PHOTO or STOREFRONT
    if ((resolvedBanner == null || resolvedBanner.isEmpty) && json['documents'] is List) {
      for (final doc in json['documents']) {
        if (doc is Map) {
          final type = doc['type']?.toString().toUpperCase();
          final url = doc['url']?.toString();
          if ((type == 'SHOP_PHOTO' ||
                  type == 'STORE_PHOTO' ||
                  type == 'STOREFRONT' ||
                  type == 'STORE_FRONT') &&
              url != null &&
              url.isNotEmpty) {
            resolvedBanner = url;
            break;
          }
        }
      }
    }

    // 3. Nested retailer object lookup if any
    if ((resolvedBanner == null || resolvedBanner.isEmpty) && json['retailer'] is Map) {
      final rMap = json['retailer'] as Map;
      resolvedBanner = rMap['shopPhotoUrl']?.toString() ??
          rMap['storePhotoUrl']?.toString() ??
          rMap['imageUrl']?.toString() ??
          rMap['bannerImage']?.toString() ??
          rMap['bannerUrl']?.toString();
      if ((resolvedBanner == null || resolvedBanner.isEmpty) && rMap['documents'] is List) {
        for (final doc in rMap['documents']) {
          if (doc is Map) {
            final type = doc['type']?.toString().toUpperCase();
            final url = doc['url']?.toString();
            if ((type == 'SHOP_PHOTO' ||
                    type == 'STORE_PHOTO' ||
                    type == 'STOREFRONT' ||
                    type == 'STORE_FRONT') &&
                url != null &&
                url.isNotEmpty) {
              resolvedBanner = url;
              break;
            }
          }
        }
      }
    }

    final banner = (resolvedBanner != null && resolvedBanner.trim().isNotEmpty)
        ? resolvedBanner.trim()
        : 'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=500';

    final resolvedName = json['shopName']?.toString() ??
        json['name']?.toString() ??
        json['storeName']?.toString() ??
        'Local Store';

    String resolvedCategory = 'Groceries & Essentials';
    if (json['categories'] is List && (json['categories'] as List).isNotEmpty) {
      resolvedCategory = (json['categories'] as List).map((c) => c.toString()).join(', ');
    } else if (json['category'] != null) {
      resolvedCategory = json['category'].toString();
    }

    String? resolvedZoneId;
    if (json['zoneId'] is Map) {
      final zMap = json['zoneId'] as Map;
      resolvedZoneId = zMap['_id']?.toString() ?? zMap['id']?.toString() ?? zMap['zoneId']?.toString();
    } else if (json['zoneIdRaw'] != null) {
      resolvedZoneId = json['zoneIdRaw']?.toString();
    } else if (json['zoneId'] != null) {
      final s = json['zoneId'].toString().trim();
      resolvedZoneId = (s.isNotEmpty && s != '[object Object]') ? s : null;
    }
    resolvedZoneId ??= (json['zone'] is Map
        ? (json['zone']['_id']?.toString() ?? json['zone']['id']?.toString())
        : json['zone']?.toString());

    return StoreModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: resolvedName,
      category: resolvedCategory,
      address: formattedAddress,
      rating: ratingVal,
      deliveryTime: deliveryTimeStr,
      distanceKm: dist,
      isOpen: isStoreOpen,
      bannerUrl: banner,
      zoneId: resolvedZoneId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'address': address,
        'rating': rating,
        'deliveryTime': deliveryTime,
        'distanceKm': distanceKm,
        'isOpen': isOpen,
        'bannerUrl': bannerUrl,
        if (zoneId != null) 'zoneId': zoneId,
      };

  static double _calculateHaversine(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }
}
