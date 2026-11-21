import 'package:equatable/equatable.dart';

class CustomerAddressEntity extends Equatable {
  final String id;
  final String label; // 'HOME', 'WORK', 'OTHER'
  final String line1;
  final String? line2;
  final String? landmark;
  final String city;
  final String state;
  final String pincode;
  final double lat;
  final double lng;
  final bool isDefault;
  final String? contactName;
  final String? contactPhone;
  final String? deliveryInstructions;

  const CustomerAddressEntity({
    this.id = '',
    required this.label,
    required this.line1,
    this.line2,
    this.landmark,
    required this.city,
    required this.state,
    required this.pincode,
    required this.lat,
    required this.lng,
    this.isDefault = false,
    this.contactName,
    this.contactPhone,
    this.deliveryInstructions,
  });

  bool get hasValidServerId => RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(id);

  String get formattedFullAddress {
    final parts = [line1, line2, landmark, '$city, $state $pincode']
        .where((p) => p != null && p.trim().isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  CustomerAddressEntity copyWith({
    String? id,
    String? label,
    String? line1,
    String? line2,
    String? landmark,
    String? city,
    String? state,
    String? pincode,
    double? lat,
    double? lng,
    bool? isDefault,
    String? contactName,
    String? contactPhone,
    String? deliveryInstructions,
  }) {
    return CustomerAddressEntity(
      id: id ?? this.id,
      label: label ?? this.label,
      line1: line1 ?? this.line1,
      line2: line2 ?? this.line2,
      landmark: landmark ?? this.landmark,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      isDefault: isDefault ?? this.isDefault,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
    );
  }

  bool isSameLocationAs(CustomerAddressEntity other) {
    if (id.isNotEmpty && other.id.isNotEmpty && id == other.id) return true;
    final sameLabel = label.toUpperCase().trim() == other.label.toUpperCase().trim();
    final sameLine1 = line1.trim().toLowerCase() == other.line1.trim().toLowerCase();
    final samePincode = pincode.trim() == other.pincode.trim();
    final closeCoords = (lat - other.lat).abs() < 0.0015 && (lng - other.lng).abs() < 0.0015;

    // Both CURRENT or matching line1 with close coords or matching line1+pincode
    if (sameLabel && label.toUpperCase().trim() == 'CURRENT') return true;
    return (sameLabel && sameLine1 && samePincode) || (sameLine1 && closeCoords);
  }

  static List<CustomerAddressEntity> deduplicate(List<CustomerAddressEntity> list) {
    final List<CustomerAddressEntity> unique = [];
    for (final addr in list) {
      final existingIndex = unique.indexWhere((u) => u.isSameLocationAs(addr));
      if (existingIndex == -1) {
        unique.add(addr);
      } else {
        // If the duplicate has default true or is newer, maintain default flag
        if (addr.isDefault && !unique[existingIndex].isDefault) {
          unique[existingIndex] = addr;
        }
      }
    }
    return unique;
  }

  @override
  List<Object?> get props => [
        id,
        label,
        line1,
        line2,
        landmark,
        city,
        state,
        pincode,
        lat,
        lng,
        isDefault,
        contactName,
        contactPhone,
        deliveryInstructions,
      ];
}
