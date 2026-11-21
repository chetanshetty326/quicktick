import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class ILocalCacheService {
  Future<void> init();
  
  // Cart Cache
  Future<void> saveCartItems(List<Map<String, dynamic>> items);
  List<Map<String, dynamic>> getCartItems();
  Future<void> clearCart();

  // Stores & Catalog Cache
  Future<void> cacheStores(List<Map<String, dynamic>> stores);
  List<Map<String, dynamic>> getCachedStores();
  Future<void> cacheProducts(List<Map<String, dynamic>> products);
  List<Map<String, dynamic>> getCachedProducts();

  // Address Cache
  Future<void> cacheAddresses(List<Map<String, dynamic>> addresses);
  List<Map<String, dynamic>> getCachedAddresses();

  // Active Orders Cache
  Future<void> cacheActiveOrders(List<Map<String, dynamic>> orders);
  List<Map<String, dynamic>> getCachedActiveOrders();
  Future<List<Map<String, dynamic>>> reloadAndGetCachedOrders();

  // Active Location & Zone Cache
  Future<void> cacheActiveLocation({
    required double lat,
    required double lng,
    required String address,
    String? zoneId,
    String? zoneName,
    bool inZone = true,
  });
  Map<String, dynamic>? getCachedActiveLocation();

  // App Preferences
  Future<void> setDarkMode(bool isDark);
  bool isDarkMode();
  Future<void> setDevRole(String role);
  String? getDevRole();
  Future<void> setAppLanguage(String langCode);
  String getAppLanguage();

  // Reviewed Orders Cache
  Future<void> saveReviewedOrderIds(Set<String> ids);
  Set<String> getReviewedOrderIds();

  // FCM Token Cache
  Future<void> saveFcmToken(String token);
  String? getCachedFcmToken();

  // Customer Search History Cache
  Future<void> saveSearchHistory(List<String> queries);
  List<String> getSearchHistory();

  // Session & User Cache Cleaning
  Future<void> clearUserData();
}

class LocalCacheService implements ILocalCacheService {
  final SharedPreferences _prefs;
  late Box<String> _cartBox;
  late Box<String> _catalogBox;
  late Box<String> _addressBox;
  late Box<String> _ordersBox;

  LocalCacheService(
    this._prefs, {
    Box<String>? cartBox,
    Box<String>? catalogBox,
    Box<String>? addressBox,
    Box<String>? ordersBox,
  }) {
    if (cartBox != null) _cartBox = cartBox;
    if (catalogBox != null) _catalogBox = catalogBox;
    if (addressBox != null) _addressBox = addressBox;
    if (ordersBox != null) _ordersBox = ordersBox;
  }

  static const String _boxCart = 'box_cart';
  static const String _boxCatalog = 'box_catalog';
  static const String _boxAddress = 'box_address';
  static const String _boxOrders = 'box_orders';

  static const String _prefKeyTheme = 'pref_dark_mode';
  static const String _prefKeyDevRole = 'pref_dev_role';
  static const String _prefKeyOrdersSync = 'pref_shared_orders_sync';
  static const String _prefKeyReviewedOrders = 'customer_reviewed_orders';
  static const String _prefKeyFcmToken = 'fcm_device_token';
  static const String _prefKeySearchHistory = 'customer_search_history';

  @override
  Future<void> init() async {
    await Hive.initFlutter();
    _cartBox = await Hive.openBox<String>(_boxCart);
    _catalogBox = await Hive.openBox<String>(_boxCatalog);
    _addressBox = await Hive.openBox<String>(_boxAddress);
    _ordersBox = await Hive.openBox<String>(_boxOrders);
  }

  // --- Cart ---
  @override
  Future<void> saveCartItems(List<Map<String, dynamic>> items) async {
    await _cartBox.put('items', jsonEncode(items));
  }

  @override
  List<Map<String, dynamic>> getCartItems() {
    final raw = _cartBox.get('items');
    if (raw == null || raw.isEmpty) return [];
    try {
      final List decoded = jsonDecode(raw);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> clearCart() async {
    await _cartBox.delete('items');
  }

  @override
  Future<void> clearUserData() async {
    try {
      if (_cartBox.isOpen) await _cartBox.clear();
      if (_addressBox.isOpen) await _addressBox.clear();
      if (_ordersBox.isOpen) await _ordersBox.clear();
      await _prefs.remove(_prefKeyOrdersSync);
      await _prefs.remove(_prefKeyReviewedOrders);
      await _prefs.remove(_prefKeySearchHistory);
    } catch (_) {}
  }

  // --- Catalog & Stores ---
  @override
  Future<void> cacheStores(List<Map<String, dynamic>> stores) async {
    await _catalogBox.put('stores', jsonEncode(stores));
  }

  @override
  List<Map<String, dynamic>> getCachedStores() {
    final raw = _catalogBox.get('stores');
    if (raw == null) return [];
    try {
      final List decoded = jsonDecode(raw);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> cacheProducts(List<Map<String, dynamic>> products) async {
    await _catalogBox.put('products', jsonEncode(products));
  }

  @override
  List<Map<String, dynamic>> getCachedProducts() {
    final raw = _catalogBox.get('products');
    if (raw == null) return [];
    try {
      final List decoded = jsonDecode(raw);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // --- Addresses ---
  @override
  Future<void> cacheAddresses(List<Map<String, dynamic>> addresses) async {
    await _addressBox.put('addresses', jsonEncode(addresses));
  }

  @override
  List<Map<String, dynamic>> getCachedAddresses() {
    final raw = _addressBox.get('addresses');
    if (raw == null) return [];
    try {
      final List decoded = jsonDecode(raw);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // --- Active Orders ---
  @override
  Future<void> cacheActiveOrders(List<Map<String, dynamic>> orders) async {
    // Security Hardening: Redact sensitive customer delivery verification OTP from local disk cache
    final sanitizedOrders = orders.map((order) {
      final copy = Map<String, dynamic>.from(order);
      copy['deliveryOtp'] = '';
      return copy;
    }).toList();

    final encoded = jsonEncode(sanitizedOrders);
    try {
      await _ordersBox.put('active_orders', encoded);
    } catch (_) {}

    // Purge any legacy unencrypted plaintext orders from SharedPreferences
    try {
      if (_prefs.containsKey(_prefKeyOrdersSync)) {
        await _prefs.remove(_prefKeyOrdersSync);
      }
    } catch (_) {}
  }

  @override
  List<Map<String, dynamic>> getCachedActiveOrders() {
    String? raw;
    try {
      raw = _ordersBox.get('active_orders');
    } catch (_) {}
    if (raw == null && _prefs.containsKey(_prefKeyOrdersSync)) {
      raw = _prefs.getString(_prefKeyOrdersSync);
      // Migrate to Hive and purge from SharedPreferences
      if (raw != null && raw.isNotEmpty) {
        _ordersBox.put('active_orders', raw);
        _prefs.remove(_prefKeyOrdersSync);
      }
    }
    if (raw == null || raw.isEmpty) return [];
    try {
      final List decoded = jsonDecode(raw);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> reloadAndGetCachedOrders() async {
    return getCachedActiveOrders();
  }

  // --- Preferences ---
  @override
  Future<void> setDarkMode(bool isDark) async {
    await _prefs.setBool(_prefKeyTheme, isDark);
  }

  @override
  bool isDarkMode() {
    return _prefs.getBool(_prefKeyTheme) ?? false;
  }

  @override
  Future<void> setDevRole(String role) async {
    await _prefs.setString(_prefKeyDevRole, role);
  }

  @override
  String? getDevRole() {
    return _prefs.getString(_prefKeyDevRole);
  }

  // --- Reviewed Orders ---
  @override
  Future<void> saveReviewedOrderIds(Set<String> ids) async {
    try {
      await _prefs.setStringList(_prefKeyReviewedOrders, ids.toList());
    } catch (_) {}
  }

  @override
  Set<String> getReviewedOrderIds() {
    try {
      final list = _prefs.getStringList(_prefKeyReviewedOrders);
      return list != null ? Set<String>.from(list) : {};
    } catch (_) {
      return {};
    }
  }

  // --- FCM Token ---
  @override
  Future<void> saveFcmToken(String token) async {
    try {
      await _prefs.setString(_prefKeyFcmToken, token);
    } catch (_) {}
  }

  @override
  String? getCachedFcmToken() {
    try {
      return _prefs.getString(_prefKeyFcmToken);
    } catch (_) {
      return null;
    }
  }

  // --- Search History ---
  @override
  Future<void> saveSearchHistory(List<String> queries) async {
    try {
      await _prefs.setStringList(_prefKeySearchHistory, queries);
    } catch (_) {}
  }

  @override
  List<String> getSearchHistory() {
    try {
      final list = _prefs.getStringList(_prefKeySearchHistory);
      return list != null ? List<String>.from(list) : const [];
    } catch (_) {
      return const [];
    }
  }

  // --- Active Location & Zone ---
  static const String _prefKeyActiveLocation = 'pref_active_location';
  @override
  Future<void> cacheActiveLocation({
    required double lat,
    required double lng,
    required String address,
    String? zoneId,
    String? zoneName,
    bool inZone = true,
  }) async {
    final data = {
      'lat': lat,
      'lng': lng,
      'address': address,
      'zoneId': zoneId,
      'zoneName': zoneName,
      'inZone': inZone,
    };
    await _prefs.setString(_prefKeyActiveLocation, jsonEncode(data));
  }

  @override
  Map<String, dynamic>? getCachedActiveLocation() {
    final raw = _prefs.getString(_prefKeyActiveLocation);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  // --- App Language Preference ---
  static const String _prefKeyAppLanguage = 'pref_app_language';

  @override
  Future<void> setAppLanguage(String langCode) async {
    await _prefs.setString(_prefKeyAppLanguage, langCode);
  }

  @override
  String getAppLanguage() {
    return _prefs.getString(_prefKeyAppLanguage) ?? 'en';
  }
}
