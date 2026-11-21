import 'package:equatable/equatable.dart';

/// Available business categories for retailer onboarding
enum BusinessCategoryType {
  restaurant,
  grocery,
  bakery,
  cafe,
  pharmacy,
  meatAndSeafood,
  generalRetail,
}

/// Regulatory document types required by different business categories
enum DocumentType {
  fssai,
  drugLicense,
  pharmacistCert,
  meatHealthNoc,
  tradeLicense,
  panCard,
  gstin,
}

/// Specification for a document field dynamically displayed based on category
class RequiredDocumentField extends Equatable {
  final DocumentType type;
  final String label;
  final String uploadTitle;
  final String hint;
  final String guidance;
  final bool isMandatory;
  final bool hasExpiryDate;
  final int? exactLength;
  final bool isNumericOnly;
  final String errorMsg;

  const RequiredDocumentField({
    required this.type,
    required this.label,
    required this.uploadTitle,
    required this.hint,
    required this.guidance,
    this.isMandatory = true,
    this.hasExpiryDate = false,
    this.exactLength,
    this.isNumericOnly = false,
    required this.errorMsg,
  });

  @override
  List<Object?> get props => [
        type,
        label,
        uploadTitle,
        hint,
        guidance,
        isMandatory,
        hasExpiryDate,
        exactLength,
        isNumericOnly,
        errorMsg,
      ];
}

/// Domain Policy mapping business categories to their legal document requirements
class BusinessCategoryDocumentPolicy extends Equatable {
  final BusinessCategoryType categoryType;
  final String categoryName;
  final String complianceBannerTitle;
  final String complianceBannerDesc;
  final List<RequiredDocumentField> documentFields;

  const BusinessCategoryDocumentPolicy({
    required this.categoryType,
    required this.categoryName,
    required this.complianceBannerTitle,
    required this.complianceBannerDesc,
    required this.documentFields,
  });

  bool get requiresFssai => documentFields.any((d) => d.type == DocumentType.fssai);
  bool get requiresDrugLicense => documentFields.any((d) => d.type == DocumentType.drugLicense);
  bool get requiresPharmacistCert => documentFields.any((d) => d.type == DocumentType.pharmacistCert);
  bool get requiresMeatNoc => documentFields.any((d) => d.type == DocumentType.meatHealthNoc);
  bool get requiresTradeLicense => documentFields.any((d) => d.type == DocumentType.tradeLicense);
  bool get requiresGstinMandatory => documentFields.any((d) => d.type == DocumentType.gstin && d.isMandatory);

  @override
  List<Object?> get props => [
        categoryType,
        categoryName,
        complianceBannerTitle,
        complianceBannerDesc,
        documentFields,
      ];

  /// Factory method to determine document policy from store category name
  static BusinessCategoryDocumentPolicy getPolicy(String category) {
    final lower = category.toLowerCase();

    // 1. Pharmacy & Health Wellness
    if (lower.contains('pharmacy') || lower.contains('wellness') || lower.contains('chemist') || lower.contains('medicine')) {
      return const BusinessCategoryDocumentPolicy(
        categoryType: BusinessCategoryType.pharmacy,
        categoryName: 'Pharmacy & Wellness',
        complianceBannerTitle: 'CDSCO & State Drug Control Compliance',
        complianceBannerDesc:
            'Drug Retail Sale License (Form 20/21) & Registered Pharmacist certification are mandatory for medicines and health wellness products.',
        documentFields: [
          RequiredDocumentField(
            type: DocumentType.drugLicense,
            label: 'Drug Retail Sale License No. (Form 20/21) *',
            uploadTitle: 'Drug Retail Sale License Certificate *',
            hint: 'DL No. (e.g. KA-B1-123456 / MH-20B-9988)',
            guidance: 'Issued by State Drug Control Administration under Drugs & Cosmetics Act.',
            isMandatory: true,
            hasExpiryDate: true,
            errorMsg: 'Enter valid Drug License number',
          ),
          RequiredDocumentField(
            type: DocumentType.pharmacistCert,
            label: 'Registered Pharmacist Reg. Number *',
            uploadTitle: 'Pharmacist Registration Certificate *',
            hint: 'Registration No. (e.g. KA-PH-45678)',
            guidance: 'Registered with State Pharmacy Council under Pharmacy Act 1948.',
            isMandatory: true,
            hasExpiryDate: false,
            errorMsg: 'Enter valid Pharmacist Registration number',
          ),
          RequiredDocumentField(
            type: DocumentType.panCard,
            label: 'Business / Proprietor PAN Card Number *',
            uploadTitle: 'Business PAN Card (Optional upload)',
            hint: '10-digit PAN (e.g. ABCDE1234F)',
            guidance: 'Mandatory tax identification for banking settlements.',
            isMandatory: true,
            exactLength: 10,
            errorMsg: 'Enter valid 10-digit PAN',
          ),
          RequiredDocumentField(
            type: DocumentType.gstin,
            label: 'GSTIN Number (Mandatory for Pharmacies) *',
            uploadTitle: 'GST Registration Certificate *',
            hint: '15-digit GSTIN (e.g. 29ABCDE1234F1Z5)',
            guidance: 'Required for compliant pharmaceutical billing & invoicing.',
            isMandatory: true,
            exactLength: 15,
            errorMsg: 'Enter valid 15-digit GSTIN',
          ),
        ],
      );
    }

    // 2. Fresh Meat & Seafood
    if (lower.contains('meat') || lower.contains('seafood') || lower.contains('fish') || lower.contains('chicken') || lower.contains('mutton')) {
      return const BusinessCategoryDocumentPolicy(
        categoryType: BusinessCategoryType.meatAndSeafood,
        categoryName: 'Fresh Meat & Seafood',
        complianceBannerTitle: 'FSSAI Meat Safety & Veterinary Health Compliance',
        complianceBannerDesc:
            'FSSAI Meat Processing License and Municipal Veterinary Health Sanitation NOC are mandatory for hygienic fresh meat and poultry delivery.',
        documentFields: [
          RequiredDocumentField(
            type: DocumentType.fssai,
            label: '14-Digit FSSAI Meat Handling License *',
            uploadTitle: 'FSSAI Meat License Certificate *',
            hint: '14-digit FSSAI Number',
            guidance: 'FSSAI Category 08: Meat, poultry & seafood handling license.',
            isMandatory: true,
            hasExpiryDate: true,
            exactLength: 14,
            isNumericOnly: true,
            errorMsg: 'Enter valid 14-digit FSSAI Meat License number',
          ),
          RequiredDocumentField(
            type: DocumentType.meatHealthNoc,
            label: 'Veterinary / Municipal Health NOC Number *',
            uploadTitle: 'Municipal Health NOC / Certificate *',
            hint: 'Health Clearance NOC No. (e.g. BBMP-VET-2026-88)',
            guidance: 'Issued by Local Municipal Corporation / Animal Husbandry Dept.',
            isMandatory: true,
            hasExpiryDate: true,
            errorMsg: 'Enter valid Health Clearance NOC details',
          ),
          RequiredDocumentField(
            type: DocumentType.panCard,
            label: 'Business PAN Card Number *',
            uploadTitle: 'PAN Card Copy',
            hint: '10-digit PAN (e.g. ABCDE1234F)',
            guidance: 'Mandatory tax identification.',
            isMandatory: true,
            exactLength: 10,
            errorMsg: 'Enter valid 10-digit PAN',
          ),
          RequiredDocumentField(
            type: DocumentType.gstin,
            label: 'GSTIN Number (Optional for local meat vendors)',
            uploadTitle: 'GST Certificate (Optional)',
            hint: '15-digit GSTIN (e.g. 29ABCDE1234F1Z5)',
            guidance: 'Optional if turnover is under statutory GST limit.',
            isMandatory: false,
            exactLength: 15,
            errorMsg: 'Enter valid 15-digit GSTIN',
          ),
        ],
      );
    }

    // 3. General Retail & Electronics (Non-Food: FSSAI is not required)
    if (lower.contains('retail') || lower.contains('electronic') || lower.contains('stationery') || lower.contains('fashion') || lower.contains('apparel') || lower.contains('pet')) {
      return const BusinessCategoryDocumentPolicy(
        categoryType: BusinessCategoryType.generalRetail,
        categoryName: 'General Retail & Electronics',
        complianceBannerTitle: 'Shop & Commercial Establishment Act Compliance',
        complianceBannerDesc:
            'Trade License / Shop & Establishment Registration and GSTIN are required for consumer goods and electronics. (No FSSAI food license required).',
        documentFields: [
          RequiredDocumentField(
            type: DocumentType.tradeLicense,
            label: 'Shop & Establishment / Trade License No. *',
            uploadTitle: 'Trade License / Gumasta Certificate *',
            hint: 'Trade License No. (e.g. BBMP-TL-2026-5412)',
            guidance: 'Issued by Municipal Corporation or Department of Labour.',
            isMandatory: true,
            hasExpiryDate: true,
            errorMsg: 'Enter valid Trade License number',
          ),
          RequiredDocumentField(
            type: DocumentType.panCard,
            label: 'Business PAN Card Number *',
            uploadTitle: 'PAN Card Copy',
            hint: '10-digit PAN (e.g. ABCDE1234F)',
            guidance: 'Mandatory tax identification for merchant payouts.',
            isMandatory: true,
            exactLength: 10,
            errorMsg: 'Enter valid 10-digit PAN',
          ),
          RequiredDocumentField(
            type: DocumentType.gstin,
            label: 'GSTIN Number *',
            uploadTitle: 'GST Registration Certificate *',
            hint: '15-digit GSTIN (e.g. 29ABCDE1234F1Z5)',
            guidance: 'Mandatory for consumer electronics, retail items & billing.',
            isMandatory: true,
            exactLength: 15,
            errorMsg: 'Enter valid 15-digit GSTIN',
          ),
        ],
      );
    }

    // 4. Default: Restaurant, Cafe, Bakery, Grocery & Dark Store (Food Categories)
    final isGrocery = lower.contains('grocery') || lower.contains('dark store') || lower.contains('supermarket');
    return BusinessCategoryDocumentPolicy(
      categoryType: isGrocery ? BusinessCategoryType.grocery : BusinessCategoryType.restaurant,
      categoryName: isGrocery ? 'Grocery & Dark Store' : 'Restaurant & Food Service',
      complianceBannerTitle: 'FSSAI Food Safety & Quality Standards',
      complianceBannerDesc:
          '14-digit FSSAI license and certificate copy are mandatory for all food, restaurant, cloud kitchen & dark store grocery establishments under FSSAI Act 2006.',
      documentFields: [
        const RequiredDocumentField(
          type: DocumentType.fssai,
          label: '14-Digit FSSAI License Number *',
          uploadTitle: 'FSSAI License Certificate *',
          hint: '14-digit FSSAI License Number',
          guidance: 'Mandatory 14-digit food safety license issued by Govt. of India.',
          isMandatory: true,
          hasExpiryDate: true,
          exactLength: 14,
          isNumericOnly: true,
          errorMsg: 'Enter valid 14-digit FSSAI license number',
        ),
        const RequiredDocumentField(
          type: DocumentType.panCard,
          label: 'Business PAN Card Number *',
          uploadTitle: 'Business PAN Card Copy',
          hint: '10-digit PAN (e.g. ABCDE1234F)',
          guidance: 'Mandatory tax identification for account verification.',
          isMandatory: true,
          exactLength: 10,
          errorMsg: 'Enter valid 10-digit PAN',
        ),
        RequiredDocumentField(
          type: DocumentType.gstin,
          label: isGrocery ? 'GSTIN Number (Mandatory for Supermarkets) *' : 'GSTIN Number (Optional for small food outlets)',
          uploadTitle: 'GST Registration Certificate',
          hint: '15-digit GSTIN (e.g. 29ABCDE1234F1Z5)',
          guidance: isGrocery ? 'Mandatory for commercial packaged grocery & dark stores.' : 'Optional if annual turnover is under ₹20 Lakhs.',
          isMandatory: isGrocery,
          exactLength: 15,
          errorMsg: 'Enter valid 15-digit GSTIN',
        ),
      ],
    );
  }
}
