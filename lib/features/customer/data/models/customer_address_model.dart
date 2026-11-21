import '../../domain/entities/customer_address_entity.dart';

class CustomerAddressModel extends CustomerAddressEntity {
  const CustomerAddressModel({
    super.id = '',
    required super.label,
    required super.line1,
    super.line2,
    super.landmark,
    required super.city,
    required super.state,
    required super.pincode,
    required super.lat,
    required super.lng,
    super.isDefault,
    super.contactName,
    super.contactPhone,
    super.deliveryInstructions,
  });

  factory CustomerAddressModel.fromJson(Map<String, dynamic> json) {
    double latitude = (json['latitude'] as num?)?.toDouble() ?? 12.9716;
    double longitude = (json['longitude'] as num?)?.toDouble() ?? 77.5946;

    if (json['location'] is Map) {
      final loc = json['location'] as Map;
      if (loc['coordinates'] is List && (loc['coordinates'] as List).length >= 2) {
        longitude = ((loc['coordinates'] as List)[0] as num).toDouble();
        latitude = ((loc['coordinates'] as List)[1] as num).toDouble();
      } else if (loc['lat'] != null && loc['lng'] != null) {
        latitude = (loc['lat'] as num).toDouble();
        longitude = (loc['lng'] as num).toDouble();
      }
    }

    String? name;
    String? phone;
    if (json['contact'] is Map) {
      name = json['contact']['name']?.toString();
      phone = json['contact']['phone']?.toString();
    }

    final addrStr = json['address']?.toString() ?? json['line1']?.toString() ?? '';

    return CustomerAddressModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? json['type']?.toString() ?? 'HOME',
      line1: addrStr,
      line2: json['floor']?.toString() ?? json['line2']?.toString(),
      landmark: json['landmark']?.toString(),
      city: json['city']?.toString() ?? 'Bangalore',
      state: json['state']?.toString() ?? 'Karnataka',
      pincode: json['pincode']?.toString() ?? json['postalCode']?.toString() ?? '560001',
      lat: latitude,
      lng: longitude,
      isDefault: json['isDefault'] == true,
      contactName: name,
      contactPhone: phone,
      deliveryInstructions: json['instructions']?.toString() ?? json['deliveryInstructions']?.toString(),
    );
  }

  Map<String, dynamic> toCreateJson() => {
        'address': line1,
        'latitude': lat,
        'longitude': lng,
        'type': (label.toUpperCase() == 'WORK' || label.toUpperCase() == 'OFFICE') ? 'WORK' : 'HOME',
        'label': label,
        'floor': line2 ?? '',
        'instructions': deliveryInstructions ?? 'Call before delivery',
        'isDefault': isDefault,
        // Legacy keys for fallback compatibility
        'line1': line1,
        'city': city,
        'state': state,
        'pincode': pincode,
        'postalCode': pincode,
        'location': {
          'lat': lat,
          'lng': lng,
        },
      };
}
