import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_colors.dart';

class LocationResult {
  final LatLng coordinates;
  final String address;

  LocationResult({required this.coordinates, required this.address});
}

class LocationService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent': 'FoodFlow-Delivery/1.0 (com.foodflow.foodflow)',
      'Accept': 'application/json',
    },
  ));

  /// Requests permission and obtains the device's actual GPS position
  static Future<Position?> determinePosition({
    required Function(String error) onError,
  }) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        onError('Location services are disabled on your device. Please enable GPS.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          onError('Location permission denied. You can enter your address manually.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        onError('Location permissions are permanently denied. Please enable them in settings or enter address manually.');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (e) {
      onError('Unable to detect current GPS location: $e');
      return null;
    }
  }

  /// Reverse-geocodes latitude and longitude into a readable street address using OpenStreetMap Nominatim
  static Future<String> reverseGeocode(double latitude, double longitude) async {
    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'format': 'json',
          'lat': latitude,
          'lon': longitude,
          'zoom': 18,
          'addressdetails': 1,
        },
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final displayName = data['display_name'] as String?;
        final addr = data['address'] as Map?;

        if (addr != null) {
          final parts = <String>[];
          final building = addr['building'] ?? addr['house_number'];
          final road = addr['road'] ?? addr['street'] ?? addr['pedestrian'];
          final sub = addr['suburb'] ?? addr['neighbourhood'] ?? addr['residential'];
          final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'];
          final postcode = addr['postcode'];

          if (building != null) parts.add(building.toString());
          if (road != null) parts.add(road.toString());
          if (sub != null) parts.add(sub.toString());
          if (city != null) parts.add(city.toString());
          if (postcode != null) parts.add(postcode.toString());

          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }

        if (displayName != null && displayName.isNotEmpty) {
          return displayName;
        }
      }
    } catch (_) {
      // Fallback if nominatim is temporarily rate-limited or unreachable
    }
    return 'Location (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})';
  }

  /// Opens an interactive map-pin picker bottom sheet powered by OpenStreetMap & flutter_map
  static Future<LocationResult?> showMapPicker(
    BuildContext context, {
    LatLng? initialCenter,
    String? initialAddress,
    String title = 'Pin Delivery Location',
    String subtitle = 'Move the map to place the pin on your delivery spot',
    String confirmButtonText = 'Confirm Delivery Location',
  }) async {
    return showModalBottomSheet<LocationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MapPickerSheet(
        initialCenter: initialCenter ?? const LatLng(12.9716, 77.5946),
        initialAddress: initialAddress,
        title: title,
        subtitle: subtitle,
        confirmButtonText: confirmButtonText,
      ),
    );
  }
}

class _MapPickerSheet extends StatefulWidget {
  final LatLng initialCenter;
  final String? initialAddress;
  final String title;
  final String subtitle;
  final String confirmButtonText;

  const _MapPickerSheet({
    required this.initialCenter,
    this.initialAddress,
    this.title = 'Pin Delivery Location',
    this.subtitle = 'Move the map to place the pin on your delivery spot',
    this.confirmButtonText = 'Confirm Delivery Location',
  });

  @override
  State<_MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends State<_MapPickerSheet> {
  final MapController _mapController = MapController();
  late LatLng _currentCenter;
  String _currentAddress = 'Locating...';
  bool _isLoadingAddress = false;

  @override
  void initState() {
    super.initState();
    _currentCenter = widget.initialCenter;
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _currentAddress = widget.initialAddress!;
    } else {
      _fetchAddressForCenter();
    }
  }

  Future<void> _fetchAddressForCenter() async {
    setState(() => _isLoadingAddress = true);
    final addr = await LocationService.reverseGeocode(_currentCenter.latitude, _currentCenter.longitude);
    if (mounted) {
      setState(() {
        _currentAddress = addr;
        _isLoadingAddress = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle and header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.subtitle,
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Map View with Center Pin
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentCenter,
                    initialZoom: 16.0,
                    onPositionChanged: (camera, hasGesture) {
                      if (hasGesture) {
                        _currentCenter = camera.center;
                      }
                    },
                    onMapEvent: (event) {
                      if (event is MapEventMoveEnd) {
                        _fetchAddressForCenter();
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.foodflow.foodflow',
                    ),
                    const SimpleAttributionWidget(
                      source: Text('© OpenStreetMap contributors'),
                    ),
                  ],
                ),

                // Center Pin Marker
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 36),
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 44,
                      color: AppColors.primary,
                    ),
                  ),
                ),

                // GPS My Location Floating Button
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 3,
                    onPressed: () async {
                      final pos = await LocationService.determinePosition(
                        onError: (msg) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                        },
                      );
                      if (pos != null) {
                        final newPos = LatLng(pos.latitude, pos.longitude);
                        _currentCenter = newPos;
                        _mapController.move(newPos, 16.0);
                        _fetchAddressForCenter();
                      }
                    },
                    child: const Icon(Icons.my_location_rounded),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Address Card and Confirmation Action
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              border: Border(
                top: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_city_rounded, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _isLoadingAddress
                            ? const Text(
                                'Detecting address details...',
                                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                              )
                            : Text(
                                _currentAddress,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.pop(
                          context,
                          LocationResult(
                            coordinates: _currentCenter,
                            address: _currentAddress,
                          ),
                        );
                      },
                      child: Text(
                        widget.confirmButtonText,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
