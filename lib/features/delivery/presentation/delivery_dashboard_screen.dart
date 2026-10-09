import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/presentation/auth_providers.dart';

class DeliveryProfileModel {
  final int id;
  final String vehicleType;
  final String vehicleNumber;
  final bool isOnline;
  final int totalEarningsPaise;

  DeliveryProfileModel({
    required this.id,
    required this.vehicleType,
    required this.vehicleNumber,
    required this.isOnline,
    required this.totalEarningsPaise,
  });

  factory DeliveryProfileModel.fromJson(Map<String, dynamic> json) {
    return DeliveryProfileModel(
      id: json['id'],
      vehicleType: json['vehicle_type'],
      vehicleNumber: json['vehicle_number'],
      isOnline: json['is_online'],
      totalEarningsPaise: json['total_earnings_paise'],
    );
  }
}

class DeliveryAssignmentModel {
  final int id;
  final int orderId;
  final String status;
  final String restaurantName;
  final String restaurantAddress;
  final String deliveryAddress;
  final int totalPaise;

  DeliveryAssignmentModel({
    required this.id,
    required this.orderId,
    required this.status,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.deliveryAddress,
    required this.totalPaise,
  });

  factory DeliveryAssignmentModel.fromJson(Map<String, dynamic> json) {
    final order = json['order'];
    return DeliveryAssignmentModel(
      id: json['id'],
      orderId: order['id'],
      status: json['status'],
      restaurantName: order['restaurant']['name'],
      restaurantAddress: order['restaurant']['address_text'] ?? '',
      deliveryAddress: order['delivery_address'],
      totalPaise: order['total_paise'],
    );
  }
}

final deliveryProfileProvider = FutureProvider<DeliveryProfileModel>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.dio.get('/delivery/profile');
  return DeliveryProfileModel.fromJson(response.data);
});

final deliveryAssignmentsProvider = FutureProvider<List<DeliveryAssignmentModel>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.dio.get('/delivery/available-orders');
  return (response.data as List).map((e) => DeliveryAssignmentModel.fromJson(e)).toList();
});

class DeliveryDashboardScreen extends ConsumerStatefulWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  ConsumerState<DeliveryDashboardScreen> createState() => _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends ConsumerState<DeliveryDashboardScreen> {
  Timer? _locationSyncTimer;

  @override
  void initState() {
    super.initState();
    _startGpsSync();
  }

  @override
  void dispose() {
    _locationSyncTimer?.cancel();
    super.dispose();
  }

  void _startGpsSync() {
    _locationSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      final assignmentsAsync = ref.read(deliveryAssignmentsProvider);
      final profileAsync = ref.read(deliveryProfileProvider);

      if (profileAsync.hasValue && profileAsync.value!.isOnline && assignmentsAsync.hasValue) {
        final active = assignmentsAsync.value!.where((a) => a.status != 'DELIVERED').toList();
        if (active.isNotEmpty) {
          await _syncDeviceLocation(active.first.orderId);
        }
      }
    });
  }

  Future<void> _syncDeviceLocation(int orderId) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 5)),
      );

      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.post(
        '/tracking/location',
        data: {
          'order_id': orderId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'heading': position.heading,
          'speed': position.speed,
        },
      );
    } catch (_) {
      // Ignore location sync glitches gracefully
    }
  }

  void _updateStatus(int assignmentId, int orderId, String newStatus) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.put('/delivery/assignments/$assignmentId/status', data: {'status': newStatus});
      
      // Also broadcast current location on status change
      _syncDeviceLocation(orderId);

      ref.invalidate(deliveryAssignmentsProvider);
      ref.invalidate(deliveryProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delivery updated: ${newStatus.replaceAll("_", " ")}'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _toggleOnline() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.put('/delivery/toggle-online');
      ref.invalidate(deliveryProfileProvider);
      ref.invalidate(deliveryAssignmentsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(deliveryProfileProvider);
    final assignmentsAsync = ref.watch(deliveryAssignmentsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Delivery Partner Portal', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: isDark ? Colors.white70 : Colors.black87),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(deliveryProfileProvider);
          ref.invalidate(deliveryAssignmentsProvider);
        },
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rider Status & Earnings Card
              profileAsync.when(
                data: (profile) => Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: profile.isOnline 
                                      ? (isDark ? Colors.green.withValues(alpha: 0.2) : Colors.green.shade50)
                                      : (isDark ? Colors.grey.withValues(alpha: 0.2) : Colors.grey.shade100),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.two_wheeler_rounded,
                                  color: profile.isOnline ? Colors.green.shade600 : Colors.grey,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile.isOnline ? 'YOU ARE ONLINE' : 'YOU ARE OFFLINE',
                                      style: TextStyle(
                                        color: profile.isOnline ? Colors.green.shade600 : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      '${profile.vehicleType} • ${profile.vehicleNumber}',
                                      style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: profile.isOnline,
                            activeThumbColor: AppColors.primary,
                            activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                            onChanged: (_) => _toggleOnline(),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        child: Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Shift Earnings:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                          Text(
                            CurrencyFormatter.formatPaise(profile.totalEarningsPaise),
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (err, stack) => Text('Error profile: $err'),
              ),
              
              const SizedBox(height: 28),
              Text(
                'Assigned Deliveries',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: isDark ? Colors.white : Colors.black87),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 14),
              
              assignmentsAsync.when(
                data: (assignments) {
                  if (assignments.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.two_wheeler_outlined, size: 64, color: isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('No active deliveries right now', style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          Text('Stay online to receive incoming orders', style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400, fontSize: 13)),
                        ],
                      ),
                    ).animate().fadeIn();
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: assignments.length,
                    itemBuilder: (context, index) {
                      final item = assignments[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(item.restaurantName, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      item.status.replaceAll('_', ' '),
                                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.storefront_rounded, size: 16, color: Colors.amber.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('Pickup: ${item.restaurantAddress}', style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, fontSize: 13))),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 16, color: Colors.red.shade600),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('Deliver To: ${item.deliveryAddress}', style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, fontSize: 13))),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.payments, size: 16, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
                                  const SizedBox(width: 8),
                                  Text('Order Value: ${CurrencyFormatter.formatPaise(item.totalPaise)}', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14.0),
                                child: Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                              ),
                              
                              // Real Delivery Progression Action Button
                              if (item.status != 'DELIVERED')
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: item.status == 'OUT_FOR_DELIVERY' ? Colors.green : AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () {
                                      if (item.status == 'ASSIGNED') {
                                        _updateStatus(item.id, item.orderId, 'ARRIVED_AT_RESTAURANT');
                                      } else if (item.status == 'ARRIVED_AT_RESTAURANT') {
                                        _updateStatus(item.id, item.orderId, 'PICKED_UP');
                                      } else if (item.status == 'PICKED_UP') {
                                        _updateStatus(item.id, item.orderId, 'OUT_FOR_DELIVERY');
                                      } else if (item.status == 'OUT_FOR_DELIVERY') {
                                        _updateStatus(item.id, item.orderId, 'DELIVERED');
                                      }
                                    },
                                    child: Text(
                                      item.status == 'ASSIGNED'
                                          ? 'Arrived at Restaurant'
                                          : item.status == 'ARRIVED_AT_RESTAURANT'
                                              ? 'Picked Up Food'
                                              : item.status == 'PICKED_UP'
                                                  ? 'Start Delivery (Out for Delivery)'
                                                  : 'Confirm Delivered to Customer',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text('Completed & Delivered', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: (index * 80).ms).slideY(begin: 0.05);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (err, stack) => Text('Error assignments: $err'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
