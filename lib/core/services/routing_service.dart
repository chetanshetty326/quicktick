import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

class RouteData {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const RouteData({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  int get durationMinutes => (durationSeconds / 60).ceil();
  double get distanceKm => (distanceMeters / 1000.0);
}

abstract class IRoutingService {
  Future<RouteData> getRoute({
    required LatLng start,
    required LatLng destination,
  });
}

class RoutingServiceImpl implements IRoutingService {
  final Dio _dio;

  LatLng? _lastStart;
  LatLng? _lastDest;
  RouteData? _cachedRoute;

  RoutingServiceImpl({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 6),
                receiveTimeout: const Duration(seconds: 6),
              ),
            );

  @override
  Future<RouteData> getRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    // Avoid re-querying when coordinate shifts are negligible (< 15 meters)
    if (_cachedRoute != null && _lastStart != null && _lastDest != null) {
      const distanceCalc = Distance();
      final dStart = distanceCalc.as(LengthUnit.Meter, start, _lastStart!);
      final dDest = distanceCalc.as(LengthUnit.Meter, destination, _lastDest!);
      if (dStart < 15 && dDest < 15) {
        return _cachedRoute!;
      }
    }

    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${start.longitude},${start.latitude};'
          '${destination.longitude},${destination.latitude}'
          '?overview=full&geometries=geojson';

      final response = await _dio.get(url);
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final firstRoute = routes.first as Map;
          final geometry = firstRoute['geometry'] as Map?;
          final coords = geometry?['coordinates'] as List?;
          final distance = (firstRoute['distance'] as num?)?.toDouble() ?? 0.0;
          final duration = (firstRoute['duration'] as num?)?.toDouble() ?? 0.0;

          if (coords != null && coords.isNotEmpty) {
            final points = coords.map<LatLng>((c) {
              final list = c as List;
              return LatLng((list[1] as num).toDouble(), (list[0] as num).toDouble());
            }).toList();

            final result = RouteData(
              points: points,
              distanceMeters: distance,
              durationSeconds: duration,
            );
            _lastStart = start;
            _lastDest = destination;
            _cachedRoute = result;
            return result;
          }
        }
      }
    } catch (e) {
      debugPrint('RoutingService OSRM error (falling back to direct connection): $e');
    }

    // Graceful fallback to direct line between endpoints
    const distanceCalc = Distance();
    final dist = distanceCalc.as(LengthUnit.Meter, start, destination);
    final fallback = RouteData(
      points: [start, destination],
      distanceMeters: dist,
      durationSeconds: (dist / 6.0), // ~22 km/h city average
    );
    return fallback;
  }
}
