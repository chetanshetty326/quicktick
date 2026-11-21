import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/services/location_service.dart';

void main() {
  group('Customer Address Sheet & GPS Location Defensive Checks', () {
    test('reverseGeocodeDetails handles null or empty address components safely without throwing', () async {
      // Test reverse geocoding fallback for 0.0, 0.0 or unreachable network
      final details = await LocationService.reverseGeocodeDetails(0.0, 0.0);
      expect(details, isA<Map<String, String>>());
      expect(details.containsKey('line1'), isTrue);
      expect(details.containsKey('formatted'), isTrue);
      expect(details['line1']!.isNotEmpty, isTrue);
    });

    test('formatLocation handles null position gracefully without throwing Bad state: No element', () {
      final formattedNull = LocationService.formatLocation(null);
      expect(formattedNull, equals('Current Location'));
    });

    test('Safe iterable navigation prevents Bad state: No element when collection is empty', () {
      final List<String> emptyList = [];
      
      // Traditional .first would throw Bad state: No element
      expect(() => emptyList.first, throwsStateError);

      // Safe access pattern:
      final safeItem = emptyList.isNotEmpty ? emptyList.first : null;
      expect(safeItem, isNull);
    });
  });
}
