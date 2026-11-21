import 'package:equatable/equatable.dart';

enum KYCStatus { unsubmitted, underReview, verified, rejected }

enum DeliveryTripStep {
  enRouteStore,
  atStore,
  orderPickedUp,
  enRouteCustomer,
  atCustomer,
  completed,
}

class RiderKYCEntity extends Equatable {
  final String riderId;
  final String fullName;
  final String phone;
  final String emergencyPhone;
  final String emergencyRelation;
  
  // Home Address Details
  final String houseNo;
  final String street;
  final String landmark;
  final String city;
  final String state;
  final String pincode;

  // Identity & Compliance
  final String aadhaarNumber;
  final bool isAadhaarVerified;
  final String dlNumber;
  final String dlExpiryDate;
  final String vehicleType;
  final String vehicleNumber;

  // Bank & UPI Payout Info
  final String bankAccount;
  final String ifscCode;
  final String upiId;

  // Biometrics
  final String faceProfilePhotoUrl;
  final bool isFaceEnrolled;
  final KYCStatus kycStatus;

  // Location & Zone Details
  final double? latitude;
  final double? longitude;
  final String? zoneId;
  final String? zoneName;

  const RiderKYCEntity({
    this.riderId = '',
    this.fullName = '',
    this.phone = '',
    this.emergencyPhone = '',
    this.emergencyRelation = '',
    this.houseNo = '',
    this.street = '',
    this.landmark = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.aadhaarNumber = '',
    this.isAadhaarVerified = false,
    this.dlNumber = '',
    this.dlExpiryDate = '',
    this.vehicleType = '',
    this.vehicleNumber = '',
    this.bankAccount = '',
    this.ifscCode = '',
    this.upiId = '',
    this.faceProfilePhotoUrl = '',
    this.isFaceEnrolled = false,
    this.kycStatus = KYCStatus.unsubmitted,
    this.latitude,
    this.longitude,
    this.zoneId,
    this.zoneName,
  });

  String get fullAddress {
    final parts = [houseNo, street, landmark, city, state].where((s) => s.trim().isNotEmpty).toList();
    if (parts.isEmpty) return '';
    final addr = parts.join(', ');
    return pincode.trim().isNotEmpty ? '$addr - $pincode' : addr;
  }

  String get maskedAadhaar {
    final clean = aadhaarNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length >= 12) {
      return 'XXXX-XXXX-${clean.substring(clean.length - 4)}';
    }
    return clean;
  }

  RiderKYCEntity copyWith({
    String? riderId,
    String? fullName,
    String? phone,
    String? emergencyPhone,
    String? emergencyRelation,
    String? houseNo,
    String? street,
    String? landmark,
    String? city,
    String? state,
    String? pincode,
    String? aadhaarNumber,
    bool? isAadhaarVerified,
    String? dlNumber,
    String? dlExpiryDate,
    String? vehicleType,
    String? vehicleNumber,
    String? bankAccount,
    String? ifscCode,
    String? upiId,
    String? faceProfilePhotoUrl,
    bool? isFaceEnrolled,
    KYCStatus? kycStatus,
    double? latitude,
    double? longitude,
    String? zoneId,
    String? zoneName,
  }) {
    return RiderKYCEntity(
      riderId: riderId ?? this.riderId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      emergencyRelation: emergencyRelation ?? this.emergencyRelation,
      houseNo: houseNo ?? this.houseNo,
      street: street ?? this.street,
      landmark: landmark ?? this.landmark,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      isAadhaarVerified: isAadhaarVerified ?? this.isAadhaarVerified,
      dlNumber: dlNumber ?? this.dlNumber,
      dlExpiryDate: dlExpiryDate ?? this.dlExpiryDate,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      bankAccount: bankAccount ?? this.bankAccount,
      ifscCode: ifscCode ?? this.ifscCode,
      upiId: upiId ?? this.upiId,
      faceProfilePhotoUrl: faceProfilePhotoUrl ?? this.faceProfilePhotoUrl,
      isFaceEnrolled: isFaceEnrolled ?? this.isFaceEnrolled,
      kycStatus: kycStatus ?? this.kycStatus,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      zoneId: zoneId ?? this.zoneId,
      zoneName: zoneName ?? this.zoneName,
    );
  }

  Map<String, dynamic> toJson() => {
        'riderId': riderId,
        'fullName': fullName,
        'phone': phone,
        'emergencyPhone': emergencyPhone,
        'emergencyRelation': emergencyRelation,
        'houseNo': houseNo,
        'street': street,
        'landmark': landmark,
        'city': city,
        'state': state,
        'pincode': pincode,
        'aadhaarNumber': aadhaarNumber,
        'isAadhaarVerified': isAadhaarVerified,
        'dlNumber': dlNumber,
        'dlExpiryDate': dlExpiryDate,
        'vehicleType': vehicleType,
        'vehicleNumber': vehicleNumber,
        'bankAccount': bankAccount,
        'ifscCode': ifscCode,
        'upiId': upiId,
        'faceProfilePhotoUrl': faceProfilePhotoUrl,
        'isFaceEnrolled': isFaceEnrolled,
        'kycStatus': kycStatus.name,
        'latitude': latitude,
        'longitude': longitude,
        'zoneId': zoneId,
        'zoneName': zoneName,
      };

  factory RiderKYCEntity.fromJson(Map<String, dynamic> json) => RiderKYCEntity(
        riderId: json['riderId']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        emergencyPhone: json['emergencyPhone']?.toString() ?? '',
        emergencyRelation: json['emergencyRelation']?.toString() ?? '',
        houseNo: json['houseNo']?.toString() ?? '',
        street: json['street']?.toString() ?? '',
        landmark: json['landmark']?.toString() ?? '',
        city: json['city']?.toString() ?? '',
        state: json['state']?.toString() ?? '',
        pincode: json['pincode']?.toString() ?? '',
        aadhaarNumber: json['aadhaarNumber']?.toString() ?? '',
        isAadhaarVerified: json['isAadhaarVerified'] == true,
        dlNumber: json['dlNumber']?.toString() ?? '',
        dlExpiryDate: json['dlExpiryDate']?.toString() ?? '',
        vehicleType: json['vehicleType']?.toString() ?? '',
        vehicleNumber: json['vehicleNumber']?.toString() ?? '',
        bankAccount: json['bankAccount']?.toString() ?? '',
        ifscCode: json['ifscCode']?.toString() ?? '',
        upiId: json['upiId']?.toString() ?? '',
        faceProfilePhotoUrl: json['faceProfilePhotoUrl']?.toString() ?? '',
        isFaceEnrolled: json['isFaceEnrolled'] == true,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        zoneId: json['zoneId']?.toString(),
        zoneName: json['zoneName']?.toString(),
        kycStatus: KYCStatus.values.firstWhere(
          (e) => e.name == json['kycStatus'],
          orElse: () => KYCStatus.underReview,
        ),
      );

  @override
  List<Object?> get props => [
        riderId,
        fullName,
        phone,
        emergencyPhone,
        emergencyRelation,
        houseNo,
        street,
        landmark,
        city,
        state,
        pincode,
        aadhaarNumber,
        isAadhaarVerified,
        dlNumber,
        dlExpiryDate,
        vehicleType,
        vehicleNumber,
        bankAccount,
        ifscCode,
        upiId,
        faceProfilePhotoUrl,
        isFaceEnrolled,
        kycStatus,
        latitude,
        longitude,
        zoneId,
        zoneName,
      ];
}

enum TransactionType { tripEarning, surgeBonus, customerTip, incentiveReward, upiWithdrawal }
enum TransactionStatus { settled, processing, failed }

class DeliveryTransactionEntity extends Equatable {
  final String id;
  final String orderId;
  final String orderNumber;
  final double amount;
  final double baseFare;
  final double surgeFee;
  final double tip;
  final TransactionType type;
  final TransactionStatus status;
  final String description;
  final DateTime timestamp;
  final String? upiReference;

  const DeliveryTransactionEntity({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.amount,
    this.baseFare = 35.0,
    this.surgeFee = 0.0,
    this.tip = 0.0,
    required this.type,
    required this.status,
    required this.description,
    required this.timestamp,
    this.upiReference,
  });

  @override
  List<Object?> get props => [
        id,
        orderId,
        orderNumber,
        amount,
        baseFare,
        surgeFee,
        tip,
        type,
        status,
        description,
        timestamp,
        upiReference,
      ];
}

class DeliveryOfferEntity extends Equatable {
  final String id;
  final String title;
  final String subtitle;
  final String tag;
  final double bonusReward;
  final int targetTrips;
  final int currentTrips;
  final bool isCompleted;
  final String expiryText;
  final String gradientColorStart;
  final String gradientColorEnd;

  const DeliveryOfferEntity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.bonusReward,
    required this.targetTrips,
    required this.currentTrips,
    required this.isCompleted,
    required this.expiryText,
    required this.gradientColorStart,
    required this.gradientColorEnd,
  });

  double get progress => targetTrips == 0 ? 0.0 : (currentTrips / targetTrips).clamp(0.0, 1.0);

  @override
  List<Object?> get props => [
        id,
        title,
        subtitle,
        tag,
        bonusReward,
        targetTrips,
        currentTrips,
        isCompleted,
        expiryText,
        gradientColorStart,
        gradientColorEnd,
      ];
}
