import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/customer/presentation/bloc/customer_bloc.dart';

/// App Localization keys and Kannada translations
enum AppLanguage {
  english('en', 'English', 'English'),
  kannada('kn', 'ಕನ್ನಡ', 'Kannada');

  final String code;
  final String nativeName;
  final String englishName;

  const AppLanguage(this.code, this.nativeName, this.englishName);

  static AppLanguage fromCode(String? code) {
    if (code == null) return AppLanguage.english;
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code.toLowerCase(),
      orElse: () => AppLanguage.english,
    );
  }
}

extension AppLocalizationContextExtension on BuildContext {
  AppStrings get strings {
    try {
      final state = read<CustomerBloc>().state;
      return state.strings;
    } catch (_) {
      return const AppStrings(AppLanguage.english);
    }
  }

  bool get isKannada {
    try {
      return read<CustomerBloc>().state.language == AppLanguage.kannada;
    } catch (_) {
      return false;
    }
  }
}

class AppStrings {
  final AppLanguage language;

  const AppStrings(this.language);

  bool get isKannada => language == AppLanguage.kannada;

  // --- Navigation ---
  String get tabShop => isKannada ? 'ಅಂಗಡಿ' : 'Shop';
  String get tabOrders => isKannada ? 'ನನ್ನ ಆರ್ಡರ್‌ಗಳು' : 'My Orders';
  String get tabProfile => isKannada ? 'ಪ್ರೊಫೈಲ್' : 'Profile';

  // --- Top Bar & Header ---
  String get deliveringTo => isKannada ? 'ವಿತರಣಾ ವಿಳಾಸ' : 'Delivering to';
  String get selectDeliveryAddress => isKannada ? 'ವಿಳಾಸ ಆಯ್ಕೆಮಾಡಿ' : 'Select Delivery Address';
  String get change => isKannada ? 'ಬದಲಾಯಿಸಿ' : 'CHANGE';
  String get notifications => isKannada ? 'ಸೂಚನೆಗಳು' : 'Notifications';
  String get searchPlaceholder => isKannada ? 'ದಿನಸಿ, ತರಕಾರಿ, ಹಣ್ಣುಗಳನ್ನು ಹುಡುಕಿ...' : 'Search for groceries, veggies...';
  String get compactSearchPlaceholder => isKannada ? 'ಉತ್ಪನ್ನಗಳು, ಅಂಗಡಿಗಳನ್ನು ಹುಡುಕಿ...' : 'Search products, stores...';

  // --- Categories & Filtering ---
  String get categories => isKannada ? 'ವಿಭಾಗಗಳು' : 'Categories';
  String get allCategories => isKannada ? 'ಎಲ್ಲಾ' : 'All';
  String get dealsAndOffers => isKannada ? 'ವಿಶೇಷ ಆಫರ್‌ಗಳು' : 'Hot Deals & Offers';
  String get allProducts => isKannada ? 'ಎಲ್ಲಾ ಉತ್ಪನ್ನಗಳು' : 'All Products';
  String get filters => isKannada ? 'ಫಿಲ್ಟರ್‌ಗಳು' : 'Filters';
  String get sortBy => isKannada ? 'ವಿಂಗಡಿಸಿ' : 'Sort by';
  String get relevance => isKannada ? 'ಜನಪ್ರಿಯ' : 'Relevance';
  String get priceLowToHigh => isKannada ? 'ಬೆಲೆ: ಕಡಿಮೆಯಿಂದ ಹೆಚ್ಚಿಗೆ' : 'Price: Low to High';
  String get priceHighToLow => isKannada ? 'ಬೆಲೆ: ಹೆಚ್ಚಿನಿಂದ ಕಡಿಮೆಗೆ' : 'Price: High to Low';
  String get inStockOnly => isKannada ? 'ಲಭ್ಯವಿರುವ ಉತ್ಪನ್ನಗಳು ಮಾತ್ರ' : 'In-Stock Only';
  String get vegOnly => isKannada ? 'ಸಸ್ಯಾಹಾರಿ ಮಾತ್ರ (Veg)' : 'Veg Only';
  String get nonVegOnly => isKannada ? 'ಮಾಂಸಾಹಾರಿ (Non-Veg)' : 'Non-Veg';
  String get clearFilters => isKannada ? 'ಫಿಲ್ಟರ್ ತೆರವುಗೊಳಿಸಿ' : 'Clear Filters';
  String get applyFilters => isKannada ? 'ಅನ್ವಯಿಸಿ' : 'Apply';

  // --- Product Cards & Interactions ---
  String get addToCart => isKannada ? 'ಸೇರಿಸಿ' : 'ADD';
  String get outOfStock => isKannada ? 'ಸ್ಟಾಕ್ ಮುಗಿದಿದೆ' : 'Out of Stock';
  String get inStock => isKannada ? 'ಲಭ್ಯವಿದೆ' : 'In Stock';
  String get unitPiece => isKannada ? 'ತುಂಡು' : 'piece';
  String get unitKg => isKannada ? 'ಕೆಜಿ' : 'kg';
  String get unitLitre => isKannada ? 'ಲೀಟರ್' : 'litre';
  String get unitGram => isKannada ? 'ಗ್ರಾಂ' : 'g';
  String get unitPack => isKannada ? 'ಪ್ಯಾಕ್' : 'pack';
  String get offPercent => isKannada ? 'ರಿಯಾಯಿತಿ' : 'OFF';

  // --- Floating Cart Bar ---
  String get viewCart => isKannada ? 'ಕಾರ್ಟ್ ನೋಡಿ' : 'VIEW CART';
  String get itemAddedToCart => isKannada ? 'ಕಾರ್ಟ್‌ಗೆ ಸೇರಿಸಲಾಗಿದೆ' : 'Added to cart';
  String itemsInCartCount(int count) => isKannada ? '$count ಐಟಂಗಳು' : '$count item${count > 1 ? "s" : ""}';

  // --- Cart Modal & Checkout ---
  String get myCart => isKannada ? 'ನನ್ನ ಕಾರ್ಟ್' : 'My Cart';
  String get clearCart => isKannada ? 'ಕಾರ್ಟ್ ಖಾಲಿ ಮಾಡಿ' : 'Clear Cart';
  String get emptyCartMessage => isKannada ? 'ನಿಮ್ಮ ಕಾರ್ಟ್ ಖಾಲಿಯಾಗಿದೆ' : 'Your cart is empty';
  String get emptyCartSubtitle => isKannada ? 'ತಾಜಾ ದಿನಸಿ ಮತ್ತು ಅಗತ್ಯ ವಸ್ತುಗಳನ್ನು ಸೇರಿಸಿ' : 'Add fresh items & groceries to get started';
  String get startShopping => isKannada ? 'ಶಾಪಿಂಗ್ ಪ್ರಾರಂಭಿಸಿ' : 'Start Shopping';
  String get billDetails => isKannada ? 'ಬಿಲ್ ವಿವರಗಳು' : 'Bill Details';
  String get itemTotal => isKannada ? 'ಐಟಂ ಮೊತ್ತ' : 'Item Total';
  String get deliveryFee => isKannada ? 'ವಿತರಣಾ ಶುಲ್ಕ' : 'Delivery Fee';
  String get freeDelivery => isKannada ? 'ಉಚಿತ' : 'FREE';
  String get platformFee => isKannada ? 'ಪ್ಲಾಟ್‌ಫಾರ್ಮ್ ಶುಲ್ಕ' : 'Platform Fee';
  String get taxesAndCharges => isKannada ? 'ತೆರಿಗೆ ಮತ್ತು ಶುಲ್ಕಗಳು' : 'Taxes & Charges';
  String get couponDiscount => isKannada ? 'ಕೂಪನ್ ರಿಯಾಯಿತಿ' : 'Coupon Discount';
  String get tipAmount => isKannada ? 'ಡೆಲಿವರಿ ಟಿಪ್' : 'Delivery Tip';
  String get grandTotal => isKannada ? 'ಒಟ್ಟು ಪಾವತಿ' : 'Grand Total';
  String get toPay => isKannada ? 'ಪಾವತಿಸಬೇಕಾದ ಮೊತ್ತ' : 'To Pay';
  String get applyCoupon => isKannada ? 'ಕೂಪನ್ ಕೋಡ್ ಅನ್ವಯಿಸಿ' : 'Apply Coupon';
  String get enterCouponCode => isKannada ? 'ಕೂಪನ್ ಕೋಡ್ ನಮೂದಿಸಿ' : 'Enter Coupon Code';
  String get removeCoupon => isKannada ? 'ತೆಗೆದುಹಾಕಿ' : 'Remove';
  String get addTipForRider => isKannada ? 'ಡೆಲಿವರಿ ಪಾಲುದಾರರಿಗೆ ಟಿಪ್ ನೀಡಿ' : 'Tip your delivery partner';
  String get selectPaymentMethod => isKannada ? 'ಪಾವತಿ ವಿಧಾನ ಆಯ್ಕೆಮಾಡಿ' : 'Select Payment Method';
  String get cashOnDelivery => isKannada ? 'ಕ್ಯಾಶ್ ಆನ್ ಡೆಲಿವರಿ (COD)' : 'Cash on Delivery (COD)';
  String get payOnline => isKannada ? 'ಆನ್‌ಲೈನ್ ಪಾವತಿ (UPI / ಕಾರ್ಡ್)' : 'Pay Online (UPI / Cards)';
  String get placeOrder => isKannada ? 'ಆರ್ಡರ್ ದೃಢೀಕರಿಸಿ' : 'Place Order';
  String get orderPlacing => isKannada ? 'ಆರ್ಡರ್ ಪ್ರಕ್ರಿಯೆಯಲ್ಲಿದೆ...' : 'Placing Order...';
  String get deliveryAddressPrompt => isKannada ? 'ದಯವಿಟ್ಟು ವಿತರಣಾ ವಿಳಾಸವನ್ನು ಆಯ್ಕೆಮಾಡಿ' : 'Please select delivery address';

  // --- Orders & Tracking ---
  String get pastOrders => isKannada ? 'ಹಿಂದಿನ ಆರ್ಡರ್‌ಗಳು' : 'Past Orders';
  String get activeOrders => isKannada ? 'ಪ್ರಸ್ತುತ ಆರ್ಡರ್‌ಗಳು' : 'Active Orders';
  String get noOrdersFound => isKannada ? 'ಯಾವುದೇ ಆರ್ಡರ್‌ಗಳು ಕಂಡುಬಂದಿಲ್ಲ' : 'No orders found';
  String get trackOrder => isKannada ? 'ಲೈವ್ ಟ್ರ್ಯಾಕ್ ಮಾಡಿ' : 'Track Order';
  String get reorder => isKannada ? 'ಮತ್ತೆ ಆರ್ಡರ್ ಮಾಡಿ' : 'Reorder';
  String get downloadInvoice => isKannada ? 'ಇನ್‌ವಾಯ್ಸ್ (PDF)' : 'Invoice';
  String get downloadingInvoice => isKannada ? 'ಇನ್‌ವಾಯ್ಸ್ ಡೌನ್‌ಲೋಡ್ ಆಗುತ್ತಿದೆ...' : 'Downloading invoice...';
  String get orderNumberPrefix => isKannada ? 'ಆರ್ಡರ್ ಸಂಖ್ಯೆ' : 'Order';
  String get orderPlacedSuccess => isKannada ? 'ಆರ್ಡರ್ ಯಶಸ್ವಿಯಾಗಿ ನೀಡಲಾಗಿದೆ!' : 'Order placed successfully!';
  String get orderStatusPlaced => isKannada ? 'ಸ್ವೀಕರಿಸಲಾಗಿದೆ' : 'Placed';
  String get orderStatusConfirmed => isKannada ? 'ದೃಢೀಕರಿಸಲಾಗಿದೆ' : 'Confirmed';
  String get orderStatusPreparing => isKannada ? 'ಸಿದ್ಧಪಡಿಸಲಾಗುತ್ತಿದೆ' : 'Preparing';
  String get orderStatusOutForDelivery => isKannada ? 'ವಿತರಣೆಗೆ ಹೊರಟಿದೆ' : 'Out for Delivery';
  String get orderStatusDelivered => isKannada ? 'ತಲುಪಿಸಲಾಗಿದೆ' : 'Delivered';
  String get orderStatusCancelled => isKannada ? 'ರದ್ದುಗೊಳಿಸಲಾಗಿದೆ' : 'Cancelled';

  // --- Profile & Settings ---
  String get myProfile => isKannada ? 'ನನ್ನ ಪ್ರೊಫೈಲ್' : 'My Profile';
  String get editProfile => isKannada ? 'ಪ್ರೊಫೈಲ್ ತಿದ್ದಿ' : 'Edit Profile';
  String get deliveryAndSettings => isKannada ? 'ವಿತರಣೆ ಮತ್ತು ಸೆಟ್ಟಿಂಗ್‌ಗಳು' : 'DELIVERY & SETTINGS';
  String get appLanguage => isKannada ? 'ಆ್ಯಪ್ ಭಾಷೆ / Language' : 'App Language';
  String get selectLanguage => isKannada ? 'ಭಾಷೆಯನ್ನು ಆಯ್ಕೆಮಾಡಿ' : 'Select Language';
  String get savedAddresses => isKannada ? 'ಉಳಿಸಿದ ವಿತರಣಾ ವಿಳಾಸಗಳು' : 'Saved Delivery Addresses';
  String get notificationCenter => isKannada ? 'ಸೂಚನಾ ಕೇಂದ್ರ' : 'Notification Center';
  String get supportAndLegal => isKannada ? 'ಬೆಂಬಲ ಮತ್ತು ನೀತಿಗಳು' : 'SUPPORT & LEGAL';
  String get privacyPolicy => isKannada ? 'ಗೌಪ್ಯತಾ ನೀತಿ' : 'Privacy Policy';
  String get termsOfService => isKannada ? 'ಸೇವಾ ನಿಯಮಗಳು' : 'Terms of Service';
  String get dataSafety => isKannada ? 'ಡೇಟಾ ಸುರಕ್ಷತೆ ಮತ್ತು ಅನುಮತಿಗಳು' : 'Data Safety & Permissions';
  String get helpAndSupport => isKannada ? 'ಸಹಾಯ ಮತ್ತು ಗ್ರಾಹಕ ಬೆಂಬಲ' : 'Help & Customer Support';
  String get logout => isKannada ? 'ಲಾಗ್ ಔಟ್' : 'Log Out';
  String get deleteAccount => isKannada ? 'ಖಾತೆ ಅಳಿಸಿ' : 'Delete Account';
  String get activeStatus => isKannada ? 'ಸಕ್ರಿಯ' : 'Active';

  // --- AI Concierge ---
  String get askAi => isKannada ? 'AI ಸಹಾಯ' : 'Ask AI';
  String get voiceTag => isKannada ? 'ಧ್ವನಿ' : 'VOICE';
  String get aiGreeting => isKannada ? 'ನಮಸ್ಕಾರ! ನಾನು ನಿಮ್ಮ QuickTick ಸಹಾಯಕ. ನಿಮಗೆ ಏನು ತರಬೇಕು?' : 'Hi! How can I assist with your shopping today?';
  String get voiceShopping => isKannada ? 'ಧ್ವನಿ ಮೂಲಕ ಶಾಪಿಂಗ್ ಮಾಡಿ ಮತ್ತು ತಕ್ಷಣದ ಬೆಂಬಲ' : 'Voice shopping & instant smart support';

  // --- Retailers & Stores Bilingual Resolver ---
  static String resolveStoreName(
    String storeId,
    String defaultName, {
    bool isKannada = false,
  }) {
    if (!isKannada) return defaultName;

    // Direct known store IDs mapped to authentic Kannada transliterations
    switch (storeId) {
      case '6aa3febe8b2afec202cc65cc':
        return 'ಬಿಗ್‌ಬಾಸ್ಕೆಟ್ ಎಕ್ಸ್‌ಪ್ರೆಸ್';
      case '6aa4d2968e786cd9f0772009':
        return 'ಡೈಲಿ ನೀಡ್ಸ್ ಸೂಪರ್‌ಮಾರ್ಕೆಟ್';
      case '6aa57f6a191b0ba5d25863af':
        return 'ಸ್ಪೈಸ್ ಗಾರ್ಡನ್ ರೆಸ್ಟೋರೆಂಟ್';
      case '6aa4d51e8e786cd9f07720bb':
        return 'ಮಲೆನಾಡು ಸ್ಪೈಸಸ್';
      case '6aa3febe8b2afec202cc65cb':
        return 'ಡೈಲಿ ನೀಡ್ಸ್ ಸ್ಟೋರ್';
      case '6aa3febe8b2afec202cc65c9':
        return 'ಕ್ವಿಕ್‌ಸ್ಟೋರ್ S391';
      case '6aa3febe8b2afec202cc65ca':
        return 'ಫ್ರೆಶ್‌ಮಾರ್ಟ್ ದಿನಸಿ';
      case '6aa3febe8b2afec202cc65ce':
        return 'ಆರ್ಗ್ಯಾನಿಕ್ ಹಬ್';
      case '6aa3febe8b2afec202cc65cd':
        return 'ಕಾರ್ನರ್ ಶಾಪ್';
      case '6aecd15dc123b83f572f4dfe':
        return 'ನಮ್ಮ ಅಂಗಡಿ';
      default:
        break;
    }

    // Dynamic smart transliteration for common store suffix words
    String name = defaultName;
    if (name == 'QuickTick Supermarket' || name == 'QuickMart Supermarket') {
      return 'ಕ್ವಿಕ್‌ಟಿಕ್ ಸೂಪರ್‌ಮಾರ್ಕೆಟ್';
    }
    if (name == 'Fresh Mart') {
      return 'ಫ್ರೆಶ್ ಮಾರ್ಟ್';
    }
    if (name == 'Store') {
      return 'ಅಂಗಡಿ';
    }

    // Transliterate common words if present in custom name
    name = name
        .replaceAll('Supermarket', 'ಸೂಪರ್‌ಮಾರ್ಕೆಟ್')
        .replaceAll('Super Market', 'ಸೂಪರ್‌ಮಾರ್ಕೆಟ್')
        .replaceAll('Grocery', 'ದಿನಸಿ')
        .replaceAll('Store', 'ಸ್ಟೋರ್')
        .replaceAll('Stores', 'ಸ್ಟೋರ್ಸ್')
        .replaceAll('Mart', 'ಮಾರ್ಟ್')
        .replaceAll('Fresh', 'ಫ್ರೆಶ್')
        .replaceAll('Express', 'ಎಕ್ಸ್‌ಪ್ರೆಸ್')
        .replaceAll('Organic', 'ಆರ್ಗ್ಯಾನಿಕ್')
        .replaceAll('Bakery', 'ಬೇಕರಿ')
        .replaceAll('Restaurant', 'ರೆಸ್ಟೋರೆಂಟ್');
    return name;
  }
}
