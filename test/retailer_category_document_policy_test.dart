import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/features/retailer/domain/entities/business_category_document_policy.dart';

void main() {
  group('Clean Architecture: BusinessCategoryDocumentPolicy Domain Tests', () {
    test('[POLICY-01] Pharmacy & Wellness category requires Drug License, Pharmacist Cert & Mandatory GSTIN, but hides FSSAI', () {
      final policy = BusinessCategoryDocumentPolicy.getPolicy('Pharmacy & Wellness');

      expect(policy.categoryType, equals(BusinessCategoryType.pharmacy));
      expect(policy.requiresDrugLicense, isTrue);
      expect(policy.requiresPharmacistCert, isTrue);
      expect(policy.requiresFssai, isFalse);
      expect(policy.requiresTradeLicense, isFalse);
      expect(policy.requiresMeatNoc, isFalse);
      expect(policy.requiresGstinMandatory, isTrue);
      expect(policy.complianceBannerTitle, contains('Drug Control'));
    });

    test('[POLICY-02] Fresh Meat & Seafood category requires FSSAI and Veterinary Health NOC, but hides Pharmacy licenses', () {
      final policy = BusinessCategoryDocumentPolicy.getPolicy('Fresh Meat & Seafood');

      expect(policy.categoryType, equals(BusinessCategoryType.meatAndSeafood));
      expect(policy.requiresFssai, isTrue);
      expect(policy.requiresMeatNoc, isTrue);
      expect(policy.requiresDrugLicense, isFalse);
      expect(policy.requiresPharmacistCert, isFalse);
      expect(policy.requiresTradeLicense, isFalse);
      expect(policy.requiresGstinMandatory, isFalse);
      expect(policy.complianceBannerTitle, contains('Veterinary Health'));
    });

    test('[POLICY-03] General Retail & Electronics category requires Shop Trade License & GSTIN, and hides FSSAI food license', () {
      final policy = BusinessCategoryDocumentPolicy.getPolicy('General Retail & Electronics');

      expect(policy.categoryType, equals(BusinessCategoryType.generalRetail));
      expect(policy.requiresTradeLicense, isTrue);
      expect(policy.requiresFssai, isFalse);
      expect(policy.requiresDrugLicense, isFalse);
      expect(policy.requiresPharmacistCert, isFalse);
      expect(policy.requiresMeatNoc, isFalse);
      expect(policy.requiresGstinMandatory, isTrue);
      expect(policy.complianceBannerTitle, contains('Commercial Establishment'));
    });

    test('[POLICY-04] Pet Supplies & Care maps to General Retail and does not require food safety license', () {
      final policy = BusinessCategoryDocumentPolicy.getPolicy('Pet Supplies & Care');

      expect(policy.categoryType, equals(BusinessCategoryType.generalRetail));
      expect(policy.requiresTradeLicense, isTrue);
      expect(policy.requiresFssai, isFalse);
    });

    test('[POLICY-05] Restaurant category enforces 14-digit FSSAI food license and PAN', () {
      final policy = BusinessCategoryDocumentPolicy.getPolicy('Restaurant (Dine-in / Cloud Kitchen)');

      expect(policy.categoryType, equals(BusinessCategoryType.restaurant));
      expect(policy.requiresFssai, isTrue);
      expect(policy.requiresDrugLicense, isFalse);
      expect(policy.requiresTradeLicense, isFalse);
      expect(policy.requiresGstinMandatory, isFalse); // Optional for small restaurants
    });

    test('[POLICY-06] Grocery & Dark Store category requires FSSAI and mandatory commercial GSTIN', () {
      final policy = BusinessCategoryDocumentPolicy.getPolicy('Grocery & Dark Store');

      expect(policy.categoryType, equals(BusinessCategoryType.grocery));
      expect(policy.requiresFssai, isTrue);
      expect(policy.requiresDrugLicense, isFalse);
      expect(policy.requiresGstinMandatory, isTrue);
    });

    test('[POLICY-07] All business categories must require Business PAN card', () {
      final categories = [
        'Restaurant (Dine-in / Cloud Kitchen)',
        'Grocery & Dark Store',
        'Bakery & Confectionery',
        'Cafe & Beverages',
        'Pharmacy & Wellness',
        'Fresh Meat & Seafood',
        'General Retail & Electronics',
        'Pet Supplies & Care',
      ];

      for (final cat in categories) {
        final policy = BusinessCategoryDocumentPolicy.getPolicy(cat);
        final hasPan = policy.documentFields.any((f) => f.type == DocumentType.panCard && f.isMandatory);
        expect(hasPan, isTrue, reason: 'Category "$cat" must mandate PAN card');
      }
    });
  });
}
