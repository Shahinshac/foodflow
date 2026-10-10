import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/routing_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dialer_helper.dart';
import '../../../core/widgets/error_and_empty_views.dart';
import '../../auth/presentation/auth_providers.dart';

class LiveTrackingData {
  final int orderId;
  final String status;
  final int calculatedEtaMinutes;
  final bool isDelayed;
  final String restaurantName;
  final LatLng? restaurantLocation;
  final String restaurantAddress;
  final LatLng? deliveryLocation;
  final String deliveryAddress;
  final bool riderAssigned;
  final String? riderName;
  final String? riderPhone;
  final LatLng? riderLocation;
  final double riderHeading;
  final DateTime? lastUpdatedAt;

  LiveTrackingData({
    required this.orderId,
    required this.status,
    required this.calculatedEtaMinutes,
    required this.isDelayed,
    required this.restaurantName,
    this.restaurantLocation,
    required this.restaurantAddress,
    this.deliveryLocation,
    required this.deliveryAddress,
    required this.riderAssigned,
    this.riderName,
    this.riderPhone,
    this.riderLocation,
    this.riderHeading = 0.0,
    this.lastUpdatedAt,
  });

  factory LiveTrackingData.fromJson(Map<String, dynamic> json) {
    return LiveTrackingData(
      orderId: json['order_id'],
      status: json['status'],
      calculatedEtaMinutes: json['calculated_eta_minutes'] ?? 30,
      isDelayed: json['is_delayed'] ?? false,
      restaurantName: json['restaurant_name'] ?? 'Restaurant',
      restaurantAddress: json['restaurant_address'] ?? 'Restaurant Address',
      restaurantLocation: json['restaurant_lat'] != null && json['restaurant_lng'] != null
          ? LatLng(
              (json['restaurant_lat'] as num).toDouble(),
              (json['restaurant_lng'] as num).toDouble(),
            )
          : null,
      deliveryLocation: json['delivery_lat'] != null && json['delivery_lng'] != null
          ? LatLng(
              (json['delivery_lat'] as num).toDouble(),
              (json['delivery_lng'] as num).toDouble(),
            )
          : null,
      deliveryAddress: json['delivery_address'] ?? '',
      riderAssigned: json['rider_assigned'] ?? false,
      riderName: json['rider_name'],
      riderPhone: json['rider_phone'],
      riderLocation: json['rider_lat'] != null && json['rider_lng'] != null
          ? LatLng(
              (json['rider_lat'] as num).toDouble(),
              (json['rider_lng'] as num).toDouble(),
            )
          : null,
      riderHeading: (json['rider_heading'] as num?)?.toDouble() ?? 0.0,
      lastUpdatedAt: json['last_updated_at'] != null
          ? DateTime.tryParse(json['last_updated_at'])
          : null,
    );
  }
}

class LiveMapTrackingScreen extends ConsumerStatefulWidget {
  final int orderId;

  const LiveMapTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<LiveMapTrackingScreen> createState() => _LiveMapTrackingScreenState();
}

class _LiveMapTrackingScreenState extends ConsumerState<LiveMapTrackingScreen> {
  final MapController _mapController = MapController();
  WebSocketChannel? _wsChannel;
  Timer? _pollingTimer;
  LiveTrackingData? _trackingData;
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasPromptedReview = false;
  bool _hasInitialFitted = false;
  RouteResult? _activeRoute;
  bool _isLoadingRoute = false;
  LatLng? _lastRoutedOrigin;
  LatLng? _lastRoutedDestination;

  @override
  void initState() {
    super.initState();
    _fetchSnapshot();
    _initWebSocket();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchSnapshot());
  }

  @override
  void dispose() {
    _wsChannel?.sink.close();
    _pollingTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchSnapshot() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get('/tracking/order/${widget.orderId}');
      final data = LiveTrackingData.fromJson(response.data);
      if (mounted) {
        setState(() {
          _trackingData = data;
          _isLoading = false;
        });

        _updateRoute(data);

        if (!_hasInitialFitted) {
          _fitMapBounds();
        }

        // If delivered, show review modal once
        if (data.status == 'DELIVERED' && !_hasPromptedReview) {
          _hasPromptedReview = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showReviewModal();
          });
        }
      }
    } catch (e) {
      if (mounted && _trackingData == null) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _initWebSocket() {
    try {
      final wsUrl = AppConstants.baseUrl.replaceFirst('http', 'ws');
      _wsChannel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/tracking/ws/${widget.orderId}'),
      );

      _wsChannel?.stream.listen((message) {
        final decoded = jsonDecode(message);
        if (decoded['event'] == 'LOCATION_UPDATED' && _trackingData != null && mounted) {
          final newLat = (decoded['rider_lat'] as num).toDouble();
          final newLng = (decoded['rider_lng'] as num).toDouble();
          final heading = (decoded['rider_heading'] as num?)?.toDouble() ?? 0.0;
          final updatedRiderLoc = LatLng(newLat, newLng);

          setState(() {
            _trackingData = LiveTrackingData(
              orderId: _trackingData!.orderId,
              status: _trackingData!.status,
              calculatedEtaMinutes: _trackingData!.calculatedEtaMinutes,
              isDelayed: _trackingData!.isDelayed,
              restaurantName: _trackingData!.restaurantName,
              restaurantAddress: _trackingData!.restaurantAddress,
              restaurantLocation: _trackingData!.restaurantLocation,
              deliveryLocation: _trackingData!.deliveryLocation,
              deliveryAddress: _trackingData!.deliveryAddress,
              riderAssigned: true,
              riderName: _trackingData!.riderName,
              riderPhone: _trackingData!.riderPhone,
              riderLocation: updatedRiderLoc,
              riderHeading: heading,
              lastUpdatedAt: DateTime.now(),
            );
          });

          _updateRoute(_trackingData!);
        }
      });
    } catch (_) {
      // Automatic fallback to REST polling
    }
  }

  void _fitMapBounds() {
    if (_trackingData == null) return;
    final points = <LatLng>[];
    if (_trackingData!.restaurantLocation != null) points.add(_trackingData!.restaurantLocation!);
    if (_trackingData!.deliveryLocation != null) points.add(_trackingData!.deliveryLocation!);
    if (_trackingData!.riderLocation != null) points.add(_trackingData!.riderLocation!);

    if (points.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (points.length == 1) {
        _mapController.move(points.first, 15.0);
      } else {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 70),
          ),
        );
      }
      _hasInitialFitted = true;
    });
  }

  Future<void> _updateRoute(LiveTrackingData data) async {
    final origin = data.riderLocation ?? data.restaurantLocation;
    final destination = data.deliveryLocation;

    if (origin == null || destination == null) return;

    final needRecalc = _activeRoute == null ||
        _lastRoutedOrigin == null ||
        _lastRoutedDestination == null ||
        RoutingService.hasMovedSignificantly(_lastRoutedOrigin, origin, thresholdMeters: 30.0) ||
        RoutingService.hasMovedSignificantly(_lastRoutedDestination, destination, thresholdMeters: 30.0);

    if (!needRecalc || _isLoadingRoute) return;

    _isLoadingRoute = true;
    try {
      final route = await RoutingService.getRoadRoute(origin, destination);
      if (mounted) {
        setState(() {
          _activeRoute = route;
          _lastRoutedOrigin = origin;
          _lastRoutedDestination = destination;
        });
      }
    } catch (_) {
      // Handled inside RoutingService
    } finally {
      _isLoadingRoute = false;
    }
  }

  void _centerOnRider() {
    if (_trackingData?.riderLocation != null) {
      _mapController.move(_trackingData!.riderLocation!, 16.0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Awaiting rider GPS location...'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildGpsStatusChip(LiveTrackingData data) {
    String text;
    Color color;
    IconData icon;

    if (!data.riderAssigned) {
      text = 'Awaiting rider assignment';
      color = Colors.grey.shade600;
      icon = Icons.person_search_rounded;
    } else if (data.riderLocation == null) {
      text = 'Awaiting rider GPS';
      color = Colors.orange.shade800;
      icon = Icons.gps_not_fixed_rounded;
    } else {
      final updated = data.lastUpdatedAt ?? DateTime.now();
      final diff = DateTime.now().difference(updated);
      if (diff.inSeconds < 45) {
        text = 'Live GPS';
        color = AppColors.veg;
        icon = Icons.gps_fixed_rounded;
      } else if (diff.inMinutes < 60) {
        text = 'GPS updated ${diff.inMinutes}m ago';
        color = Colors.orange.shade800;
        icon = Icons.access_time_rounded;
      } else {
        text = 'Stale GPS (${diff.inHours}h ago)';
        color = AppColors.error;
        icon = Icons.gps_off_rounded;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteStatusChip() {
    if (_activeRoute == null) return const SizedBox.shrink();

    final isRoad = _activeRoute!.isRoadRoute;
    final color = isRoad ? AppColors.veg : Colors.deepOrange;
    final label = isRoad
        ? 'Road: ${_activeRoute!.distanceKm.toStringAsFixed(1)} km (~${_activeRoute!.durationMinutes} min)'
        : 'Straight-line (Road route unavailable)';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isRoad ? Icons.alt_route_rounded : Icons.straighten_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showReviewModal() {
    double selectedRating = 5.0;
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Rate Your Food Experience',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'How was the food from ${_trackingData?.restaurantName}?',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starVal = index + 1;
                  return IconButton(
                    iconSize: 36,
                    icon: Icon(
                      starVal <= selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: Colors.amber,
                    ),
                    onPressed: () {
                      setModalState(() => selectedRating = starVal.toDouble());
                    },
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Share your feedback (Optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    try {
                      final api = ref.read(apiClientProvider);
                      await api.dio.post(
                        '/reviews',
                        data: {
                          'restaurant_id': 1,
                          'order_id': widget.orderId,
                          'rating': selectedRating,
                          'comment': commentController.text.trim(),
                        },
                      );
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Thank you for your review! ⭐')),
                        );
                      }
                    } catch (_) {
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Submit Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Order #${widget.orderId} Live Tracking', style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
              ? CustomErrorView(
                  message: 'Failed to connect to live tracking service. $_errorMessage',
                  onRetry: _fetchSnapshot,
                )
              : _buildLiveTrackingBody(),
    );
  }

  Widget _buildLiveTrackingBody() {
    final data = _trackingData!;
    final centerPoint = data.riderLocation ??
        data.restaurantLocation ??
        data.deliveryLocation ??
        const LatLng(0, 0);

    final polylines = <Polyline>[];
    if (_activeRoute != null && _activeRoute!.points.isNotEmpty) {
      polylines.add(
        Polyline(
          points: _activeRoute!.points,
          strokeWidth: _activeRoute!.isRoadRoute ? 4.5 : 3.0,
          color: _activeRoute!.isRoadRoute ? AppColors.primary : Colors.deepOrange,
        ),
      );
    } else {
      final fallbackPoints = <LatLng>[
        if (data.restaurantLocation != null) data.restaurantLocation!,
        if (data.riderLocation != null) data.riderLocation!,
        if (data.deliveryLocation != null) data.deliveryLocation!,
      ];
      if (fallbackPoints.length >= 2) {
        polylines.add(
          Polyline(
            points: fallbackPoints,
            strokeWidth: 2.5,
            color: Colors.grey.shade400,
          ),
        );
      }
    }

    final markers = <Marker>[
      // Restaurant Marker
      if (data.restaurantLocation != null)
        Marker(
          point: data.restaurantLocation!,
          width: 44,
          height: 44,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.amber.shade700,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6),
              ],
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
          ),
        ),

      // Customer Destination Marker
      if (data.deliveryLocation != null)
        Marker(
          point: data.deliveryLocation!,
          width: 44,
          height: 44,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6),
              ],
            ),
            child: const Icon(Icons.location_on, color: Colors.white, size: 24),
          ),
        ),

      // Delivery Partner Rider Marker with Directional Rotation
      if (data.riderLocation != null)
        Marker(
          point: data.riderLocation!,
          width: 50,
          height: 50,
          child: Transform.rotate(
            angle: data.riderHeading * (3.14159 / 180.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8),
                ],
              ),
              child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 26),
            ),
          ),
        ),
    ];

    return Column(
      children: [
        // 1. LIVE OPENSTREETMAP VIEW
        Expanded(
          flex: 5,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: centerPoint,
                  initialZoom: 14.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.foodflow.foodflow',
                  ),
                  if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
                  if (markers.isNotEmpty) MarkerLayer(markers: markers),
                  const SimpleAttributionWidget(
                    source: Text('© OpenStreetMap contributors'),
                  ),
                ],
              ),

              // Floating ETA & Status Badge
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.status == 'DELIVERED'
                                    ? 'Order Delivered!'
                                    : 'Arriving in ~${data.calculatedEtaMinutes} mins',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                data.status.replaceAll('_', ' '),
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.directions_bike_rounded, color: AppColors.primary, size: 24),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildGpsStatusChip(data),
                          _buildRouteStatusChip(),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: -0.1),
              ),

              // Floating Map Controls: Center on Rider & Fit Whole Route
              Positioned(
                bottom: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'fit_bounds_btn',
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.textPrimaryLight,
                      tooltip: 'Show whole route',
                      onPressed: _fitMapBounds,
                      child: const Icon(Icons.crop_free_rounded, size: 20),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'center_rider_btn',
                      backgroundColor: data.riderLocation != null ? AppColors.primary : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      tooltip: 'Center on Rider',
                      onPressed: _centerOnRider,
                      child: const Icon(Icons.my_location_rounded, size: 20),
                    ),
                  ],
                ),
              ),

              // Unconfigured Location Warning Banner
              if (data.restaurantLocation == null || data.deliveryLocation == null)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 80,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.warning_amber_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Map coordinates not fully configured for this order.',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 2. LIVE DASHBOARD PANEL
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rider Profile Card if assigned
                  if (data.riderAssigned && data.riderName != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data.riderName!,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                ),
                                const Text('Delivery Partner • ⭐ 4.9', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.phone, color: Colors.green),
                            tooltip: 'Call Delivery Partner',
                            onPressed: () => DialerHelper.openDialer(
                              context,
                              data.riderPhone,
                              contactLabel: 'Delivery Partner',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Address Details
                  Row(
                    children: [
                      Icon(Icons.storefront_rounded, color: Colors.amber.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data.restaurantName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(data.restaurantAddress, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.0),
                    child: Divider(height: 1),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: Colors.red, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(data.deliveryAddress, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (data.status == 'DELIVERED') ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.star_rate_rounded),
                        label: const Text('Rate Your Order', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _showReviewModal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
