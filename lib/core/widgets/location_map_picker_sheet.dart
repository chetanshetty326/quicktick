import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';

class LocationPickResult {
  final double lat;
  final double lng;
  final String street;
  final String area;
  final String city;
  final String state;
  final String pincode;
  final String fullAddress;

  const LocationPickResult({
    required this.lat,
    required this.lng,
    required this.street,
    required this.area,
    required this.city,
    required this.state,
    required this.pincode,
    required this.fullAddress,
  });
}

class LocationMapPickerSheet extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const LocationMapPickerSheet({
    super.key,
    this.initialLat = 12.9715987, // Bengaluru center fallback
    this.initialLng = 77.5945627,
  });

  static Future<LocationPickResult?> show(
    BuildContext context, {
    double initialLat = 12.9715987,
    double initialLng = 77.5945627,
  }) {
    return showModalBottomSheet<LocationPickResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationMapPickerSheet(
        initialLat: initialLat,
        initialLng: initialLng,
      ),
    );
  }

  @override
  State<LocationMapPickerSheet> createState() => _LocationMapPickerSheetState();
}

class _LocationMapPickerSheetState extends State<LocationMapPickerSheet> with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late LatLng _currentCenter;
  double _currentZoom = 16.5;

  bool _isLocating = false;
  bool _isGeocoding = false;
  bool _hasLocationError = false;
  String _locationErrorMessage = '';
  Timer? _debounceTimer;

  String _resolvedTitle = 'Detecting current location...';
  String _resolvedAddress = 'Align pin to your building or entrance';
  String _resolvedStreet = '';
  String _resolvedArea = '';
  String _resolvedCity = '';
  String _resolvedState = '';
  String _resolvedPincode = '';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {
      'User-Agent': 'QuickTickApp/1.0 (support@quicktick.in)',
      'Accept': 'application/json',
    },
  ));

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentCenter = LatLng(widget.initialLat, widget.initialLng);
    
    // Reverse geocode initial fallback
    _reverseGeocode(_currentCenter.latitude, _currentCenter.longitude);

    // Mandatorily request and acquire live GPS location on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _requestAndAcquireLiveLocation();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// Mandatory location acquisition on sheet open
  Future<void> _requestAndAcquireLiveLocation() async {
    setState(() {
      _isLocating = true;
      _hasLocationError = false;
      _locationErrorMessage = '';
    });

    try {
      final pos = await LocationService.getCurrentPosition(requestIfNeeded: true);
      if (pos != null && mounted) {
        final newCenter = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _currentCenter = newCenter;
          _isLocating = false;
          _hasLocationError = false;
        });
        _mapController.move(newCenter, 17.5);
        await _reverseGeocode(pos.latitude, pos.longitude);
        return;
      }
    } catch (_) {}

    if (mounted) {
      final hasPerm = await LocationService.hasLocationPermission();
      setState(() {
        _isLocating = false;
        if (!hasPerm) {
          _hasLocationError = true;
          _locationErrorMessage = 'Location permission is required to detect your exact delivery address.';
        } else {
          _hasLocationError = true;
          _locationErrorMessage = 'Please enable device GPS / Location services for pinpoint accuracy.';
        }
      });
    }
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _currentCenter = camera.center;
    _currentZoom = camera.zoom;

    if (hasGesture) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) {
          _reverseGeocode(_currentCenter.latitude, _currentCenter.longitude);
        }
      });
    }
  }

  /// High precision reverse geocoding with granular Indian locality/sub-locality breakdown
  Future<void> _reverseGeocode(double lat, double lng) async {
    if (!mounted) return;
    setState(() => _isGeocoding = true);

    try {
      final url = 'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&zoom=18&addressdetails=1';
      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>? ?? {};

        // 1. Street / Building / Landmark
        final landmark = address['building']?.toString() ??
            address['amenity']?.toString() ??
            address['shop']?.toString() ??
            address['office']?.toString() ??
            address['house_name']?.toString() ??
            '';
        final houseNo = address['house_number']?.toString() ?? '';
        final road = address['road']?.toString() ??
            address['pedestrian']?.toString() ??
            address['street']?.toString() ??
            address['residential']?.toString() ??
            address['footway']?.toString() ??
            '';

        // 2. Locality / Suburb / Area
        final subLocality = address['suburb']?.toString() ??
            address['neighbourhood']?.toString() ??
            address['residential']?.toString() ??
            address['subdistrict']?.toString() ??
            address['city_district']?.toString() ??
            address['quarter']?.toString() ??
            address['block']?.toString() ??
            '';

        // 3. City / Town / Village
        final city = address['city']?.toString() ??
            address['town']?.toString() ??
            address['village']?.toString() ??
            address['municipality']?.toString() ??
            address['district']?.toString() ??
            address['state_district']?.toString() ??
            address['county']?.toString() ??
            '';

        // 4. State & Pincode
        final state = address['state']?.toString() ?? '';
        final pincode = address['postcode']?.toString() ?? '';
        final displayName = data['display_name']?.toString() ?? '';

        // Formulate Title
        String title = '';
        if (landmark.isNotEmpty) {
          title = landmark;
        } else if (road.isNotEmpty) {
          title = houseNo.isNotEmpty ? '$houseNo, $road' : road;
        } else if (subLocality.isNotEmpty) {
          title = subLocality;
        } else if (city.isNotEmpty) {
          title = city;
        } else {
          title = 'Selected Location';
        }

        // Formulate Street Line for Form
        String streetLine = '';
        if (landmark.isNotEmpty && road.isNotEmpty) {
          streetLine = houseNo.isNotEmpty ? '$landmark, No. $houseNo, $road' : '$landmark, $road';
        } else if (road.isNotEmpty) {
          streetLine = houseNo.isNotEmpty ? 'No. $houseNo, $road' : road;
        } else if (landmark.isNotEmpty) {
          streetLine = landmark;
        } else {
          streetLine = title;
        }

        // Formulate Area
        String areaLine = subLocality.isNotEmpty ? subLocality : (road.isNotEmpty && road != title ? road : city);

        // Formulate Subtitle
        final addressParts = <String>[];
        if (subLocality.isNotEmpty && subLocality != title) addressParts.add(subLocality);
        if (city.isNotEmpty && city != title) addressParts.add(city);
        if (state.isNotEmpty) addressParts.add(state);
        if (pincode.isNotEmpty) addressParts.add(pincode);

        final subtitle = addressParts.isNotEmpty ? addressParts.join(', ') : displayName;

        if (mounted) {
          setState(() {
            _resolvedTitle = title;
            _resolvedAddress = subtitle.isNotEmpty ? subtitle : displayName;
            _resolvedStreet = streetLine;
            _resolvedArea = areaLine;
            _resolvedCity = city;
            _resolvedState = state;
            _resolvedPincode = pincode;
            _isGeocoding = false;
          });
        }
        return;
      }
    } catch (_) {
      // Network fallback
    }

    if (mounted) {
      setState(() {
        _resolvedTitle = 'Pinned Location (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
        _resolvedAddress = 'Coordinates: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
        _isGeocoding = false;
      });
    }
  }

  void _confirmLocation() {
    final result = LocationPickResult(
      lat: _currentCenter.latitude,
      lng: _currentCenter.longitude,
      street: _resolvedStreet.isNotEmpty ? _resolvedStreet : _resolvedTitle,
      area: _resolvedArea,
      city: _resolvedCity,
      state: _resolvedState,
      pincode: _resolvedPincode,
      fullAddress: '$_resolvedTitle, $_resolvedAddress',
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.94,
        maxWidth: 680,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Top Drag Handle & Title Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.map_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pinpoint Delivery Location',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Drag or tap map to position pin at your exact door entrance',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF334155)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Mandatory Location Permission Alert Banner (if permission denied or GPS off)
            if (_hasLocationError)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_disabled_rounded, color: Color(0xFFD97706), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _locationErrorMessage,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        await LocationService.openAppSettings();
                        _requestAndAcquireLiveLocation();
                      },
                      child: const Text('ALLOW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Interactive Leaflet OpenStreetMap View
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentCenter,
                      initialZoom: _currentZoom,
                      minZoom: 3,
                      maxZoom: 22,
                      onPositionChanged: _onPositionChanged,
                      onTap: (tapPosition, point) {
                        _mapController.move(point, _currentZoom);
                        _reverseGeocode(point.latitude, point.longitude);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.quicktick.customer',
                        maxNativeZoom: 19,
                        maxZoom: 22,
                      ),
                    ],
                  ),

                  // Center Pin Target Crosshair
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 38),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isGeocoding) ...[
                                  const SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                const Icon(Icons.bolt, color: Colors.amber, size: 13),
                                const SizedBox(width: 2),
                                const Text(
                                  'Delivery Point',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Icon(
                            Icons.location_on_rounded,
                            size: 46,
                            color: Color(0xFFE11D48),
                          ),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top Map Tips Pill
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app_rounded, size: 14, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text(
                              'Tap anywhere or drag map to place delivery pin',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Floating Controls (Zoom & Live GPS Locate Me)
                  Positioned(
                    right: 16,
                    bottom: 20,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Zoom In / Out Controls
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.add_rounded, size: 20, color: Color(0xFF1E293B)),
                                onPressed: () {
                                  _mapController.move(_currentCenter, (_currentZoom + 1).clamp(3.0, 22.0));
                                },
                              ),
                              const Divider(height: 1, indent: 6, endIndent: 6),
                              IconButton(
                                icon: const Icon(Icons.remove_rounded, size: 20, color: Color(0xFF1E293B)),
                                onPressed: () {
                                  _mapController.move(_currentCenter, (_currentZoom - 1).clamp(3.0, 22.0));
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Locate Me GPS Button
                        FloatingActionButton(
                          heroTag: 'map_locate_me_btn',
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          elevation: 6,
                          onPressed: _isLocating ? null : _requestAndAcquireLiveLocation,
                          child: _isLocating
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary))
                              : const Icon(Icons.my_location_rounded, size: 24),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Address Details Card
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _resolvedTitle,
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: Color(0xFF0F172A)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_isGeocoding) ...[
                                  const SizedBox(width: 6),
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _resolvedAddress,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Confirm Location Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 3,
                        shadowColor: AppColors.primary.withValues(alpha: 0.35),
                      ),
                      onPressed: _confirmLocation,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Confirm Location & Auto-Fill',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
