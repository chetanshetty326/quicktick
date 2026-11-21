import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/routing_service.dart';
import '../../../order/domain/entities/order_entity.dart';
import '../../domain/entities/delivery_models.dart';
import '../../domain/entities/delivery_api_entities.dart';
import '../bloc/delivery_bloc.dart';
import '../widgets/delivery_sos_sheet.dart';
import '../widgets/doorstep_payment_collection_sheet.dart';
import 'delivery_main_screen.dart';

class DeliveryActiveNavigationScreen extends StatefulWidget {
  final OrderEntity order;
  final bool isEmbedded;
  final VoidCallback? onBackToRadar;

  const DeliveryActiveNavigationScreen({
    super.key,
    required this.order,
    this.isEmbedded = false,
    this.onBackToRadar,
  });

  @override
  State<DeliveryActiveNavigationScreen> createState() => _DeliveryActiveNavigationScreenState();
}

class _DeliveryActiveNavigationScreenState extends State<DeliveryActiveNavigationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final MapController _mapController = MapController();

  LatLng _riderPosition = const LatLng(12.9716, 77.5946);
  late LatLng _storePosition;
  late LatLng _customerPosition;
  bool _isMapInteractive = true;
  final double _currentZoom = 15.0;

  Timer? _liveGpsTimer;
  IRoutingService? _routingService;
  List<LatLng> _routePoints = [];
  double _distanceKm = 0.0;
  int _etaMins = 0;

  @override
  void initState() {
    super.initState();
    _routingService = sl.isRegistered<IRoutingService>() ? sl<IRoutingService>() : RoutingServiceImpl();

    final bloc = context.read<DeliveryBloc>();
    final job = bloc.state.apiJobs.cast<DeliveryJobEntity?>().firstWhere(
          (j) => j?.id == widget.order.id,
          orElse: () => null,
        );
    if (job?.storeLatitude != null && job?.storeLongitude != null) {
      _storePosition = LatLng(job!.storeLatitude!, job.storeLongitude!);
    } else {
      _storePosition = LatLng(_riderPosition.latitude + 0.0038, _riderPosition.longitude - 0.0032);
    }

    if (job?.customerLatitude != null && job?.customerLongitude != null) {
      _customerPosition = LatLng(job!.customerLatitude!, job.customerLongitude!);
    } else {
      _customerPosition = LatLng(_riderPosition.latitude - 0.0045, _riderPosition.longitude + 0.0055);
    }
    _initLiveGpsLocation();
    _startLiveGpsTracking();
  }

  Future<void> _fetchRoadRoute({DeliveryTripStep? currentStep}) async {
    if (!mounted || _routingService == null) return;
    final activeStep = currentStep ?? context.read<DeliveryBloc>().state.activeJobStep;
    final isEnRouteCustomer = activeStep.index >= DeliveryTripStep.orderPickedUp.index;
    final destination = isEnRouteCustomer ? _customerPosition : _storePosition;

    final routeData = await _routingService!.getRoute(
      start: _riderPosition,
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

  Future<void> _initLiveGpsLocation() async {
    try {
      final pos = await LocationService.getCurrentPosition(requestIfNeeded: false);
      if (pos != null && mounted) {
        setState(() {
          _riderPosition = LatLng(pos.latitude, pos.longitude);
        });
        _mapController.move(_riderPosition, _currentZoom);
        await _fetchRoadRoute();
      }
    } catch (_) {}
  }

  void _startLiveGpsTracking() {
    _liveGpsTimer?.cancel();
    // Live GPS telemetry tracking interval: every 6s during active navigation
    _liveGpsTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
      if (!mounted) return;
      try {
        final pos = await LocationService.getCurrentPosition(requestIfNeeded: false);
        if (pos != null && mounted) {
          final newPos = LatLng(pos.latitude, pos.longitude);
          const distCalc = Distance();
          final movedDist = distCalc.as(LengthUnit.Meter, _riderPosition, newPos);

          setState(() {
            _riderPosition = newPos;
          });

          // Dispatch location ping to DeliveryBloc — the bloc handler
          // calls emitRiderLocation() on IWebSocketService for all active trips,
          // including the rider's OSRM-computed ETA so the customer sees an
          // accurate arrival time rather than their own re-calculated estimate.
          context.read<DeliveryBloc>().add(
                UpdateLocationPingEvent(
                  lat: pos.latitude,
                  lng: pos.longitude,
                  etaMins: _etaMins > 0 ? _etaMins : null,
                ),
              );

          if (movedDist > 15 || _routePoints.isEmpty) {
            _fetchRoadRoute();
          }
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _liveGpsTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _showOtpModal(BuildContext context) {
    final deliveryBloc = context.read<DeliveryBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: DoorstepPaymentCollectionSheet(
            order: widget.order,
            onDismiss: () {
              Navigator.of(ctx).pop();
            },
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted) {
        deliveryBloc.add(const StopQrPollingEvent());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DeliveryBloc, DeliveryState>(
      listenWhen: (prev, curr) =>
          prev.activeJobStep != curr.activeJobStep ||
          prev.errorMessage != curr.errorMessage ||
          prev.successMessage != curr.successMessage,
      listener: (context, state) {
        if (state.activeJobStep != DeliveryTripStep.completed) {
          _fetchRoadRoute(currentStep: state.activeJobStep);
        }

        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }

        if (state.activeJobStep == DeliveryTripStep.completed) {
          _showTripCompletedCelebration(context, state);
        }
      },
      builder: (context, state) {
        final step = state.activeJobStep;

        final content = Column(
          children: [
            if (widget.isEmbedded)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF0F172A),
                child: Row(
                  children: [
                    if (widget.onBackToRadar != null) ...[
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        tooltip: 'Back to Radar',
                        onPressed: widget.onBackToRadar,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        'Active Trip • #${widget.order.orderNumber}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getShortStepLabel(step),
                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Interactive Live OpenStreetMap Visualizer with GPS Telemetry
              Expanded(
                flex: 4,
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFF1E293B),
                  child: Stack(
                    children: [
                      // Live OpenStreetMap or Schematic Fallback
                      if (_isMapInteractive)
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _riderPosition,
                            initialZoom: _currentZoom,
                            minZoom: 4,
                            maxZoom: 19,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.quicktick.app',
                              tileProvider: NetworkTileProvider(
                                headers: {
                                  'User-Agent': 'QuickLinkDelivery/1.0 (Android; support@quicklink.app)',
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
                                    color: const Color(0xFF38BDF8),
                                    borderStrokeWidth: 2.5,
                                    borderColor: const Color(0xFF0369A1),
                                  )
                                else
                                  Polyline(
                                    points: [
                                      _riderPosition,
                                      step.index >= DeliveryTripStep.orderPickedUp.index
                                          ? _customerPosition
                                          : _storePosition,
                                    ],
                                    strokeWidth: 4.5,
                                    color: const Color(0xFF38BDF8),
                                  ),
                              ],
                            ),
                            MarkerLayer(
                              markers: [
                                // Store Pin
                                Marker(
                                  point: _storePosition,
                                  width: 100,
                                  height: 62,
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
                                          widget.order.storeName.length > 11
                                              ? '${widget.order.storeName.substring(0, 9)}...'
                                              : widget.order.storeName,
                                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                        ),
                                      ),
                                      const Icon(Icons.storefront, color: Color(0xFF38BDF8), size: 28),
                                    ],
                                  ),
                                ),
                                // Customer Pin
                                Marker(
                                  point: _customerPosition,
                                  width: 100,
                                  height: 62,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F172A),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFF59E0B), width: 1),
                                        ),
                                        child: Text(
                                          widget.order.customerName.length > 11
                                              ? '${widget.order.customerName.substring(0, 9)}...'
                                              : widget.order.customerName,
                                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                        ),
                                      ),
                                      const Icon(Icons.location_on, color: Color(0xFFF59E0B), size: 28),
                                    ],
                                  ),
                                ),
                                // Live Rider Pin
                                Marker(
                                  point: _riderPosition,
                                  width: 50,
                                  height: 50,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                      border: Border.all(color: const Color(0xFF10B981), width: 2),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.two_wheeler, color: Colors.white, size: 24),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _MapRoutePainter(step: step),
                          ),
                        ),

                      // Top Map Floating Card: Distance & ETA
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.navigation, color: Color(0xFF10B981), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      step == DeliveryTripStep.enRouteStore || step == DeliveryTripStep.atStore
                                          ? 'Head to: ${widget.order.storeName}'
                                          : 'Deliver to: ${widget.order.customerName}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _distanceKm > 0
                                          ? '${_distanceKm.toStringAsFixed(1)} km • $_etaMins mins estimated 🛵'
                                          : (step == DeliveryTripStep.enRouteStore || step == DeliveryTripStep.atStore
                                              ? 'Heading to Store'
                                              : 'Heading to Doorstep'),
                                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: _isMapInteractive ? 'Switch to schematic' : 'Switch to live map',
                                icon: Icon(_isMapInteractive ? Icons.layers : Icons.map_outlined, color: Colors.white70, size: 20),
                                onPressed: () => setState(() => _isMapInteractive = !_isMapInteractive),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Floating Map Action Pills
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Column(
                          children: [
                            // Feature C: Emergency SOS Button
                            FloatingActionButton.small(
                              heroTag: 'nav_sos_btn',
                              backgroundColor: const Color(0xFFEF4444),
                              tooltip: 'Emergency SOS',
                              child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 20),
                              onPressed: () => DeliverySosSheet.show(context),
                            ),
                            const SizedBox(height: 8),
                            // Recenter map on live GPS position
                            FloatingActionButton.small(
                              heroTag: 'recenter_btn',
                              backgroundColor: const Color(0xFF0F172A),
                              child: const Icon(Icons.my_location, color: Color(0xFF10B981)),
                              onPressed: () {
                                _mapController.move(_riderPosition, _currentZoom);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Centered on current GPS location 🎯'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            // External Google Maps Turn-by-Turn Navigation
                            FloatingActionButton.small(
                              heroTag: 'map_btn',
                              backgroundColor: const Color(0xFF38BDF8),
                              child: const Icon(Icons.map, color: Colors.white),
                              onPressed: () async {
                                final isToStore = step == DeliveryTripStep.enRouteStore || step == DeliveryTripStep.atStore;
                                final destination = isToStore ? widget.order.storeAddress : widget.order.deliveryAddress;
                                final mapsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(destination)}');
                                try {
                                  if (await canLaunchUrl(mapsUri)) {
                                    await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
                                  } else {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Navigating to $destination... 🗺️')),
                                      );
                                    }
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Navigating to $destination... 🗺️')),
                                    );
                                  }
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            // Phone customer
                            FloatingActionButton.small(
                              heroTag: 'call_btn',
                              backgroundColor: const Color(0xFF10B981),
                              child: const Icon(Icons.phone, color: Colors.white),
                              onPressed: () async {
                                final cleanPhone = widget.order.customerPhone.replaceAll(RegExp(r'[^0-9+]'), '');
                                final phoneUri = Uri.parse('tel:$cleanPhone');
                                try {
                                  if (await canLaunchUrl(phoneUri)) {
                                    await launchUrl(phoneUri);
                                  } else {
                                      final maskedPhone = cleanPhone.length > 4
                                          ? '•••• ${cleanPhone.substring(cleanPhone.length - 4)}'
                                          : cleanPhone;
                                      if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Calling ${widget.order.customerName} ($maskedPhone)... 📞')),
                                      );
                                      }
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Calling ${widget.order.customerName}... 📞')),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Trip Action & Item Checklist Drawer
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Step Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _getStepLabel(step),
                                style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Total: ₹${widget.order.grandTotal.toStringAsFixed(0)}',
                              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Store & Customer Addresses Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(Icons.store, color: Color(0xFF38BDF8), size: 16),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${widget.order.storeName} (${widget.order.storeAddress})',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, height: 1.25),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white12, height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(Icons.home, color: Color(0xFFF59E0B), size: 16),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${widget.order.customerName} • ${widget.order.deliveryAddress}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.25),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Item Checklist Header
                      const Text('Store Item Checklist (Verify at counter):',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      // Scrollable Items Checklist
                      Expanded(
                        child: ListView.builder(
                          itemCount: widget.order.items.length,
                          itemBuilder: (ctx, i) {
                            final item = widget.order.items[i];
                            final isChecked = state.verifiedItemChecklist.contains(item.productId);

                            return GestureDetector(
                              onTap: () => context.read<DeliveryBloc>().add(ToggleItemChecklistEvent(item.productId)),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isChecked ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isChecked ? const Color(0xFF10B981) : Colors.white12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                                      color: isChecked ? const Color(0xFF10B981) : Colors.white54,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '${item.quantity}x ${item.nameSnapshot} (${item.unit})',
                                        style: TextStyle(
                                          color: isChecked ? Colors.white : Colors.white70,
                                          fontSize: 12,
                                          fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Step Progression Primary Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            if (step == DeliveryTripStep.enRouteStore) {
                              context.read<DeliveryBloc>().add(ArrivedAtStoreEvent(widget.order.id));
                            } else if (step == DeliveryTripStep.atStore) {
                              context.read<DeliveryBloc>().add(MarkPickedUpEvent(widget.order.id));
                            } else if (step == DeliveryTripStep.orderPickedUp) {
                              context.read<DeliveryBloc>().add(MarkOutForDeliveryEvent(widget.order.id));
                            } else if (step == DeliveryTripStep.enRouteCustomer) {
                              context.read<DeliveryBloc>().add(ArrivedAtCustomerEvent(widget.order.id));
                            } else if (step == DeliveryTripStep.atCustomer) {
                              _showOtpModal(context);
                            } else {
                              _exitToRadar();
                            }
                          },
                          child: Text(
                            _getButtonText(step),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );

        if (widget.isEmbedded) {
          return content;
        }

        void handleBack() {
          if (widget.onBackToRadar != null) {
            widget.onBackToRadar!();
          } else if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DeliveryMainScreen()),
            );
          }
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) handleBack();
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            appBar: AppBar(
              backgroundColor: const Color(0xFF0F172A),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: handleBack,
              ),
              title: Text(
                'Trip: #${widget.order.orderNumber}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            body: content,
          ),
        );
      },
    );
  }

  String _getShortStepLabel(DeliveryTripStep step) {
    switch (step) {
      case DeliveryTripStep.enRouteStore:
        return '🛵 Step 1: En Route';
      case DeliveryTripStep.atStore:
        return '🏪 Step 2: At Store';
      case DeliveryTripStep.orderPickedUp:
        return '📦 Step 3: Picked Up';
      case DeliveryTripStep.enRouteCustomer:
        return '🚀 Step 4: Delivering';
      case DeliveryTripStep.atCustomer:
        return '🏠 Step 5: Doorstep';
      case DeliveryTripStep.completed:
        return '✅ Completed';
    }
  }

  String _getStepLabel(DeliveryTripStep step) {
    switch (step) {
      case DeliveryTripStep.enRouteStore:
        return '🛵 STEP 1: EN ROUTE TO STORE';
      case DeliveryTripStep.atStore:
        return '🏪 STEP 2: AT MERCHANT COUNTER';
      case DeliveryTripStep.orderPickedUp:
        return '📦 STEP 3: ORDER PICKED UP (READY TO DEPART)';
      case DeliveryTripStep.enRouteCustomer:
        return '🚀 STEP 4: OUT FOR DELIVERY (EN ROUTE)';
      case DeliveryTripStep.atCustomer:
        return '🏠 STEP 5: AT CUSTOMER DOORSTEP';
      case DeliveryTripStep.completed:
        return '✅ COMPLETED';
    }
  }

  String _getButtonText(DeliveryTripStep step) {
    switch (step) {
      case DeliveryTripStep.enRouteStore:
        return 'I Have Arrived at Store 🏪';
      case DeliveryTripStep.atStore:
        return 'Verified Items • Mark Picked Up 📦';
      case DeliveryTripStep.orderPickedUp:
        return 'Depart Store • Mark Out For Delivery 🚀';
      case DeliveryTripStep.enRouteCustomer:
        return 'I Have Arrived at Customer Location 🏠';
      case DeliveryTripStep.atCustomer:
        return 'Verify Customer 6-Digit Delivery PIN 🔐';
      case DeliveryTripStep.completed:
        return 'Trip Completed! Back to Radar 🚀';
    }
  }

  void _exitToRadar() {
    if (widget.onBackToRadar != null) {
      widget.onBackToRadar!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DeliveryMainScreen()),
      );
    }
  }

  void _showTripCompletedCelebration(BuildContext context, DeliveryState state) {
    final double earnings = widget.order.deliveryFee > 0 ? widget.order.deliveryFee : 35.0;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'Trip Delivered Successfully! 🎉',
                style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Order #${widget.order.orderNumber} is marked as delivered.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Earnings Credited to Wallet', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text('₹${earnings.toStringAsFixed(0)} 💰', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    _exitToRadar();
                  },
                  child: const Text('Back to Job Radar 🚀', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapRoutePainter extends CustomPainter {
  final DeliveryTripStep step;
  _MapRoutePainter({required this.step});

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;

    final polylinePaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final riderPaint = Paint()..color = const Color(0xFF10B981);
    final storePaint = Paint()..color = const Color(0xFF38BDF8);
    final customerPaint = Paint()..color = const Color(0xFFF59E0B);

    final storePoint = Offset(size.width * 0.25, size.height * 0.7);
    final customerPoint = Offset(size.width * 0.75, size.height * 0.3);

    // Draw Roads
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), roadPaint);
    canvas.drawLine(Offset(size.width * 0.5, 0), Offset(size.width * 0.5, size.height), roadPaint);

    // Draw Route Polyline
    final path = Path()
      ..moveTo(storePoint.dx, storePoint.dy)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.4, customerPoint.dx, customerPoint.dy);
    canvas.drawPath(path, polylinePaint);

    // Draw Store & Customer Pins
    canvas.drawCircle(storePoint, 10, storePaint);
    canvas.drawCircle(customerPoint, 10, customerPaint);

    // Draw Rider Current Position
    Offset riderPos;
    if (step == DeliveryTripStep.enRouteStore) {
      riderPos = Offset(storePoint.dx - 30, storePoint.dy + 30);
    } else if (step == DeliveryTripStep.atStore) {
      riderPos = storePoint;
    } else if (step == DeliveryTripStep.atCustomer) {
      riderPos = customerPoint;
    } else {
      riderPos = Offset(size.width * 0.5, size.height * 0.45);
    }

    canvas.drawCircle(riderPos, 14, riderPaint);
    canvas.drawCircle(riderPos, 18, Paint()..color = const Color(0xFF10B981).withValues(alpha: 0.3));
  }

  @override
  bool shouldRepaint(covariant _MapRoutePainter oldDelegate) => oldDelegate.step != step;
}
