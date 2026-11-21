import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/routing_service.dart';
import '../../../../core/services/websocket_service.dart';
import '../../../../core/services/network_connectivity_service.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../order/domain/entities/order_entity.dart';
import '../../../order/domain/repositories/order_repository.dart';
import '../widgets/order_rating_feedback_sheet.dart';

class CustomerLiveTrackingScreen extends StatefulWidget {
  final OrderEntity order;

  const CustomerLiveTrackingScreen({
    super.key,
    required this.order,
  });

  @override
  State<CustomerLiveTrackingScreen> createState() => _CustomerLiveTrackingScreenState();
}

class _CustomerLiveTrackingScreenState extends State<CustomerLiveTrackingScreen> {
  late OrderEntity _currentOrder;
  final MapController _mapController = MapController();
  final IWebSocketService _webSocketService = sl<IWebSocketService>();
  final IOrderRepository _orderRepo = sl<IOrderRepository>();
  final IRoutingService _routingService = sl<IRoutingService>();

  StreamSubscription? _orderRepoSub;
  StreamSubscription? _riderLocationSub;
  StreamSubscription? _orderStatusSub;
  StreamSubscription? _connectivitySub;
  Timer? _fallbackPollTimer;
  bool _isOffline = false;

  LatLng _riderLocation = const LatLng(12.9716, 77.5946);
  LatLng _storeLocation = const LatLng(12.9720, 77.5930);
  LatLng _customerLocation = const LatLng(12.9750, 77.6000);
  int _etaMins = 12;
  double _distanceKm = 0.0;
  bool _hasInitialRiderLocation = false;
  List<LatLng> _routePoints = [];
  // C-4 Fix: throttle OSRM route re-fetches to max 1 per 20s.
  // A city rider at 30 km/h triggers the >15m threshold every ~2s — without
  // throttling this becomes ~30 OSRM HTTP calls/min which hits rate limits.
  DateTime? _lastRouteRefresh;
  bool _hasAutoPromptedRating = false;

  void _checkAndPromptRating() {
    if (_currentOrder.status == OrderStatus.delivered && !_hasAutoPromptedRating && mounted) {
      _hasAutoPromptedRating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          OrderRatingFeedbackSheet.show(context, order: _currentOrder);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    if (sl.isRegistered<INetworkConnectivityService>()) {
      _isOffline = !sl<INetworkConnectivityService>().isConnected;
      _connectivitySub = sl<INetworkConnectivityService>().onConnectivityChanged.listen((online) {
        if (mounted) {
          setState(() => _isOffline = !online);
          if (online) {
            _setupWebSocketAndPolling();
          }
        }
      });
    }
    _resolveLocations();
    _setupWebSocketAndPolling();
    _checkAndPromptRating();
  }

  Future<void> _resolveLocations() async {
    final pos = await LocationService.getCurrentPosition(requestIfNeeded: false);
    if (pos != null && mounted) {
      setState(() {
        _customerLocation = LatLng(pos.latitude, pos.longitude);
        if (!_hasInitialRiderLocation) {
          _storeLocation = LatLng(pos.latitude - 0.008, pos.longitude - 0.006);
          _riderLocation = LatLng(pos.latitude - 0.005, pos.longitude - 0.004);
        }
      });
    }
    await _fetchRoadRoute();
    _fitMapBounds();
  }

  Future<void> _fetchRoadRoute() async {
    if (!mounted) return;
    final isDeliveryPhase = _currentOrder.status == OrderStatus.pickedUp ||
        _currentOrder.status == OrderStatus.outForDelivery;
    final destination = isDeliveryPhase ? _customerLocation : _storeLocation;

    final routeData = await _routingService.getRoute(
      start: _riderLocation,
      destination: destination,
    );

    if (mounted) {
      setState(() {
        _routePoints = routeData.points;
        _distanceKm = routeData.distanceKm;
        if (routeData.durationMinutes > 0) {
          _etaMins = routeData.durationMinutes;
        }
      });
    }
  }

  void _setupWebSocketAndPolling() {
    // 0. Listen to local order updates via repository stream
    _orderRepoSub = _orderRepo.ordersStream.listen((orders) {
      final updated = orders.where((o) => o.id == _currentOrder.id).firstOrNull;
      if (updated != null && mounted) {
        final prevStatus = _currentOrder.status;
        // Never revert an already delivered order
        if (prevStatus == OrderStatus.delivered && updated.status != OrderStatus.delivered) {
          return;
        }
        setState(() {
          _currentOrder = updated;
        });
        if (updated.status != prevStatus) {
          _fetchRoadRoute();
        }
      }
    });

    // 1. WebSocket: Subscribe to order room
    _webSocketService.connect();
    _webSocketService.subscribeOrder(_currentOrder.id);

    // 2. Listen to live rider:location events
    _riderLocationSub = _webSocketService.riderLocationStream.listen((data) {
      final String? incomingOrderId = data['orderId']?.toString() ?? data['id']?.toString();
      if (incomingOrderId == null || incomingOrderId == _currentOrder.id) {
        final double? lat = (data['latitude'] as num?)?.toDouble() ?? (data['lat'] as num?)?.toDouble();
        final double? lng = (data['longitude'] as num?)?.toDouble() ?? (data['lng'] as num?)?.toDouble();
        final int? eta = (data['etaMins'] as num?)?.toInt() ?? (data['eta'] as num?)?.toInt();

        if (lat != null && lng != null && mounted) {
          final newPos = LatLng(lat, lng);
          const distCalc = Distance();
          final movedDist = distCalc.as(LengthUnit.Meter, _riderLocation, newPos);

          List<LatLng>? decodedRoute;
          if (data['routePolyline'] is List) {
            final poly = data['routePolyline'] as List;
            decodedRoute = [];
            for (final pt in poly) {
              if (pt is List && pt.length >= 2) {
                final double pLng = (pt[0] as num).toDouble();
                final double pLat = (pt[1] as num).toDouble();
                decodedRoute.add(LatLng(pLat, pLng));
              }
            }
          }

          setState(() {
            _riderLocation = newPos;
            _hasInitialRiderLocation = true;
            if (eta != null) _etaMins = eta;
            if (decodedRoute != null && decodedRoute.isNotEmpty) {
              _routePoints = decodedRoute;
            }
          });
          _mapController.move(_riderLocation, _mapController.camera.zoom);

          if (decodedRoute == null && (movedDist > 15 || _routePoints.isEmpty)) {
            // C-4 Fix: throttle to at most 1 OSRM call per 20 seconds.
            final now = DateTime.now();
            final shouldRefresh = _lastRouteRefresh == null ||
                now.difference(_lastRouteRefresh!).inSeconds >= 20;
            if (shouldRefresh) {
              _lastRouteRefresh = now;
              _fetchRoadRoute();
            }
          }
        }
      }
    });

    // 3. Listen to order status updates (e.g. PICKED_UP, OUT_FOR_DELIVERY, DELIVERED)
    _orderStatusSub = _webSocketService.orderStatusStream.listen((data) {
      final String? incomingOrderId = data['orderId']?.toString() ?? data['id']?.toString();
      if (incomingOrderId == null || incomingOrderId == _currentOrder.id) {
        final String? newStatusStr = data['status']?.toString();
        if (newStatusStr != null && mounted) {
          final s = newStatusStr.toLowerCase();
          if (s == 'delivered') {
            setState(() {
              _currentOrder = _currentOrder.copyWith(status: OrderStatus.delivered);
            });
            _fetchRoadRoute();
            _checkAndPromptRating();
          }
          _refreshOrderState();
        }
      }
    });

    // 4. HTTP fallback polling: 10-15s when disconnected, 30s when connected
    _fallbackPollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!_webSocketService.isConnected || DateTime.now().second % 30 < 12) {
        _refreshOrderState();
      }
    });
  }

  Future<void> _refreshOrderState() async {
    try {
      final res = await _orderRepo.trackOrder(_currentOrder.id);
      res.fold(
        (_) {},
        (data) {
          if (!mounted) return;
          final previousStatus = _currentOrder.status;
          final orderMap = data['order'] is Map ? (data['order'] as Map) : data;

          setState(() {
            // ETA from tracking response
            final etaMap = (data['eta'] is Map)
                ? (data['eta'] as Map)
                : (orderMap['eta'] is Map ? (orderMap['eta'] as Map) : null);
            if (etaMap != null) {
              if (etaMap['durationMinutes'] != null) {
                _etaMins = (etaMap['durationMinutes'] as num).toInt();
              }
              if (etaMap['distanceKm'] != null) {
                _distanceKm = (etaMap['distanceKm'] as num).toDouble();
              }
            } else if (data['etaMinutes'] != null || orderMap['etaMinutes'] != null) {
              _etaMins = ((data['etaMinutes'] ?? orderMap['etaMinutes']) as num).toInt();
            } else if (data['etaMins'] != null || orderMap['etaMins'] != null) {
              _etaMins = ((data['etaMins'] ?? orderMap['etaMins']) as num).toInt();
            }

            final rawStatus = data['status'] ?? orderMap['status'];
            OrderStatus? newStatus;
            if (rawStatus is String) {
              final s = rawStatus.toLowerCase();
              if (s == 'delivered') {
                newStatus = OrderStatus.delivered;
              } else if (s == 'picked_up' || s == 'pickedup') {
                newStatus = OrderStatus.pickedUp;
              } else if (s == 'out_for_delivery' || s == 'outfordelivery') {
                newStatus = OrderStatus.outForDelivery;
              } else if (s == 'assigned') {
                newStatus = OrderStatus.assigned;
              } else if (s == 'ready_for_pickup') {
                newStatus = OrderStatus.readyForPickup;
              } else if (s == 'preparing') {
                newStatus = OrderStatus.preparing;
              }
            }

            // Never downgrade terminal DELIVERED status
            if (previousStatus == OrderStatus.delivered && newStatus != OrderStatus.delivered) {
              newStatus = OrderStatus.delivered;
            }

            // Parse rider / deliveryPartner object per backend conventions
            DeliveryPartnerInfoEntity? parsedRider;
            final riderMap = (data['rider'] is Map ? data['rider'] : null) ??
                (orderMap['rider'] is Map ? orderMap['rider'] : null) ??
                (data['deliveryPartner'] is Map ? data['deliveryPartner'] : null) ??
                (orderMap['deliveryPartner'] is Map ? orderMap['deliveryPartner'] : null) ??
                (data['deliveryPartnerId'] is Map ? data['deliveryPartnerId'] : null) ??
                (orderMap['deliveryPartnerId'] is Map ? orderMap['deliveryPartnerId'] : null);

            if (riderMap is Map) {
              parsedRider = DeliveryPartnerInfoEntity.fromJson(
                Map<String, dynamic>.from(riderMap),
              );
            }

            String? partnerName = (parsedRider?.name.isNotEmpty == true && parsedRider!.name != 'Delivery Partner')
                ? parsedRider.name
                : data['deliveryPartnerName']?.toString() ??
                    orderMap['deliveryPartnerName']?.toString() ??
                    data['riderName']?.toString() ??
                    orderMap['riderName']?.toString() ??
                    parsedRider?.name;

            String? partnerPhone = (parsedRider?.phone.isNotEmpty == true)
                ? parsedRider!.phone
                : data['deliveryPartnerPhone']?.toString() ??
                    orderMap['deliveryPartnerPhone']?.toString() ??
                    data['riderPhone']?.toString() ??
                    orderMap['riderPhone']?.toString() ??
                    data['riderMobile']?.toString() ??
                    orderMap['riderMobile']?.toString();

            final rawPartnerId = (parsedRider?.id.isNotEmpty == true)
                ? parsedRider!.id
                : (data['deliveryPartnerId'] is String
                    ? data['deliveryPartnerId'] as String
                    : (orderMap['deliveryPartnerId'] is String ? orderMap['deliveryPartnerId'] as String : null));

            if (newStatus != null || partnerName != null || partnerPhone != null || parsedRider != null || rawPartnerId != null) {
              _currentOrder = _currentOrder.copyWith(
                status: newStatus ?? _currentOrder.status,
                deliveryPartnerId: rawPartnerId ?? _currentOrder.deliveryPartnerId,
                deliveryPartner: parsedRider ?? _currentOrder.deliveryPartner,
                deliveryPartnerName: partnerName ?? _currentOrder.deliveryPartnerName,
                deliveryPartnerPhone: partnerPhone ?? _currentOrder.deliveryPartnerPhone,
              );
              if (_currentOrder.status == OrderStatus.delivered) {
                _checkAndPromptRating();
              }
            }

            // 1. Live coordinates directly from rider object if available
            if (parsedRider != null && parsedRider.latitude != null && parsedRider.longitude != null) {
              _riderLocation = LatLng(parsedRider.latitude!, parsedRider.longitude!);
              _hasInitialRiderLocation = true;
            } else {
              final locMap = (data['riderLocation'] is Map ? data['riderLocation'] : null) ??
                  (orderMap['riderLocation'] is Map ? orderMap['riderLocation'] : null);
              if (locMap is Map) {
                final lat = (locMap['latitude'] ?? locMap['lat']) as num?;
                final lng = (locMap['longitude'] ?? locMap['lng']) as num?;
                if (lat != null && lng != null) {
                  _riderLocation = LatLng(lat.toDouble(), lng.toDouble());
                  _hasInitialRiderLocation = true;
                }
              } else {
                final rLat = data['riderLatitude'] ?? orderMap['riderLatitude'];
                final rLng = data['riderLongitude'] ?? orderMap['riderLongitude'];
                if (rLat != null && rLng != null) {
                  _riderLocation = LatLng((rLat as num).toDouble(), (rLng as num).toDouble());
                  _hasInitialRiderLocation = true;
                }
              }
            }

            final sloc = (data['storeLocation'] is Map ? data['storeLocation'] : null) ??
                (orderMap['storeLocation'] is Map ? orderMap['storeLocation'] : null);
            if (sloc is Map) {
              final slat = (sloc['latitude'] ?? sloc['lat']) as num?;
              final slng = (sloc['longitude'] ?? sloc['lng']) as num?;
              if (slat != null && slng != null) {
                _storeLocation = LatLng(slat.toDouble(), slng.toDouble());
              }
            } else {
              final sLat = data['storeLatitude'] ?? orderMap['storeLatitude'];
              final sLng = data['storeLongitude'] ?? orderMap['storeLongitude'];
              if (sLat != null && sLng != null) {
                _storeLocation = LatLng((sLat as num).toDouble(), (sLng as num).toDouble());
              }
            }

            if (data['customerLocation'] is Map || data['addressSnapshot'] is Map) {
              final cloc = (data['customerLocation'] ?? data['addressSnapshot']) as Map;
              final clat = (cloc['latitude'] ?? cloc['lat']) as num?;
              final clng = (cloc['longitude'] ?? cloc['lng']) as num?;
              if (clat != null && clng != null) {
                _customerLocation = LatLng(clat.toDouble(), clng.toDouble());
              }
            } else if (data['customerLatitude'] != null && data['customerLongitude'] != null) {
              _customerLocation = LatLng(
                (data['customerLatitude'] as num).toDouble(),
                (data['customerLongitude'] as num).toDouble(),
              );
            }

            if (data['routePolyline'] is List) {
              final poly = data['routePolyline'] as List;
              final List<LatLng> decoded = [];
              for (final pt in poly) {
                if (pt is List && pt.length >= 2) {
                  final double pLng = (pt[0] as num).toDouble();
                  final double pLat = (pt[1] as num).toDouble();
                  decoded.add(LatLng(pLat, pLng));
                }
              }
              if (decoded.isNotEmpty) {
                _routePoints = decoded;
              }
            }
          });

          if (_currentOrder.status != previousStatus) {
            if (_routePoints.isEmpty) {
              _fetchRoadRoute();
            }
            _fitMapBounds();
          }
        },
      );
    } catch (_) {}
  }

  void _fitMapBounds() {
    final points = _routePoints.isNotEmpty
        ? _routePoints
        : [_customerLocation, _storeLocation, _riderLocation];
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.only(top: 140, bottom: 270, left: 45, right: 45),
      ),
    );
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _webSocketService.unsubscribeOrder(_currentOrder.id);
    _orderRepoSub?.cancel();
    _riderLocationSub?.cancel();
    _orderStatusSub?.cancel();
    _fallbackPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _callRider(String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rider phone number not available')),
      );
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKn = context.isKannada;
    final status = _currentOrder.status;
    final isDelivered = status == OrderStatus.delivered;
    final isOutForDelivery = status == OrderStatus.outForDelivery;
    final isPickedUp = status == OrderStatus.pickedUp;
    final storeName = AppStrings.resolveStoreName(_currentOrder.storeId, _currentOrder.storeName, isKannada: isKn);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // 1. Live Interactive Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _customerLocation,
              initialZoom: 14.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.quicktick.app',
                tileProvider: NetworkTileProvider(
                  headers: {
                    'User-Agent': 'QuickLinkCustomer/1.0 (Android; support@quicklink.app)',
                  },
                ),
                maxZoom: 19,
                errorTileCallback: (tile, error, stackTrace) {},
              ),
              PolylineLayer(
                polylines: [
                  if (_routePoints.isNotEmpty)
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5.5,
                      color: const Color(0xFF0D9488),
                      borderStrokeWidth: 2.5,
                      borderColor: const Color(0xFF134E4A),
                    )
                  else
                    Polyline(
                      points: [_riderLocation, isOutForDelivery || isPickedUp ? _customerLocation : _storeLocation],
                      strokeWidth: 4.0,
                      color: const Color(0xFF0D9488),
                      borderStrokeWidth: 2.0,
                      borderColor: const Color(0xFF134E4A),
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // Store Pickup Marker
                  Marker(
                    point: _storeLocation,
                    width: 100,
                    height: 60,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF38BDF8), width: 1),
                          ),
                          child: Text(
                            storeName.length > 12
                                ? '${storeName.substring(0, 10)}...'
                                : storeName,
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
                            ],
                          ),
                          child: const Icon(Icons.store, color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                  ),
                  // Customer Destination Marker
                  Marker(
                    point: _customerLocation,
                    width: 90,
                    height: 60,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFEF4444), width: 1),
                          ),
                          child: Text(
                            isKn ? 'ವಿತರಣೆ' : 'Delivery',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
                            ],
                          ),
                          child: const Icon(Icons.home_filled, color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                  ),
                  // Live Moving Rider Marker with Live ETA Pill
                  Marker(
                    point: _riderLocation,
                    width: 70,
                    height: 72,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                          ),
                          child: Text(
                            '${_etaMins}m',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.45),
                                blurRadius: 14,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.two_wheeler, color: Colors.white, size: 24),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. Top Header with Back Button & ETA Banner
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white12),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isDelivered
                                      ? (isKn ? 'ಯಶಸ್ವಿಯಾಗಿ ತಲುಪಿಸಲಾಗಿದೆ! 🎉' : 'Delivered Successfully! 🎉')
                                      : isOutForDelivery
                                          ? (isKn
                                              ? '$_etaMins ನಿಮಿಷಗಳಲ್ಲಿ ತಲುಪಲಿದೆ 🛵 • ${_distanceKm > 0 ? '${_distanceKm.toStringAsFixed(1)} ಕಿ.ಮೀ' : 'ಸಮೀಪದಲ್ಲಿದೆ'}'
                                              : 'Arriving in $_etaMins mins 🛵 • ${_distanceKm > 0 ? '${_distanceKm.toStringAsFixed(1)} km' : 'Nearby'}')
                                          : isPickedUp
                                              ? (isKn ? 'ಆರ್ಡರ್ ಪಡೆಯಲಾಗಿದೆ • ದಾರಿಯಲ್ಲಿದೆ 🛵' : 'Order Picked Up • On the way 🛵')
                                              : (status == OrderStatus.assigned
                                                  ? (isKn ? 'ಡೆಲಿವರಿ ಪಾರ್ಟ್ನರ್ ನಿಯೋಜಿಸಲಾಗಿದೆ 🛵 • ಅಂಗಡಿಗೆ ತೆರಳುತ್ತಿದ್ದಾರೆ' : 'Delivery Partner Assigned 🛵 • Heading to store')
                                                  : (isKn ? '$storeName ನಲ್ಲಿ ಸಿದ್ಧವಾಗುತ್ತಿದೆ 🏪' : 'Order preparing at $storeName 🏪')),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _fitMapBounds,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Icon(Icons.my_location, color: Color(0xFF38BDF8), size: 20),
                        ),
                      ),
                    ],
                  ),
                  if (_isOffline) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            isKn ? 'ಆಫ್‌ಲೈನ್ • ಕೊನೆಯ ತಿಳಿದಿರುವ ಸ್ಥಳ ತೋರಿಸಲಾಗುತ್ತಿದೆ' : 'Offline • Showing last known rider location',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 3. Bottom Sliding Details Card
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, -4)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),

                  // Status Stepper Progress
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStep(Icons.check_circle, isKn ? 'ಸ್ವೀಕರಿಸಲಾಗಿದೆ' : 'Placed', true),
                      _buildStepDivider(status.stepIndex >= 2),
                      _buildStep(Icons.soup_kitchen, isKn ? 'ಸಿದ್ಧಪಡಿಸಲಾಗುತ್ತಿದೆ' : 'Preparing', status.stepIndex >= 2),
                      _buildStepDivider(status.stepIndex >= 5),
                      _buildStep(Icons.delivery_dining, isKn ? 'ದಾರಿಯಲ್ಲಿದೆ' : 'On the way', status.stepIndex >= 5),
                      _buildStepDivider(isDelivered),
                      _buildStep(Icons.home, isKn ? 'ತಲುಪಿಸಲಾಗಿದೆ' : 'Delivered', isDelivered),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 28),

                  // Delivery Partner / Driver Details
                  Builder(
                    builder: (context) {
                      final dp = _currentOrder.deliveryPartner;
                      final bool hasPartner = dp != null ||
                          (_currentOrder.deliveryPartnerName != null &&
                              _currentOrder.deliveryPartnerName!.isNotEmpty) ||
                          (_currentOrder.deliveryPartnerId != null &&
                              _currentOrder.deliveryPartnerId!.isNotEmpty) ||
                          status == OrderStatus.assigned ||
                          status == OrderStatus.pickedUp ||
                          status == OrderStatus.outForDelivery;

                      if (!hasPartner && !isDelivered) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFFF59E0B), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isKn ? 'ಡೆಲಿವರಿ ಪಾರ್ಟ್ನರ್ ಹುಡುಕಲಾಗುತ್ತಿದೆ...' : 'Assigning Delivery Partner...',
                                      style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isKn ? 'ನಿಮ್ಮ ಆರ್ಡರ್‌ಗಾಗಿ ಹತ್ತಿರದ ರೈಡರ್‌ಗಳನ್ನು ಸಂಪರ್ಕಿಸಲಾಗುತ್ತಿದೆ' : 'Finding the nearest available rider for your order',
                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final defaultPartnerName = isKn ? 'ಡೆಲಿವರಿ ಪಾರ್ಟ್ನರ್ ನಿಯೋಜಿಸಲಾಗಿದೆ' : 'Delivery Partner Assigned';
                      final partnerName = (dp?.name.isNotEmpty == true && dp!.name != 'Delivery Partner')
                          ? dp.name
                          : (_currentOrder.deliveryPartnerName?.isNotEmpty == true
                              ? _currentOrder.deliveryPartnerName!
                              : defaultPartnerName);
                      final partnerPhone = (dp?.phone.isNotEmpty == true)
                          ? dp!.phone
                          : _currentOrder.deliveryPartnerPhone;
                      final vehicleBadge = dp != null && (dp.vehicleType.isNotEmpty || dp.vehicleNumber.isNotEmpty)
                          ? '${dp.vehicleType} • ${dp.vehicleNumber}'.trim()
                          : null;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            // Driver Avatar or Icon
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                image: (dp?.avatarUrl != null && dp!.avatarUrl!.isNotEmpty)
                                    ? DecorationImage(
                                        image: NetworkImage(dp.avatarUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: (dp?.avatarUrl == null || dp!.avatarUrl!.isEmpty)
                                  ? const Icon(Icons.delivery_dining_rounded, color: Color(0xFF10B981), size: 26)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          partnerName,
                                          style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (dp != null && dp.rating > 0) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFBBF24)),
                                              const SizedBox(width: 2),
                                              Text(
                                                dp.rating.toStringAsFixed(1),
                                                style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 2,
                                    children: [
                                      if (vehicleBadge != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F172A),
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(color: Colors.white12),
                                          ),
                                          child: Text(
                                            vehicleBadge,
                                            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      if (dp != null && dp.totalDeliveries > 0)
                                        Text(
                                          isKn ? '${dp.totalDeliveries} ಟ್ರಿಪ್‌ಗಳು' : '${dp.totalDeliveries} trips',
                                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                                        ),
                                      if (vehicleBadge == null && (dp == null || dp.totalDeliveries <= 0))
                                        Text(
                                          isDelivered
                                              ? (isKn ? 'ಟ್ರಿಪ್ ಪೂರ್ಣಗೊಂಡಿದೆ' : 'Trip completed')
                                              : (isKn ? 'ವೇಗದ ಮತ್ತು ಸುರಕ್ಷಿತ ವಿತರಣೆ' : 'Fast & contactless delivery'),
                                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Call Rider Button
                            if (partnerPhone != null && partnerPhone.isNotEmpty && !isDelivered)
                              IconButton.filled(
                                onPressed: () => _callRider(partnerPhone),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  shape: const CircleBorder(),
                                ),
                                icon: const Icon(Icons.phone_rounded, size: 20),
                                tooltip: isKn ? 'ಡೆಲಿವರಿ ಪಾರ್ಟ್ನರ್‌ಗೆ ಕರೆ ಮಾಡಿ' : 'Call Delivery Partner',
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Delivery OTP Share Container
                  if (_currentOrder.deliveryOtp.isNotEmpty && !isDelivered)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.pin, color: Color(0xFF10B981), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                isKn ? 'ಡೆಲಿವರಿ OTP ಕೋಡ್:' : 'Delivery OTP Code:',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _currentOrder.deliveryOtp,
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),
                  // Store & Destination row
                  Row(
                    children: [
                      const Icon(Icons.store, color: Color(0xFF38BDF8), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          storeName,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${isKn ? 'ಒಟ್ಟು' : 'Total'}: ₹${_currentOrder.grandTotal.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                  // Post-Delivery Feedback Trigger Button
                  if (isDelivered) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () => OrderRatingFeedbackSheet.show(context, order: _currentOrder),
                        icon: const Icon(Icons.star_rounded, color: Color(0xFFFDE68A), size: 20),
                        label: Text(
                          isKn ? 'ಅಂಗಡಿ ಮತ್ತು ಡೆಲಿವರಿ ರೇಟಿಂಗ್ ನೀಡಿ' : 'Rate Store & Delivery Experience',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(IconData icon, String label, bool isActive) {
    return Column(
      children: [
        Icon(
          icon,
          size: 18,
          color: isActive ? const Color(0xFF10B981) : Colors.white24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white38,
            fontSize: 9,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        color: isActive ? const Color(0xFF10B981) : Colors.white12,
      ),
    );
  }
}
