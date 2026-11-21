import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../features/auth/domain/entities/user_entity.dart';

abstract class IInAppMessagingService {
  /// Initializes In-App Messaging for the authenticated user and their active role
  Future<void> initialize({required UserRole role, String? userId});

  /// Triggers a contextual event to display targeted in-app banners/popups
  Future<void> triggerEvent(String eventName);

  /// Suppresses in-app popups during sensitive operations (e.g., checkout/scanning)
  Future<void> setMessagesSuppressed(bool suppressed);

  /// Checks if message suppression is currently active
  bool get isSuppressed;

  /// Role-specific trigger event constants
  static const String customerAppOpened = 'customer_app_opened';
  static const String customerCartViewed = 'customer_cart_viewed';
  static const String customerOrderPlaced = 'customer_order_placed';
  static const String customerRecipeUsed = 'customer_recipe_used';
  static const String customerCategoryBrowsed = 'customer_category_browsed';

  static const String retailerAppOpened = 'retailer_app_opened';
  static const String retailerOrderAccepted = 'retailer_order_accepted';
  static const String retailerOrderReady = 'retailer_order_ready';
  static const String retailerStockToggled = 'retailer_stock_toggled';
  static const String retailerSettlementViewed = 'retailer_settlement_viewed';

  static const String deliveryAppOpened = 'delivery_app_opened';
  static const String deliveryDutyOn = 'delivery_duty_on';
  static const String deliveryDutyOff = 'delivery_duty_off';
  static const String deliveryOrderAccepted = 'delivery_order_accepted';
  static const String deliveryOrderPickedUp = 'delivery_order_picked_up';
  static const String deliveryOrderDelivered = 'delivery_order_delivered';
  static const String deliveryEarningsViewed = 'delivery_earnings_viewed';
}

class FirebaseInAppMessagingService implements IInAppMessagingService {
  final FirebaseInAppMessaging? _customFiam;
  bool _isSuppressed = false;

  FirebaseInAppMessagingService({FirebaseInAppMessaging? fiam})
      : _customFiam = fiam;

  FirebaseInAppMessaging? get _fiam {
    if (_customFiam != null) return _customFiam;
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseInAppMessaging.instance;
      }
    } catch (_) {}
    return null;
  }

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  bool get isSuppressed => _isSuppressed;

  @override
  Future<void> initialize({required UserRole role, String? userId}) async {
    if (!_isSupportedPlatform) {
      debugPrint('[FIAM] In-App Messaging is not supported on ${defaultTargetPlatform.name}. Gracefully bypassed.');
      return;
    }

    try {
      // Allow messages by default upon initialization
      await setMessagesSuppressed(false);

      // Trigger app open event according to role
      final roleEvent = _getAppOpenEventForRole(role);
      await triggerEvent(roleEvent);

      debugPrint('[FIAM] Initialized successfully for role: ${role.name}, user: $userId');
    } catch (e) {
      debugPrint('[FIAM] Initialization warning: $e');
    }
  }

  @override
  Future<void> triggerEvent(String eventName) async {
    if (!_isSupportedPlatform) return;
    if (_isSuppressed) {
      debugPrint('[FIAM] Event "$eventName" suppressed because in-app messages are temporarily paused.');
      return;
    }

    try {
      final fiam = _fiam;
      if (fiam != null) {
        await fiam.triggerEvent(eventName);
        debugPrint('📢 [FIAM] Triggered in-app messaging event: "$eventName"');
      }
    } catch (e) {
      debugPrint('[FIAM] Error triggering event "$eventName": $e');
    }
  }

  @override
  Future<void> setMessagesSuppressed(bool suppressed) async {
    _isSuppressed = suppressed;
    if (!_isSupportedPlatform) return;

    try {
      final fiam = _fiam;
      if (fiam != null) {
        await fiam.setMessagesSuppressed(suppressed);
        debugPrint('🛑 [FIAM] Messages suppressed: $suppressed');
      }
    } catch (e) {
      debugPrint('[FIAM] Error setting message suppression: $e');
    }
  }

  String _getAppOpenEventForRole(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return IInAppMessagingService.customerAppOpened;
      case UserRole.retailer:
        return IInAppMessagingService.retailerAppOpened;
      case UserRole.deliveryPartner:
        return IInAppMessagingService.deliveryAppOpened;
      case UserRole.admin:
        return 'admin_app_opened';
    }
  }
}

