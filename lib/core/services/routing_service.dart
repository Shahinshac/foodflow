import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class RouteResult {
  final List<LatLng> points;
  final bool isRoadRoute;
  final double? distanceMeters;
  final double? durationSeconds;
  final String? errorMessage;

  const RouteResult({
    required this.points,
    required this.isRoadRoute,
    this.distanceMeters,
    this.durationSeconds,
    this.errorMessage,
  });

  double get distanceKm => (distanceMeters ?? 0.0) / 1000.0;
  int get durationMinutes => ((durationSeconds ?? 0.0) / 60.0).round();
}

class RoutingService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {
      'User-Agent': 'FoodFlow-Delivery/1.0 (com.foodflow.foodflow)',
      'Accept': 'application/json',
    },
  ));

  // In-memory cache to prevent excessive calls to OSRM public server
  static final Map<String, RouteResult> _routeCache = {};

  static String _cacheKey(LatLng origin, LatLng destination) {
    // Round to 4 decimal places (~11 meters) for cache matching
    final oLat = origin.latitude.toStringAsFixed(4);
    final oLng = origin.longitude.toStringAsFixed(4);
    final dLat = destination.latitude.toStringAsFixed(4);
    final dLng = destination.longitude.toStringAsFixed(4);
    return '$oLat,$oLng->$dLat,$dLng';
  }

  /// Calculates actual road route geometry using Open Source Routing Machine (OSRM).
  /// Falls back to straight-line connection if OSRM is unreachable or errors.
  static Future<RouteResult> getRoadRoute(
    LatLng origin,
    LatLng destination, {
    bool forceRefresh = false,
  }) async {
    final key = _cacheKey(origin, destination);
    if (!forceRefresh && _routeCache.containsKey(key)) {
      return _routeCache[key]!;
    }

    try {
      // OSRM expects coordinates in {lon},{lat} order
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}'
          '?overview=full&geometries=geojson';

      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final code = data['code'] as String?;

        if (code == 'Ok' && data['routes'] is List && (data['routes'] as List).isNotEmpty) {
          final firstRoute = data['routes'][0] as Map;
          final geometry = firstRoute['geometry'] as Map?;
          final distance = (firstRoute['distance'] as num?)?.toDouble();
          final duration = (firstRoute['duration'] as num?)?.toDouble();

          if (geometry != null && geometry['coordinates'] is List) {
            final rawCoords = geometry['coordinates'] as List;
            final roadPoints = <LatLng>[];

            for (final item in rawCoords) {
              if (item is List && item.length >= 2) {
                // GeoJSON format is [longitude, latitude]
                final lng = (item[0] as num).toDouble();
                final lat = (item[1] as num).toDouble();
                roadPoints.add(LatLng(lat, lng));
              }
            }

            if (roadPoints.isNotEmpty) {
              final result = RouteResult(
                points: roadPoints,
                isRoadRoute: true,
                distanceMeters: distance,
                durationSeconds: duration,
              );
              _routeCache[key] = result;
              return result;
            }
          }
        }
      }
    } catch (e) {
      // Network error, timeout, or OSRM rate limiting
    }

    // Graceful fallback to direct Euclidean connection
    final fallback = RouteResult(
      points: [origin, destination],
      isRoadRoute: false,
      distanceMeters: const Distance().as(LengthUnit.Meter, origin, destination),
      errorMessage: 'Road route unavailable. Showing straight line connection.',
    );
    return fallback;
  }

  /// Checks if location moved beyond [thresholdMeters] (defaults to 25m) to avoid unnecessary API queries
  static bool hasMovedSignificantly(
    LatLng? previous,
    LatLng current, {
    double thresholdMeters = 25.0,
  }) {
    if (previous == null) return true;
    final distanceMeters = const Distance().as(LengthUnit.Meter, previous, current);
    return distanceMeters >= thresholdMeters;
  }
}
