import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/location_disclosure_dialog.dart';

class LocationService {
  /// Check and request location permission with Google Play prominent disclosure
  static Future<bool> requestLocationPermission({
    BuildContext? context,
    bool isDeliveryPartner = false,
  }) async {
    try {
      if (context != null && context.mounted) {
        final agreed = await LocationDisclosureDialog.ensureDisclosureConsent(
          context,
          isDeliveryPartner: isDeliveryPartner,
        );
        if (!agreed) return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  /// Explicit check for Google Play prominent disclosure consent
  static Future<bool> ensureDisclosureConsent(
    BuildContext context, {
    bool isDeliveryPartner = false,
  }) async {
    return await LocationDisclosureDialog.ensureDisclosureConsent(
      context,
      isDeliveryPartner: isDeliveryPartner,
    );
  }

  /// Check current permission status
  static Future<bool> hasLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  /// Open Location settings or app settings
  static Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Get Current Position safely with permission request and GPS lock
  static Future<Position?> getCurrentPosition({bool requestIfNeeded = true}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location service is turned off on device
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestIfNeeded) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }

      // Try quick last known position first (fast cache lookup)
      Position? lastKnown;
      try {
        lastKnown = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      // 1. Try high accuracy with a 5-second deadline
      try {
        final current = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        return current;
      } catch (_) {
        // High accuracy may fail or timeout on OnePlus/OxygenOS aggressive power saving
        // or on Android 12+ if user granted only "Approximate Location"
      }

      // 2. Fallback to medium/balanced accuracy (works seamlessly with approximate location)
      try {
        final balanced = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
        return balanced;
      } catch (_) {}

      // 3. Fallback to last known position if active polling timed out
      if (lastKnown != null) {
        return lastKnown;
      }

      // 4. Final attempt to query last known position once more
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  /// Convert position or mock name to address
  static String formatLocation(Position? position) {
    if (position != null) {
      return 'Current Location (${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)})';
    }
    return 'Current Location';
  }

  /// Reverse geocode coordinates to a clean human-readable Indian street/locality/city address
  static Future<Map<String, String>> reverseGeocodeDetails(double lat, double lng) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        headers: {'User-Agent': 'QuickTickCustomerApp/1.0'},
      ));
      final url = 'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&zoom=18&addressdetails=1';
      final response = await dio.get(url);

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>? ?? {};

        final road = address['road'] ?? address['pedestrian'] ?? address['street'] ?? '';
        final area = address['suburb'] ?? address['neighbourhood'] ?? address['residential'] ?? address['quarter'] ?? '';
        final city = address['city'] ?? address['town'] ?? address['village'] ?? address['city_district'] ?? '';
        final state = address['state'] ?? '';
        final pincode = address['postcode'] ?? '';

        final line1 = road.toString().isNotEmpty ? road.toString() : (area.toString().isNotEmpty ? area.toString() : 'Current Location');
        final line2 = area.toString().isNotEmpty && area != line1 ? area.toString() : '';

        final parts = <String>[];
        if (line1.isNotEmpty) parts.add(line1);
        if (line2.isNotEmpty) parts.add(line2);
        if (city.toString().isNotEmpty) parts.add(city.toString());
        if (pincode.toString().isNotEmpty) parts.add(pincode.toString());

        return {
          'line1': line1,
          'line2': line2,
          'city': city.toString(),
          'state': state.toString(),
          'pincode': pincode.toString(),
          'formatted': parts.isNotEmpty ? parts.join(', ') : 'Current Location (${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)})',
        };
      }
    } catch (_) {}

    return {
      'line1': 'Current Location',
      'line2': '',
      'city': '',
      'state': '',
      'pincode': '',
      'formatted': 'Current Location (${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)})',
    };
  }

  /// High-level single string reverse geocoding
  static Future<String> reverseGeocode(double lat, double lng) async {
    final details = await reverseGeocodeDetails(lat, lng);
    return details['formatted'] ?? 'Current Location (${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)})';
  }
}
