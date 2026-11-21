import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../security/secure_storage_service.dart';

/// Top-level background message handler required by FirebaseMessaging for terminated/background state
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}
  debugPrint('🔔 [FCM Background Handler] Message: ${message.messageId} -> ${message.data}');

  // Android only auto-displays messages with a top-level `notification` block.
  // For data-only background pushes containing title/body/message, display via local notifications.
  if (message.notification == null && message.data.isNotEmpty) {
    final title = message.data['title']?.toString();
    final body = message.data['body']?.toString() ?? message.data['message']?.toString();
    if ((title != null && title.isNotEmpty) || (body != null && body.isNotEmpty)) {
      try {
        final localNotifs = FlutterLocalNotificationsPlugin();
        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        await localNotifs.initialize(const InitializationSettings(android: androidInit));
        final androidPlugin = localNotifs.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            PushNotificationService._channelId,
            PushNotificationService._channelName,
            description: PushNotificationService._channelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
        await localNotifs.show(
          message.hashCode,
          title ?? 'QuickTick Update',
          body ?? '',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              PushNotificationService._channelId,
              PushNotificationService._channelName,
              channelDescription: PushNotificationService._channelDesc,
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: jsonEncode({
            'id': message.messageId ?? 'notif_${DateTime.now().millisecondsSinceEpoch}',
            'title': title ?? 'QuickTick Update',
            'body': body ?? '',
            'type': message.data['type']?.toString(),
            'orderId': message.data['orderId']?.toString(),
            'deepLink': message.data['deepLink']?.toString(),
            'data': message.data,
          }),
        );
      } catch (e) {
        debugPrint('⚠️ [FCM Background LocalNotif Error]: $e');
      }
    }
  }
}

/// Push Notification Payload Model representing an incoming notification
class PushNotificationPayload {
  final String id;
  final String title;
  final String body;
  final String? type; // e.g., 'ORDER_STATUS', 'NEW_ORDER', 'PROMO', 'DELIVERY_UPDATE'
  final String? orderId;
  final String? deepLink;
  final Map<String, dynamic> data;
  final DateTime receivedAt;
  final bool fromTap;

  const PushNotificationPayload({
    required this.id,
    required this.title,
    required this.body,
    this.type,
    this.orderId,
    this.deepLink,
    this.data = const {},
    required this.receivedAt,
    this.fromTap = false,
  });

  factory PushNotificationPayload.fromJson(Map<String, dynamic> json, {bool fromTap = false}) {
    return PushNotificationPayload(
      id: json['id']?.toString() ?? 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title']?.toString() ?? 'QuickTick Alert',
      body: json['body']?.toString() ?? json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? json['data']?['type']?.toString(),
      orderId: json['orderId']?.toString() ?? json['data']?['orderId']?.toString(),
      deepLink: json['deepLink']?.toString() ?? json['data']?['deepLink']?.toString(),
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : {},
      receivedAt: DateTime.now(),
      fromTap: fromTap || json['fromTap'] == true,
    );
  }

  factory PushNotificationPayload.fromRemoteMessage(RemoteMessage message, {bool fromTap = false}) {
    final notification = message.notification;
    final data = message.data;
    return PushNotificationPayload(
      id: message.messageId ?? 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: notification?.title ?? data['title']?.toString() ?? 'QuickTick Update',
      body: notification?.body ?? data['body']?.toString() ?? data['message']?.toString() ?? '',
      type: data['type']?.toString(),
      orderId: data['orderId']?.toString(),
      deepLink: data['deepLink']?.toString(),
      data: data,
      receivedAt: DateTime.now(),
      fromTap: fromTap,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      ...data,
      'id': id,
      'title': title,
      'body': body,
      'message': body,
      if (type != null) 'type': type,
      if (orderId != null) 'orderId': orderId,
      if (deepLink != null) 'deepLink': deepLink,
      'fromTap': fromTap,
    };
  }
}

abstract class IPushNotificationService {
  Stream<PushNotificationPayload> get onNotificationReceived;
  PushNotificationPayload? consumePendingNotification();
  Future<void> initialize({UserRole? role});
  Future<String?> getDeviceToken();
  Future<bool> registerDeviceWithBackend({
    required String fcmToken,
    required UserRole role,
    String? deviceId,
  });
  Future<bool> unregisterDeviceWithBackend({required UserRole role});
  void showInAppBanner(BuildContext context, PushNotificationPayload payload, {VoidCallback? onTap});
  void simulateIncomingPush(PushNotificationPayload payload);
  Future<void> showOngoingDeliveryNotification({
    required String title,
    required String body,
    String? subText,
  });
  Future<void> cancelOngoingDeliveryNotification();
  void dispose();
}

class PushNotificationService implements IPushNotificationService {
  final ApiClient _apiClient;
  final SharedPreferences? _prefs;
  final ISecureStorageService? _secureStorage;
  final FlutterLocalNotificationsPlugin _localNotifs = FlutterLocalNotificationsPlugin();

  FirebaseMessaging? get _fcm {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseMessaging.instance;
      }
    } catch (_) {}
    return null;
  }

  final _notifStreamController = StreamController<PushNotificationPayload>.broadcast();
  PushNotificationPayload? _pendingNotification;
  String? _cachedToken;
  UserRole? _activeRole;
  bool _isInitialized = false;

  static const String _channelId = 'quicktick_high_importance';
  static const String _channelName = 'QuickTick High Importance Notifications';
  static const String _channelDesc = 'Critical notifications for orders, status updates and delivery alerts.';

  PushNotificationService({
    required ApiClient apiClient,
    SharedPreferences? prefs,
    ISecureStorageService? secureStorage,
  })  : _apiClient = apiClient,
        _prefs = prefs,
        _secureStorage = secureStorage;

  @override
  Stream<PushNotificationPayload> get onNotificationReceived => _notifStreamController.stream;

  @override
  PushNotificationPayload? consumePendingNotification() {
    final pending = _pendingNotification;
    _pendingNotification = null;
    return pending;
  }

  void _emitNotification(PushNotificationPayload payload, {bool cacheIfColdStart = false}) {
    if (cacheIfColdStart || !_notifStreamController.hasListener) {
      _pendingNotification = payload;
    }
    _notifStreamController.add(payload);
  }

  void _emitFromRawJsonPayload(String? rawPayload) {
    if (rawPayload == null || rawPayload.isEmpty) return;
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is Map) {
        final payload = PushNotificationPayload.fromJson(
          Map<String, dynamic>.from(decoded),
          fromTap: true,
        );
        _emitNotification(payload, cacheIfColdStart: true);
      }
    } catch (_) {}
  }

  @override
  Future<void> initialize({UserRole? role}) async {
    if (_isInitialized) {
      if (role != null) {
        _activeRole = role;
        await _registerStoredTokenIfAvailable();
      }
      return;
    }

    _activeRole = role;

    try {
      final fcmInstance = _fcm;
      if (fcmInstance == null) {
        debugPrint('⚠️ [FCM Init Notice] Firebase is not initialized. Skipping FCM setup.');
        _isInitialized = true;
        return;
      }

      // 1. Set top-level background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 2. Request OS Notification Permissions (Android 13+ & iOS)
      final settings = await fcmInstance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('🔔 [FCM] Notification authorization status: ${settings.authorizationStatus}');

      // 3. Setup Android Notification Channel & Local Notifications
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);

      await _localNotifs.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('🔔 [LocalNotifs] Notification response tapped: ${response.payload}');
          _emitFromRawJsonPayload(response.payload);
        },
      );

      const androidChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _localNotifs.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(androidChannel);
        await androidPlugin.requestNotificationsPermission();
      }

      // 4. Listen for Foreground Messages (App is currently Open)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('🔔 [FCM Foreground] Received: ${message.notification?.title ?? message.data['title']}');
        final payload = PushNotificationPayload.fromRemoteMessage(message);
        _emitNotification(payload);

        // Display system heads-up notification banner while app is open (supports both notification & data-only pushes)
        final notification = message.notification;
        final hasDisplayContent = notification != null || payload.body.isNotEmpty || message.data.isNotEmpty;
        if (hasDisplayContent) {
          _localNotifs.show(
            notification?.hashCode ?? message.hashCode,
            notification?.title ?? payload.title,
            notification?.body ?? payload.body,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                _channelId,
                _channelName,
                channelDescription: _channelDesc,
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
                icon: '@mipmap/ic_launcher',
              ),
            ),
            payload: jsonEncode(payload.toMap()),
          );
        }
      });

      // 5. App Opened from Background notification tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🔔 [FCM onMessageOpenedApp] Tapped notification: ${message.data}');
        final payload = PushNotificationPayload.fromRemoteMessage(message, fromTap: true);
        _emitNotification(payload, cacheIfColdStart: true);
      });

      // 6. Check Initial Message (Cold Start / Terminated State — both FCM & background local notifs)
      final initialMessage = await fcmInstance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🔔 [FCM InitialMessage] Cold start notification: ${initialMessage.data}');
        final payload = PushNotificationPayload.fromRemoteMessage(initialMessage, fromTap: true);
        _emitNotification(payload, cacheIfColdStart: true);
      } else {
        final launchDetails = await _localNotifs.getNotificationAppLaunchDetails();
        if (launchDetails?.didNotificationLaunchApp == true) {
          _emitFromRawJsonPayload(launchDetails?.notificationResponse?.payload);
        }
      }

      // 7. Token Refresh Listener
      fcmInstance.onTokenRefresh.listen((newToken) {
        debugPrint('🔔 [FCM] Token refreshed: $newToken');
        _cachedToken = newToken;
        _prefs?.setString('fcm_device_token', newToken);
        if (_activeRole != null) {
          registerDeviceWithBackend(fcmToken: newToken, role: _activeRole!);
        }
      });

      // 8. Retrieve initial token & auto-register
      final token = await getDeviceToken();
      if (token != null && _activeRole != null) {
        await registerDeviceWithBackend(fcmToken: token, role: _activeRole!);
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('⚠️ [FCM Init Warning] Error initializing Firebase Messaging: $e');
    }
  }

  Future<void> _registerStoredTokenIfAvailable() async {
    final token = _cachedToken ?? _prefs?.getString('fcm_device_token');
    if (token != null && _activeRole != null) {
      await registerDeviceWithBackend(fcmToken: token, role: _activeRole!);
    }
  }

  @override
  Future<String?> getDeviceToken() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty && !_cachedToken!.startsWith('fcm_token_')) {
      return _cachedToken;
    }

    try {
      final fcmInstance = _fcm;
      if (fcmInstance == null) return null;
      final token = await fcmInstance.getToken();
      if (token != null && token.isNotEmpty) {
        _cachedToken = token;
        await _prefs?.setString('fcm_device_token', token);
        return token;
      }
    } catch (e) {
      debugPrint('FCM getToken error (fallback active): $e');
    }

    // Fall back to previously saved real FCM token if live lookup temporarily fails
    final stored = _prefs?.getString('fcm_device_token');
    if (stored != null && stored.isNotEmpty && !stored.startsWith('fcm_token_')) {
      _cachedToken = stored;
      return _cachedToken;
    }

    // Graceful fallback for emulators without Play Services so app never crashes
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();
    return 'fcm_token_${platform}_$timestamp';
  }

  String _getOrCreatePersistentDeviceId() {
    final existing = _prefs?.getString('persistent_push_device_id');
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = 'device_${DateTime.now().millisecondsSinceEpoch % 100000000}';
    _prefs?.setString('persistent_push_device_id', generated);
    return generated;
  }

  @override
  Future<bool> registerDeviceWithBackend({
    required String fcmToken,
    required UserRole role,
    String? deviceId,
  }) async {
    _activeRole = role;
    var resolvedToken = fcmToken;
    if (resolvedToken.startsWith('fcm_token_')) {
      final refreshed = await getDeviceToken();
      if (refreshed != null && refreshed.isNotEmpty && !refreshed.startsWith('fcm_token_')) {
        resolvedToken = refreshed;
      }
    }
    if (!resolvedToken.startsWith('fcm_token_')) {
      _cachedToken = resolvedToken;
      await _prefs?.setString('fcm_device_token', resolvedToken);
    }

    // Guard: Only register device with the backend if the user is authenticated.
    // The backend /users/register-device endpoint requires a Bearer JWT; unauthenticated calls throw 401.
    if (_secureStorage != null) {
      final token = await _secureStorage.getAccessToken();
      final isSessionValid = await _secureStorage.isSessionValid();
      if (token == null || token.isEmpty || !isSessionValid) {
        debugPrint('🔔 [FCM] Postponing backend device registration: user is not authenticated yet.');
        return false;
      }
    }

    final platformStr = kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();
    final deviceIdStr = deviceId ?? _getOrCreatePersistentDeviceId();

    try {
      final response = await _apiClient.post(
        ApiEndpoints.registerDeviceToken,
        data: {
          'deviceToken': resolvedToken,
          'fcmToken': resolvedToken,
          'platform': platformStr,
          'role': role.name,
          'app': role.name.toLowerCase(),
          'deviceId': deviceIdStr,
        },
      );
      final data = response.data;
      if (data is Map && data['success'] == true) {
        return true;
      }
    } catch (_) {
      // Gracefully try role-specific fallback endpoint for customer / retailer
      if (role == UserRole.retailer || role == UserRole.customer) {
        final fallbackEndpoint = role == UserRole.retailer
            ? ApiEndpoints.retailerRegisterDevice
            : ApiEndpoints.customerRegisterDevice;
        try {
          await _apiClient.post(
            fallbackEndpoint,
            data: {
              'deviceToken': resolvedToken,
              'fcmToken': resolvedToken,
              'platform': platformStr,
              'deviceId': deviceIdStr,
              'role': role.name,
            },
          );
        } catch (e) {
          debugPrint('PushNotificationService: registerDevice fallback notice: $e');
        }
      }
    }
    return true;
  }

  @override
  Future<bool> unregisterDeviceWithBackend({required UserRole role}) async {
    if (_secureStorage != null) {
      final token = await _secureStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        return true;
      }
    }
    try {
      await _apiClient.post(
        ApiEndpoints.logout,
        data: {
          'deviceId': 'device_current',
          'fcmToken': _cachedToken ?? '',
        },
      );
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  void showInAppBanner(BuildContext context, PushNotificationPayload payload, {VoidCallback? onTap}) {
    if (!context.mounted) return;

    final isOrderType = payload.type?.contains('ORDER') == true;
    final isPromo = payload.type?.contains('PROMO') == true;

    Color bannerColor = const Color(0xFF0F766E); // Teal
    IconData icon = Icons.notifications_active_rounded;

    if (isOrderType) {
      bannerColor = const Color(0xFF0284C7); // Sky Blue
      icon = Icons.local_shipping_rounded;
    } else if (isPromo) {
      bannerColor = const Color(0xFFD97706); // Amber
      icon = Icons.local_offer_rounded;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 4),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: bannerColor.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bannerColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: bannerColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payload.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      payload.body,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    onTap();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: bannerColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: const Text('VIEW', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static const int _ongoingDeliveryNotifId = 9991;
  static const String _deliveryChannelId = 'quicktick_delivery_service';
  static const String _deliveryChannelName = 'QuickTick Delivery Duty Service';
  static const String _deliveryChannelDesc = 'Ongoing status notifications while online or on active delivery trips.';

  @override
  Future<void> showOngoingDeliveryNotification({
    required String title,
    required String body,
    String? subText,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        _deliveryChannelId,
        _deliveryChannelName,
        channelDescription: _deliveryChannelDesc,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        showWhen: true,
        subText: subText,
        icon: '@mipmap/ic_launcher',
      );
      await _localNotifs.show(
        _ongoingDeliveryNotifId,
        title,
        body,
        NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('⚠️ [Ongoing Notification Error]: $e');
    }
  }

  @override
  Future<void> cancelOngoingDeliveryNotification() async {
    try {
      await _localNotifs.cancel(_ongoingDeliveryNotifId);
    } catch (e) {
      debugPrint('⚠️ [Cancel Ongoing Notification Error]: $e');
    }
  }

  @override
  void simulateIncomingPush(PushNotificationPayload payload) {
    _notifStreamController.add(payload);
  }

  @override
  void dispose() {
    _notifStreamController.close();
  }
}
