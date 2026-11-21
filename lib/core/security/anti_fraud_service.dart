import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:geolocator/geolocator.dart';

class AntiFraudSecurityService {
  /// Detects whether the rider's device is using mock / spoofed GPS locations
  static bool isLocationSpoofed(Position position) {
    return position.isMocked;
  }

  /// Verifies if delivery PIN matches secure SHA-256 digest
  static bool verifyDeliveryPinHash({
    required String enteredPin,
    required String expectedHash,
  }) {
    final digest = sha256.convert(utf8.encode(enteredPin.trim())).toString();
    return digest == expectedHash;
  }

  /// Generates secure 6-digit numeric delivery OTP
  static String generateSecureDeliveryOtp(String orderId) {
    final bytes = utf8.encode('$orderId-${DateTime.now().millisecondsSinceEpoch}');
    final hash = sha256.convert(bytes).toString();
    final numeric = hash.replaceAll(RegExp(r'[^0-9]'), '');
    return numeric.length >= 6 ? numeric.substring(0, 6) : '782345';
  }

  /// Masks sensitive Aadhaar digits for compliance with UIDAI Privacy Guidelines
  static String maskAadhaar(String aadhaar) {
    final clean = aadhaar.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length == 12) {
      return 'XXXX-XXXX-${clean.substring(8)}';
    }
    return aadhaar;
  }

  /// Masks Bank Account Number showing only last 4 digits
  static String maskBankAccount(String account) {
    final clean = account.trim();
    if (clean.length > 4) {
      return '••••••••${clean.substring(clean.length - 4)}';
    }
    return clean;
  }
}
