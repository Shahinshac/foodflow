import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/dashboard_sidebar.dart';
import '../../../core/widgets/error_and_empty_views.dart';
import '../../../core/widgets/motion_system.dart';
import '../../../core/utils/dialer_helper.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
  final String? restaurantPhone;
  final String? upiId;
  final String deliveryAddress;
  final int totalPaise;
  final String? customerName;
  final String? customerPhone;
  final String paymentMethod;
  final String paymentStatus;

  DeliveryAssignmentModel({
    required this.id,
    required this.orderId,
    required this.status,
    required this.restaurantName,
    required this.restaurantAddress,
    this.restaurantPhone,
    this.upiId,
    required this.deliveryAddress,
    required this.totalPaise,
    this.customerName,
    this.customerPhone,
    required this.paymentMethod,
    required this.paymentStatus,
  });

  factory DeliveryAssignmentModel.fromJson(Map<String, dynamic> json) {
    final order = json['order'] as Map<String, dynamic>;
    final restaurant = order['restaurant'] as Map<String, dynamic>?;
    final customer = order['user'] as Map<String, dynamic>?;

    return DeliveryAssignmentModel(
      id: json['id'],
      orderId: order['id'],
      status: json['status'],
      restaurantName: restaurant?['name'] ?? 'Restaurant',
      restaurantAddress: restaurant?['address_text'] ?? '',
      restaurantPhone: restaurant?['owner_phone'],
      upiId: restaurant?['upi_id'],
      deliveryAddress: order['delivery_address'] ?? '',
      totalPaise: order['total_paise'] ?? 0,
      customerName: customer?['full_name'],
      customerPhone: customer?['phone'],
      paymentMethod: order['payment_method'] ?? 'COD',
      paymentStatus: order['payment_status'] ?? 'PENDING',
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

class _DeliveryDashboardScreenState extends ConsumerState<DeliveryDashboardScreen> with WidgetsBindingObserver {
  Timer? _locationSyncTimer;
  Timer? _pollingTimer;
  int _selectedNavIndex = 0;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startGpsSync();
    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startGpsSync();
      _startPolling();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _stopGpsSync();
      _stopPolling();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      ref.invalidate(deliveryAssignmentsProvider);
      ref.invalidate(deliveryProfileProvider);
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _startGpsSync() {
    _locationSyncTimer?.cancel();
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

  void _stopGpsSync() {
    _locationSyncTimer?.cancel();
    _locationSyncTimer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopGpsSync();
    _stopPolling();
    super.dispose();
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

  void _acceptAssignment(int assignmentId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.post('/delivery/assignments/$assignmentId/accept');
      ref.invalidate(deliveryAssignmentsProvider);
      ref.invalidate(deliveryProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order accepted! Proceed to pickup at restaurant.'),
            backgroundColor: AppColors.veg,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ref.invalidate(deliveryAssignmentsProvider);
      if (mounted) {
        final errorMsg = e.toString().contains('409') || e.toString().contains('Already accepted')
            ? 'Already accepted by another rider.'
            : 'Failed to accept order: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showUpiQrDialog(DeliveryAssignmentModel item) {
    final upiId = item.upiId;
    final totalAmount = (item.totalPaise / 100).toStringAsFixed(2);
    final upiPayload = (upiId != null && upiId.isNotEmpty)
        ? 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(item.restaurantName)}&am=$totalAmount&cu=INR&tn=${Uri.encodeComponent("Order #${item.orderId}")}'
        : null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'UPI at Delivery - Order #${item.orderId}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Payable Amount: ₹$totalAmount',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.primary),
              ),
              const SizedBox(height: 4),
              Text(
                'Restaurant: ${item.restaurantName}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (upiPayload != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: QrImageView(
                    data: upiPayload,
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    'UPI ID: $upiId',
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Customer can scan with Google Pay, PhonePe, Paytm, or any UPI app to pay directly to the restaurant.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber, size: 36),
                      SizedBox(height: 8),
                      Text(
                        'The restaurant has not configured a UPI ID yet.\n\nPlease collect ₹ amount via Cash on Delivery or request restaurant to update their UPI ID in Partner Portal.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.security_rounded, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Verify payment confirmation on customer\'s screen or bank SMS before marking delivered.',
                        style: TextStyle(fontSize: 11, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
    final authUser = ref.watch(authProvider).user;
    final isApproved = authUser?.isApproved ?? true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (_selectedNavIndex != 0) {
          setState(() => _selectedNavIndex = 0);
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit FoodFlow'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        final contentWidget = RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(deliveryProfileProvider);
            ref.invalidate(deliveryAssignmentsProvider);
          },
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isApproved) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.pending_actions_rounded, color: Color(0xFFB45309), size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Account Pending Verification',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Your rider application has been submitted and is currently under review by our Admin team. You will be able to go online and receive orders once approved.',
                                    style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Rider Status & Earnings Card
                    profileAsync.when(
                      data: (profile) => Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppColors.softShadow,
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
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          !isApproved
                                              ? 'PENDING APPROVAL'
                                              : (profile.isOnline ? 'YOU ARE ONLINE' : 'YOU ARE OFFLINE'),
                                          style: TextStyle(
                                            color: !isApproved
                                                ? const Color(0xFFB45309)
                                                : (profile.isOnline ? Colors.green.shade600 : (isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        Text(
                                          '${profile.vehicleType} • ${profile.vehicleNumber}',
                                          style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: profile.isOnline,
                                  activeThumbColor: AppColors.veg,
                                  onChanged: isApproved ? (_) => _toggleOnline() : null,
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
                                  style: const TextStyle(color: AppColors.veg, fontWeight: FontWeight.w900, fontSize: 18),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
                      loading: () => const FoodShimmerLoading(width: double.infinity, height: 110),
                      error: (err, stack) => CustomErrorView(
                        message: 'Failed to load rider profile: ${ApiClient.formatError(err)}',
                        onRetry: () => ref.invalidate(deliveryProfileProvider),
                      ),
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
                              if (item.customerName != null && item.customerName!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.person_outline, size: 16, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                    const SizedBox(width: 8),
                                    Text('Customer: ${item.customerName}', style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.payments_outlined, size: 16, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
                                  const SizedBox(width: 8),
                                  Text('Order Value: ${CurrencyFormatter.formatPaise(item.totalPaise)} • ', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: item.paymentMethod == 'UPI_AT_DELIVERY'
                                          ? Colors.purple.withValues(alpha: 0.15)
                                          : (item.paymentMethod == 'COD' ? Colors.orange.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.paymentMethod == 'UPI_AT_DELIVERY' ? 'UPI at Delivery' : item.paymentMethod,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: item.paymentMethod == 'UPI_AT_DELIVERY'
                                            ? Colors.purple
                                            : (item.paymentMethod == 'COD' ? Colors.orange.shade800 : Colors.green.shade800),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  if (item.restaurantPhone != null && item.restaurantPhone!.isNotEmpty)
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.call_rounded, size: 16),
                                        label: const Text('Call Store', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => DialerHelper.openDialer(context, item.restaurantPhone, contactLabel: 'Restaurant'),
                                      ),
                                    ),
                                  if (item.restaurantPhone != null && item.restaurantPhone!.isNotEmpty && item.customerPhone != null && item.customerPhone!.isNotEmpty)
                                    const SizedBox(width: 8),
                                  if (item.customerPhone != null && item.customerPhone!.isNotEmpty)
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                                        label: const Text('Call Customer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => DialerHelper.openDialer(context, item.customerPhone, contactLabel: 'Customer'),
                                      ),
                                    ),
                                ],
                              ),
                              if (item.paymentMethod == 'UPI_AT_DELIVERY' && item.status != 'DELIVERED') ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.qr_code_2_rounded, color: Colors.purple),
                                    label: const Text('Show Restaurant UPI QR to Customer', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.purple),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => _showUpiQrDialog(item),
                                  ),
                                ),
                              ],
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
                                      backgroundColor: item.status == 'ASSIGNED'
                                          ? AppColors.primary
                                          : (item.status == 'OUT_FOR_DELIVERY' || item.status == 'ARRIVED_AT_CUSTOMER' ? Colors.green : AppColors.primary),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () {
                                      if (item.status == 'ASSIGNED') {
                                        _acceptAssignment(item.id);
                                      } else if (item.status == 'ACCEPTED') {
                                        _updateStatus(item.id, item.orderId, 'ARRIVED_AT_RESTAURANT');
                                      } else if (item.status == 'ARRIVED_AT_RESTAURANT') {
                                        _updateStatus(item.id, item.orderId, 'PICKED_UP');
                                      } else if (item.status == 'PICKED_UP') {
                                        _updateStatus(item.id, item.orderId, 'OUT_FOR_DELIVERY');
                                      } else if (item.status == 'OUT_FOR_DELIVERY') {
                                        _updateStatus(item.id, item.orderId, 'ARRIVED_AT_CUSTOMER');
                                      } else if (item.status == 'ARRIVED_AT_CUSTOMER') {
                                        _updateStatus(item.id, item.orderId, 'DELIVERED');
                                      }
                                    },
                                    child: Text(
                                      item.status == 'ASSIGNED'
                                          ? 'Accept Delivery Order'
                                          : item.status == 'ACCEPTED'
                                              ? 'Arrived at Restaurant'
                                              : item.status == 'ARRIVED_AT_RESTAURANT'
                                                  ? 'Food Picked Up'
                                                  : item.status == 'PICKED_UP'
                                                      ? 'Start Delivery (Out for Delivery)'
                                                      : item.status == 'OUT_FOR_DELIVERY'
                                                          ? 'Arrived at Customer Doorstep'
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
                loading: () => ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 2,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, _) => const FoodShimmerLoading(width: double.infinity, height: 160),
                ),
                error: (err, stack) => CustomErrorView(
                  message: 'Failed to load delivery assignments: ${ApiClient.formatError(err)}',
                  onRetry: () => ref.invalidate(deliveryAssignmentsProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

        if (isDesktop) {
          return Scaffold(
            backgroundColor: const Color(0xFFFBF9F5),
            body: Row(
              children: [
                DashboardSidebar(
                  portalTitle: 'Delivery Portal',
                  portalSubtitle: 'Partner Fleet',
                  selectedIndex: _selectedNavIndex,
                  onItemSelected: (idx) => setState(() => _selectedNavIndex = idx),
                  items: const [
                    SidebarItem(index: 0, label: 'My Deliveries', icon: Icons.two_wheeler_rounded),
                    SidebarItem(index: 1, label: 'Shift Earnings', icon: Icons.account_balance_wallet_rounded),
                    SidebarItem(index: 2, label: 'Live Route / GPS', icon: Icons.navigation_rounded),
                    SidebarItem(index: 3, label: 'Rider Profile', icon: Icons.person_rounded),
                  ],
                ),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        color: Colors.white,
                        child: Row(
                          children: [
                            const Text(
                              'Delivery Partner Dashboard',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded),
                              tooltip: 'Refresh',
                              onPressed: () {
                                ref.invalidate(deliveryProfileProvider);
                                ref.invalidate(deliveryAssignmentsProvider);
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: contentWidget),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('Delivery Partner Portal', style: TextStyle(fontWeight: FontWeight.w900)),
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  ref.invalidate(deliveryProfileProvider);
                  ref.invalidate(deliveryAssignmentsProvider);
                },
              ),
              IconButton(
                icon: Icon(Icons.logout_rounded, color: isDark ? Colors.white70 : Colors.black87),
                onPressed: () => ref.read(authProvider.notifier).logout(),
              ),
            ],
          ),
          body: contentWidget,
        );
      },
    ),
    );
  }
}
