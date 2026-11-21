import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Retailer Registration Draft Auto-Save & Restore Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Saves draft to SharedPreferences with phone-keyed storage', () async {
      final prefs = await SharedPreferences.getInstance();
      const phone = '9876543210';
      const key = 'retailer_registration_draft_$phone';

      final draftData = {
        'currentStep': 1,
        'storeName': 'Green Apple Grocery',
        'ownerName': 'John Doe',
        'phone': phone,
        'email': 'john@greenapple.com',
        'selectedStoreType': 'Grocery & Dark Store',
        'fssaiNumber': '12345678901234',
        'fssaiDocUploaded': true,
        'pan': 'ABCDE1234F',
        'panDocUploaded': true,
        'address': 'Plot 45, Main Market Road',
        'city': 'Bengaluru',
        'pincode': '560001',
        'accountName': 'Green Apple Enterprises',
        'accountNumber': '1234567890',
        'ifsc': 'SBIN0001234',
      };

      await prefs.setString(key, jsonEncode(draftData));
      await prefs.setString('retailer_registration_draft_last_key', key);

      // Verify stored
      final retrieved = prefs.getString(key);
      expect(retrieved, isNotNull);
      final decoded = jsonDecode(retrieved!) as Map<String, dynamic>;

      expect(decoded['currentStep'], equals(1));
      expect(decoded['storeName'], equals('Green Apple Grocery'));
      expect(decoded['ownerName'], equals('John Doe'));
      expect(decoded['fssaiNumber'], equals('12345678901234'));
      expect(decoded['fssaiDocUploaded'], isTrue);
      expect(decoded['pan'], equals('ABCDE1234F'));
      expect(decoded['address'], equals('Plot 45, Main Market Road'));
      expect(decoded['accountNumber'], equals('1234567890'));
    });

    test('Clears draft from SharedPreferences on completion or reset', () async {
      final prefs = await SharedPreferences.getInstance();
      const phone = '9876543210';
      const key = 'retailer_registration_draft_$phone';

      await prefs.setString(key, jsonEncode({'storeName': 'Green Apple Grocery'}));
      await prefs.setString('retailer_registration_draft_last_key', key);

      // Verify exists before clearing
      expect(prefs.getString(key), isNotNull);

      // Clear draft
      await prefs.remove(key);
      await prefs.remove('retailer_registration_draft_generic');
      await prefs.remove('retailer_registration_draft_last_key');

      // Verify cleared
      expect(prefs.getString(key), isNull);
      expect(prefs.getString('retailer_registration_draft_last_key'), isNull);
    });

    test('Fallback to last saved key if specific phone key is not found', () async {
      final prefs = await SharedPreferences.getInstance();
      const key = 'retailer_registration_draft_9988776655';

      await prefs.setString(key, jsonEncode({
        'currentStep': 2,
        'storeName': 'Sunrise Cafe',
      }));
      await prefs.setString('retailer_registration_draft_last_key', key);

      // Lookup via last key fallback
      final lastKey = prefs.getString('retailer_registration_draft_last_key');
      expect(lastKey, equals(key));
      final raw = prefs.getString(lastKey!);
      expect(raw, isNotNull);
      final data = jsonDecode(raw!) as Map<String, dynamic>;
      expect(data['storeName'], equals('Sunrise Cafe'));
      expect(data['currentStep'], equals(2));
    });
  });
}
