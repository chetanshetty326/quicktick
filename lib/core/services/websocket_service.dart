import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../network/api_endpoints.dart';
import '../security/secure_storage_service.dart';

/// Clean Architecture WebSocket Service for QuickTick real-time events.
/// Handles connection lifecycle, auto-reconnect, JWT authentication,
/// and typed streams for order tracking, location updates, and notifications.
abstract class IWebSocketService {
  Stream<Map<String, dynamic>> get orderStatusStream;
  Stream<Map<String, dynamic>> get locationStream;
  Stream<Map<String, dynamic>> get riderLocationStream;
  Stream<Map<String, dynamic>> get notificationStream;
  Stream<Map<String, dynamic>> get criticalAlertStream;
  Stream<Map<String, dynamic>> get bannerUpdateStream;
  Stream<bool> get connectionStateStream;

  bool get isConnected;
  Future<void> connect();
  void disconnect();
  void subscribeOrder(String orderId);
  void unsubscribeOrder(String orderId);
  void emitRiderLocation({
    required String orderId,
    required double latitude,
    required double longitude,
    int? etaMins,
  });
  void emitOrderStatus({
    required String orderId,
    required String status,
  });
  void dispose();
}

class WebSocketService implements IWebSocketService {
  final ISecureStorageService _secureStorage;
  io.Socket? _socket;

  final _orderStatusController = StreamController<Map<String, dynamic>>.broadcast();
  final _locationController = StreamController<Map<String, dynamic>>.broadcast();
  final _riderLocationController = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  final _criticalAlertController = StreamController<Map<String, dynamic>>.broadcast();
  final _bannerUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  final Set<String> _subscribedOrders = {};
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isDisposed = false;

  WebSocketService(this._secureStorage);

  @override
  Stream<Map<String, dynamic>> get orderStatusStream => _orderStatusController.stream;

  @override
  Stream<Map<String, dynamic>> get locationStream => _locationController.stream;

  @override
  Stream<Map<String, dynamic>> get riderLocationStream => _riderLocationController.stream;

  @override
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;

  @override
  Stream<Map<String, dynamic>> get criticalAlertStream => _criticalAlertController.stream;

  @override
  Stream<Map<String, dynamic>> get bannerUpdateStream => _bannerUpdateController.stream;

  @override
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  @override
  bool get isConnected => _isConnected;

  void _scheduleReconnect() {
    if (_isDisposed) return;
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;

    _reconnectAttempts++;
    final delaySec = (_reconnectAttempts * 3).clamp(3, 15);
    debugPrint('🔄 [WebSocket] Reconnect scheduled in ${delaySec}s (attempt #$_reconnectAttempts)');

    _reconnectTimer = Timer(Duration(seconds: delaySec), () {
      if (_isDisposed) return;
      if (!_isConnected) {
        debugPrint('🔄 [WebSocket] Attempting scheduled reconnection now...');
        connect();
      }
    });
  }

  @override
  Future<void> connect() async {
    if (_isDisposed) return;
    if (_socket != null && _socket!.connected) {
      _isConnected = true;
      return;
    }
    if (_isConnecting) return;
    _isConnecting = true;

    try {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;

      // Clean up previous socket instance cleanly
      if (_socket != null) {
        try {
          _socket!.clearListeners();
          _socket!.dispose();
        } catch (_) {}
        _socket = null;
      }

      final token = await _secureStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        debugPrint('ℹ️ [WebSocket] No auth token found. Skipping connection until user logs in.');
        _isConnecting = false;
        return;
      }

      // Configure socket.io options conforming to backend spec
      final socketUri = ApiEndpoints.baseUrl.replaceFirst('/api/v1', '');
      
      // Verify DNS readiness before opening raw socket connection
      final host = Uri.parse(socketUri).host;
      if (host.isNotEmpty) {
        try {
          final ips = await InternetAddress.lookup(host).timeout(const Duration(seconds: 2));
          if (ips.isEmpty) {
            debugPrint('⚠️ [WebSocket] DNS returned no addresses for $host. Scheduling retry...');
            _isConnecting = false;
            _scheduleReconnect();
            return;
          }
        } catch (dnsErr) {
          debugPrint('⚠️ [WebSocket] DNS resolution pending for $host: $dnsErr. Scheduling retry in 3s...');
          _isConnecting = false;
          _scheduleReconnect();
          return;
        }
      }

      debugPrint('⚡ [WebSocket] Connecting to $socketUri ...');

      _socket = io.io(
        socketUri,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setPath('/socket.io/')
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(2000)
            .setReconnectionAttempts(10)
            .setAuth({
              'token': token,
            })
            .setExtraHeaders({
              'Authorization': 'Bearer $token',
            })
            .build(),
      );

      _socket!.onConnect((_) {
        debugPrint('⚡ [WebSocket] Connected to QuickTick Real-Time Engine (id: ${_socket!.id})');
        _isConnected = true;
        _isConnecting = false;
        _reconnectAttempts = 0;
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        _connectionStateController.add(true);

        // Re-subscribe to any active tracked orders
        for (final orderId in _subscribedOrders) {
          debugPrint('📡 [WebSocket] Resubscribing to order: $orderId');
          _socket!.emit('subscribe:order', {'orderId': orderId});
        }

        // Trigger a fresh hero banner sync after reconnect so edits/deletions while offline are caught
        _bannerUpdateController.add(const {'event': 'connected'});
      });

      _socket!.onDisconnect((reason) {
        debugPrint('⚠️ [WebSocket] Disconnected from QuickTick Real-Time Engine: $reason');
        _isConnected = false;
        _isConnecting = false;
        _connectionStateController.add(false);
        _scheduleReconnect();
      });

      _socket!.onConnectError((err) {
        debugPrint('❌ [WebSocket] Connection Error: $err');
        _isConnected = false;
        _isConnecting = false;
        _connectionStateController.add(false);
        _scheduleReconnect();
      });

      _socket!.onError((err) {
        debugPrint('⚠️ [WebSocket] Socket error: $err');
        _scheduleReconnect();
      });

      // 1. Order Status Updates & New Order Broadcasts
      _socket!.on('order:status:changed', (data) {
        debugPrint('📦 [WebSocket] Event: order:status:changed -> $data');
        if (data is Map) {
          _orderStatusController.add(Map<String, dynamic>.from(data));
        }
      });
      _socket!.on('order:created', (data) {
        debugPrint('📦 [WebSocket] Event: order:created -> $data');
        if (data is Map) {
          final payload = Map<String, dynamic>.from(data);
          payload['status'] ??= 'PLACED';
          _orderStatusController.add(payload);
        }
      });
      _socket!.on('order:new', (data) {
        debugPrint('📦 [WebSocket] Event: order:new -> $data');
        if (data is Map) {
          final payload = Map<String, dynamic>.from(data);
          payload['status'] ??= 'PLACED';
          _orderStatusController.add(payload);
        }
      });
      _socket!.on('order:placed', (data) {
        debugPrint('📦 [WebSocket] Event: order:placed -> $data');
        if (data is Map) {
          final payload = Map<String, dynamic>.from(data);
          payload['status'] ??= 'PLACED';
          _orderStatusController.add(payload);
        }
      });

      // 2. Order Delivered Alert
      _socket!.on('order:delivered', (data) {
        debugPrint('🎉 [WebSocket] Event: order:delivered -> $data');
        if (data is Map) {
          final payload = Map<String, dynamic>.from(data);
          payload['status'] = 'DELIVERED';
          _orderStatusController.add(payload);
        }
      });

      // 3. Live Delivery Partner Location Update (Frontend Integration Spec: rider:location)
      _socket!.on('rider:location', (data) {
        debugPrint('📍 [WebSocket] Event: rider:location -> $data');
        if (data is Map) {
          final mapped = Map<String, dynamic>.from(data);
          _riderLocationController.add(mapped);
          _locationController.add(mapped);
        }
      });
      _socket!.on('location:updated', (data) {
        debugPrint('📍 [WebSocket] Event: location:updated -> $data');
        if (data is Map) {
          final mapped = Map<String, dynamic>.from(data);
          _riderLocationController.add(mapped);
          _locationController.add(mapped);
        }
      });

      // 4. In-App Notifications
      _socket!.on('notification', (data) {
        debugPrint('🔔 [WebSocket] Event: notification -> $data');
        if (data is Map) {
          _notificationController.add(Map<String, dynamic>.from(data));
        }
      });

      // 5. Delivery Assigned Event
      _socket!.on('delivery:assigned', (data) {
        debugPrint('🛵 [WebSocket] Event: delivery:assigned -> $data');
        if (data is Map) {
          _notificationController.add(Map<String, dynamic>.from(data));
        }
      });

      // 6. Critical Alert Event
      _socket!.on('critical:alert', (data) {
        debugPrint('🚨 [WebSocket] Event: critical:alert -> $data');
        if (data is Map) {
          _criticalAlertController.add(Map<String, dynamic>.from(data));
        }
      });

      // 7. Real-time Hero Banner Updates (create, update, toggle, delete)
      for (final bannerEvent in const [
        'hero-banners:updated',
        'hero-banner:created',
        'hero-banner:updated',
        'hero-banner:deleted',
        'heroBanner:created',
        'heroBanner:updated',
        'heroBanner:deleted',
        'banner:created',
        'banner:updated',
        'banner:deleted',
        'banners:updated',
      ]) {
        _socket!.on(bannerEvent, (data) {
          debugPrint('🖼️ [WebSocket] Event: $bannerEvent -> $data');
          final payload = data is Map
              ? <String, dynamic>{...Map<String, dynamic>.from(data), 'event': bannerEvent}
              : <String, dynamic>{'event': bannerEvent};
          _bannerUpdateController.add(payload);
        });
      }
    } catch (e) {
      debugPrint('❌ [WebSocket] Initialization failed: $e');
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  @override
  void subscribeOrder(String orderId) {
    if (orderId.isEmpty) return;
    _subscribedOrders.add(orderId);
    if (_socket != null && _socket!.connected) {
      debugPrint('📡 [WebSocket] Subscribing to order: $orderId');
      _socket!.emit('subscribe:order', {'orderId': orderId});
    }
  }

  @override
  void unsubscribeOrder(String orderId) {
    if (orderId.isEmpty) return;
    _subscribedOrders.remove(orderId);
    if (_socket != null && _socket!.connected) {
      debugPrint('📡 [WebSocket] Unsubscribing from order: $orderId');
      _socket!.emit('unsubscribe:order', {'orderId': orderId});
    }
  }

  @override
  void emitRiderLocation({
    required String orderId,
    required double latitude,
    required double longitude,
    int? etaMins,
  }) {
    final payload = <String, dynamic>{
      'orderId': orderId,
      'id': orderId,
      'latitude': latitude,
      'longitude': longitude,
      'lat': latitude,
      'lng': longitude,
    };
    if (etaMins != null) {
      payload['etaMins'] = etaMins;
      payload['eta'] = etaMins;
    }
    if (_socket != null && _socket!.connected) {
      _socket!.emit('rider:location', payload);
      _socket!.emit('rider:location:update', payload);
    }
    // Broadcast locally so cross-app / in-memory tracking screens receive updates immediately
    _riderLocationController.add(payload);
    _locationController.add(payload);
  }

  @override
  void emitOrderStatus({
    required String orderId,
    required String status,
  }) {
    final payload = {
      'orderId': orderId,
      'id': orderId,
      'status': status,
    };
    if (_socket != null && _socket!.connected) {
      _socket!.emit('order:status:changed', payload);
      if (status.toUpperCase() == 'DELIVERED') {
        _socket!.emit('order:delivered', payload);
      }
    }
    _orderStatusController.add(payload);
  }

  @override
  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isConnecting = false;
    _isConnected = false;
    if (_socket != null) {
      try {
        _socket!.clearListeners();
        _socket!.disconnect();
        _socket!.dispose();
      } catch (_) {}
      _socket = null;
    }
    _connectionStateController.add(false);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _subscribedOrders.clear();
    disconnect();
    _orderStatusController.close();
    _locationController.close();
    _riderLocationController.close();
    _notificationController.close();
    _criticalAlertController.close();
    _bannerUpdateController.close();
    _connectionStateController.close();
  }
}
