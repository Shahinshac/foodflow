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
import '../../auth/presentation/auth_providers.dart';

class LiveTrackingData {
  final int orderId;
  final String status;
  final int calculatedEtaMinutes;
  final bool isDelayed;
  final String restaurantName;
  final LatLng restaurantLocation;
  final String restaurantAddress;
  final LatLng deliveryLocation;
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
    required this.restaurantLocation,
    required this.restaurantAddress,
    required this.deliveryLocation,
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
      restaurantLocation: LatLng(
        (json['restaurant_lat'] as num?)?.toDouble() ?? 12.9352,
        (json['restaurant_lng'] as num?)?.toDouble() ?? 77.6245,
      ),
      deliveryLocation: LatLng(
        (json['delivery_lat'] as num?)?.toDouble() ?? 12.9716,
        (json['delivery_lng'] as num?)?.toDouble() ?? 77.5946,
      ),
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
              riderLocation: LatLng(newLat, newLng),
              riderHeading: heading,
              lastUpdatedAt: DateTime.now(),
            );
          });
        }
      });
    } catch (_) {
      // Automatic fallback to REST polling
    }
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
                    backgroundColor: const Color(0xFFFF5722),
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5722)))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_errorMessage'),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _fetchSnapshot, child: const Text('Retry')),
                    ],
                  ),
                )
              : _buildLiveTrackingBody(),
    );
  }

  Widget _buildLiveTrackingBody() {
    final data = _trackingData!;
    final centerPoint = data.riderLocation ?? data.restaurantLocation;

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
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [
                          data.restaurantLocation,
                          if (data.riderLocation != null) data.riderLocation!,
                          data.deliveryLocation,
                        ],
                        strokeWidth: 4.0,
                        color: const Color(0xFFFF5722),
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      // Restaurant Marker
                      Marker(
                        point: data.restaurantLocation,
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
                      Marker(
                        point: data.deliveryLocation,
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
                                color: const Color(0xFFFF5722),
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
                    ],
                  ),
                ],
              ),
              // Floating ETA Badge
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
                  child: Row(
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
                              color: Color(0xFFFF5722),
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
                          color: const Color(0xFFFF5722).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.directions_bike_rounded, color: Color(0xFFFF5722), size: 24),
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: -0.1),
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
                            backgroundColor: Color(0xFFFF5722),
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
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Calling ${data.riderPhone ?? "Delivery Partner"}...')),
                              );
                            },
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
