import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/error_and_empty_views.dart';
import '../../../core/widgets/motion_system.dart';
import '../../../core/widgets/dashboard_sidebar.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../notifications/presentation/notification_sheet.dart';
import '../../restaurant/domain/models.dart';

final adminTimeframeProvider = StateProvider<String>((ref) => '30d');

final adminAnalyticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final timeframe = ref.watch(adminTimeframeProvider);
  final response = await apiClient.dio.get('/admin/analytics', queryParameters: {'timeframe': timeframe});
  return Map<String, dynamic>.from(response.data);
});

final adminUsersProvider = FutureProvider<List<UserModel>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.dio.get('/admin/users');
  return (response.data as List).map((e) => UserModel.fromJson(e)).toList();
});

final adminRestaurantsProvider = FutureProvider<List<RestaurantModel>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.dio.get('/admin/restaurants');
  return (response.data as List).map((e) => RestaurantModel.fromJson(e)).toList();
});

final adminPromotionsFilterProvider = StateProvider<String>((ref) => 'all');

final adminPromotionsProvider = FutureProvider<List<CouponModel>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final filter = ref.watch(adminPromotionsFilterProvider);
  final response = await apiClient.dio.get(
    '/admin/promotions',
    queryParameters: {
      'status_filter': filter,
    },
  );
  return (response.data as List).map((e) => CouponModel.fromJson(e)).toList();
});

final adminOrdersProvider = FutureProvider<List<OrderModel>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.dio.get('/admin/orders');
  return (response.data as List).map((e) => OrderModel.fromJson(e)).toList();
});

final adminAuditLogsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.dio.get('/admin/audit-logs');
  return List<Map<String, dynamic>>.from(response.data);
});

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  Timer? _refreshTimer;
  DateTime? _lastBackPressTime;
  final Set<int> _processingRestaurantIds = {};
  final Set<int> _processingUserIds = {};

  final _userSearchController = TextEditingController();
  String _userSearchQuery = '';
  String _userRoleFilter = 'ALL';

  final _restaurantSearchController = TextEditingController();
  String _restaurantSearchQuery = '';
  String _restaurantStatusFilter = 'ALL';

  final _orderSearchController = TextEditingController();
  String _orderSearchQuery = '';
  String _orderStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 6, vsync: this);
    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _stopPolling();
    }
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      ref.invalidate(adminAnalyticsProvider);
      ref.invalidate(adminOrdersProvider);
    });
  }

  void _stopPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _userSearchController.dispose();
    _restaurantSearchController.dispose();
    _orderSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _showAdminProfileDialog() {
    final authState = ref.read(authProvider);
    final user = authState.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final nameController = TextEditingController(text: user?.fullName ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isUpdatingProfile = false;
    bool isChangingPassword = false;
    bool obscureCurrent = true;
    bool obscureNew = true;

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
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.manage_accounts_rounded, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Admin Profile & Security',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              user?.email ?? '',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 20),

                // SECTION 1: Profile Details
                const Text('Profile Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkAction,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isUpdatingProfile
                        ? null
                        : () async {
                            setModalState(() => isUpdatingProfile = true);
                            try {
                              final api = ref.read(apiClientProvider);
                              await api.dio.put(
                                '/admin/profile',
                                data: {
                                  'full_name': nameController.text.trim(),
                                  'phone': phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
                                },
                              );
                              await ref.read(authProvider.notifier).checkAuth();
                              ref.invalidate(adminAuditLogsProvider);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Admin profile updated successfully!'), backgroundColor: AppColors.veg),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to update profile: $e'), backgroundColor: AppColors.error),
                                );
                              }
                            } finally {
                              setModalState(() => isUpdatingProfile = false);
                            }
                          },
                    child: isUpdatingProfile
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Profile Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),

                // SECTION 2: Change Password
                const Text('Security & Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 12),
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setModalState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password (min 6 chars)',
                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setModalState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureNew,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isChangingPassword
                        ? null
                        : () async {
                            if (currentPasswordController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter your current password'), backgroundColor: AppColors.error),
                              );
                              return;
                            }
                            if (newPasswordController.text.length < 6) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('New password must be at least 6 characters'), backgroundColor: AppColors.error),
                              );
                              return;
                            }
                            if (newPasswordController.text != confirmPasswordController.text) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('New passwords do not match'), backgroundColor: AppColors.error),
                              );
                              return;
                            }
                            setModalState(() => isChangingPassword = true);
                            try {
                              final api = ref.read(apiClientProvider);
                              await api.dio.put(
                                '/admin/change-password',
                                data: {
                                  'current_password': currentPasswordController.text,
                                  'new_password': newPasswordController.text,
                                },
                              );
                              ref.invalidate(adminAuditLogsProvider);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Password changed successfully!'), backgroundColor: AppColors.veg),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to change password: ${ApiClient.formatError(e)}'), backgroundColor: AppColors.error),
                                );
                              }
                            } finally {
                              setModalState(() => isChangingPassword = false);
                            }
                          },
                    child: isChangingPassword
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOrderDetailsDialog(OrderModel order) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 10),
            Text('Order #${order.id}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                order.status,
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Restaurant: ${order.restaurant.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text('Delivery Address: ${order.deliveryAddress}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text('Payment: ${order.paymentMethod} (${order.paymentStatus})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              const Divider(),
              const Text('Items Ordered:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${item.quantity}x ${item.foodItem.name}', style: const TextStyle(fontSize: 13)),
                        Text(CurrencyFormatter.formatPaise(item.pricePaise * item.quantity), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(CurrencyFormatter.formatPaise(order.totalPaise), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primary)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkAction,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _toggleUserActive(int userId) async {
    setState(() => _processingUserIds.add(userId));
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.put('/admin/users/$userId/toggle-active');
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminAnalyticsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User status updated successfully'), backgroundColor: AppColors.veg),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update user: ${ApiClient.formatError(e)}'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _processingUserIds.remove(userId));
    }
  }

  void _confirmDeleteUser(UserModel u) {
    final authState = ref.read(authProvider);
    if (authState.user?.id == u.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot delete your own administrative account.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 10),
            Text('Delete User Account', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete the user account for:',
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : const Color(0xFF374151)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.fullName,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF111827)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    u.email,
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : const Color(0xFF4B5563)),
                  ),
                  const SizedBox(height: 6),
                  _buildRoleBadge(u.role, isDark),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Note: If this user has active orders, delivery history, or restaurants, their account will be safely archived and deactivated to protect financial and business integrity.',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF6B7280)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteUser(u.id, u.fullName);
            },
          ),
        ],
      ),
    );
  }

  void _deleteUser(int userId, String userName) async {
    setState(() => _processingUserIds.add(userId));
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.delete('/admin/users/$userId');
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminAnalyticsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User "$userName" deleted / archived successfully.'),
            backgroundColor: AppColors.veg,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete user: ${ApiClient.formatError(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingUserIds.remove(userId));
    }
  }

  void _approveUser(int userId) async {
    setState(() => _processingUserIds.add(userId));
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.put('/admin/users/$userId/approve');
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminAnalyticsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User account approved successfully!'), backgroundColor: AppColors.veg),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve user: ${ApiClient.formatError(e)}'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _processingUserIds.remove(userId));
    }
  }

  void _confirmRejectUser(UserModel u) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.person_off_outlined, color: AppColors.error, size: 26),
            SizedBox(width: 10),
            Text('Reject Registration', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reject the application for ${u.fullName} (${u.role})?',
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : const Color(0xFF374151)),
            ),
            const SizedBox(height: 8),
            Text(
              'The account will remain inactive and prevented from signing in or taking deliveries.',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF6B7280)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _rejectUser(u.id);
            },
            child: const Text('Reject Application', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _rejectUser(int userId) async {
    setState(() => _processingUserIds.add(userId));
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.put('/admin/users/$userId/reject');
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminAnalyticsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User application rejected.'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject user: ${ApiClient.formatError(e)}'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _processingUserIds.remove(userId));
    }
  }

  void _approveRestaurant(int restaurantId) async {
    setState(() => _processingRestaurantIds.add(restaurantId));
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.put('/admin/restaurants/$restaurantId/approve');
      ref.invalidate(adminRestaurantsProvider);
      ref.invalidate(adminAnalyticsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restaurant approved and activated successfully!'), backgroundColor: AppColors.veg),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve restaurant: ${ApiClient.formatError(e)}'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _processingRestaurantIds.remove(restaurantId));
    }
  }

  void _confirmRejectRestaurant(RestaurantModel r) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.store_mall_directory_outlined, color: AppColors.error, size: 26),
            SizedBox(width: 10),
            Text('Reject Application?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to reject the partner application for "${r.name}"? The store will not be visible to customers and cannot accept orders.',
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : const Color(0xFF374151)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.cancel_rounded, size: 18),
            label: const Text('Confirm Reject', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              _rejectRestaurant(r.id);
            },
          ),
        ],
      ),
    );
  }

  void _rejectRestaurant(int restaurantId) async {
    setState(() => _processingRestaurantIds.add(restaurantId));
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.put('/admin/restaurants/$restaurantId/reject');
      ref.invalidate(adminRestaurantsProvider);
      ref.invalidate(adminAnalyticsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restaurant application rejected.'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject: ${ApiClient.formatError(e)}'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _processingRestaurantIds.remove(restaurantId));
    }
  }

  void _toggleRestaurantActive(int restaurantId) async {
    setState(() => _processingRestaurantIds.add(restaurantId));
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.put('/admin/restaurants/$restaurantId/toggle-active');
      ref.invalidate(adminRestaurantsProvider);
      ref.invalidate(adminAnalyticsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restaurant store status updated.'), backgroundColor: AppColors.veg),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: ${ApiClient.formatError(e)}'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _processingRestaurantIds.remove(restaurantId));
    }
  }

  void _showCreateUserDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = 'OWNER';

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
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Add New Account / Partner', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(labelText: 'Account Role'),
                    items: const [
                      DropdownMenuItem(value: 'OWNER', child: Text('Hotel / Restaurant Owner')),
                      DropdownMenuItem(value: 'DRIVER', child: Text('Delivery Partner / Driver')),
                      DropdownMenuItem(value: 'CUSTOMER', child: Text('Customer')),
                      DropdownMenuItem(value: 'ADMIN', child: Text('Administrator')),
                    ],
                    onChanged: (v) => setModalState(() => selectedRole = v ?? 'OWNER'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name', hintText: 'e.g. John Doe'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email Address', hintText: 'e.g. owner@restaurant.com'),
                    validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone Number', hintText: 'e.g. 9876543210'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password', hintText: 'Min 6 characters'),
                    validator: (v) => v == null || v.length < 6 ? 'Password min 6 chars' : null,
                  ),
                  const SizedBox(height: 24),
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
                        if (formKey.currentState!.validate()) {
                          try {
                            final api = ref.read(apiClientProvider);
                            await api.dio.post(
                              '/admin/users',
                              data: {
                                'full_name': nameCtrl.text.trim(),
                                'email': emailCtrl.text.trim().toLowerCase(),
                                'phone': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                                'password': passCtrl.text,
                                'role': selectedRole,
                              },
                            );
                            ref.invalidate(adminUsersProvider);
                            ref.invalidate(adminAnalyticsProvider);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$selectedRole account created for ${emailCtrl.text.trim()}!'),
                                  backgroundColor: AppColors.veg,
                                ),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to create account: $e'), backgroundColor: AppColors.error),
                              );
                            }
                          }
                        }
                      },
                      child: const Text('Create User Account', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateRestaurantDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final cuisineCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final imageCtrl = TextEditingController(text: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800');
    final deliveryTimeCtrl = TextEditingController(text: '30');
    final deliveryFeeCtrl = TextEditingController(text: '30');
    final minOrderCtrl = TextEditingController(text: '100');
    final commissionCtrl = TextEditingController(text: '15');

    bool createNewOwner = true;
    int? selectedOwnerId;
    final ownerNameCtrl = TextEditingController();
    final ownerEmailCtrl = TextEditingController();
    final ownerPhoneCtrl = TextEditingController();
    final ownerPassCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final usersState = ref.watch(adminUsersProvider);
          final existingOwners = usersState.asData?.value.where((u) => u.role == 'OWNER').toList() ?? [];

          return Container(
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
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Direct Onboard Restaurant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Admin-created restaurants are approved and active immediately.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Restaurant Name', hintText: 'e.g. Spice Route'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: cuisineCtrl,
                      decoration: const InputDecoration(labelText: 'Cuisine', hintText: 'e.g. Indian, Chinese, Italian'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Cuisine required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(labelText: 'Address', hintText: 'Full physical address'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Address required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Contact Phone Number', hintText: 'e.g. 9876543210'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Phone required' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: deliveryFeeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Delivery Fee (₹)', prefixText: '₹ '),
                            validator: (v) => v == null || double.tryParse(v) == null ? 'Fee required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: minOrderCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Min Order (₹)', prefixText: '₹ '),
                            validator: (v) => v == null || double.tryParse(v) == null ? 'Min order required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: deliveryTimeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Est Time (mins)', suffixText: 'mins'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: commissionCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Commission (%)', suffixText: '%'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('Owner Assignment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Create New Owner'),
                            selected: createNewOwner,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(color: createNewOwner ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
                            onSelected: (val) {
                              setModalState(() => createNewOwner = true);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Assign Existing Owner'),
                            selected: !createNewOwner,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(color: !createNewOwner ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
                            onSelected: (val) {
                              setModalState(() {
                                createNewOwner = false;
                                if (existingOwners.isNotEmpty && selectedOwnerId == null) {
                                  selectedOwnerId = existingOwners.first.id;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (createNewOwner) ...[
                      TextFormField(
                        controller: ownerNameCtrl,
                        decoration: const InputDecoration(labelText: 'Owner Full Name', hintText: 'e.g. Rahul Sharma'),
                        validator: (v) => createNewOwner && (v == null || v.trim().isEmpty) ? 'Owner name required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: ownerEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Owner Email', hintText: 'e.g. rahul@restaurant.com'),
                        validator: (v) => createNewOwner && (v == null || !v.contains('@')) ? 'Valid owner email required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: ownerPassCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Owner Password', hintText: 'Min 6 characters'),
                        validator: (v) => createNewOwner && (v == null || v.length < 6) ? 'Password min 6 chars' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: ownerPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Owner Phone (Optional)', hintText: 'e.g. 9876543210'),
                      ),
                    ] else ...[
                      if (existingOwners.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: const Text('No existing owner accounts found. Please choose "Create New Owner" above.', style: TextStyle(fontSize: 13)),
                        )
                      else
                        DropdownButtonFormField<int>(
                          initialValue: selectedOwnerId ?? existingOwners.first.id,
                          decoration: const InputDecoration(labelText: 'Select Existing Owner'),
                          items: existingOwners.map((o) => DropdownMenuItem<int>(
                            value: o.id,
                            child: Text('${o.fullName} (${o.email})'),
                          )).toList(),
                          onChanged: (val) {
                            setModalState(() => selectedOwnerId = val);
                          },
                        ),
                    ],
                    const SizedBox(height: 24),
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
                          if (formKey.currentState!.validate()) {
                            if (!createNewOwner && selectedOwnerId == null && existingOwners.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No owner account selected'), backgroundColor: AppColors.error),
                              );
                              return;
                            }
                            try {
                              final api = ref.read(apiClientProvider);
                              final delFeePaise = (double.parse(deliveryFeeCtrl.text.trim()) * 100).toInt();
                              final minOrderPaise = (double.parse(minOrderCtrl.text.trim()) * 100).toInt();
                              final delTime = int.tryParse(deliveryTimeCtrl.text.trim()) ?? 30;
                              final commRate = (double.tryParse(commissionCtrl.text.trim()) ?? 15.0) / 100.0;

                              final Map<String, dynamic> payload = {
                                'name': nameCtrl.text.trim(),
                                'cuisine': cuisineCtrl.text.trim(),
                                'address': addressCtrl.text.trim(),
                                'phone': phoneCtrl.text.trim(),
                                'image_url': imageCtrl.text.trim().isNotEmpty ? imageCtrl.text.trim() : null,
                                'delivery_time_mins': delTime,
                                'delivery_fee_paise': delFeePaise,
                                'minimum_order_paise': minOrderPaise,
                                'commission_rate': commRate,
                              };

                              if (createNewOwner) {
                                payload['owner_name'] = ownerNameCtrl.text.trim();
                                payload['owner_email'] = ownerEmailCtrl.text.trim().toLowerCase();
                                payload['owner_password'] = ownerPassCtrl.text;
                                payload['owner_phone'] = ownerPhoneCtrl.text.trim().isNotEmpty ? ownerPhoneCtrl.text.trim() : null;
                              } else {
                                payload['owner_id'] = selectedOwnerId ?? existingOwners.first.id;
                              }

                              await api.dio.post('/admin/restaurants', data: payload);
                              ref.invalidate(adminRestaurantsProvider);
                              ref.invalidate(adminUsersProvider);
                              ref.invalidate(adminAnalyticsProvider);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Restaurant onboarded & activated successfully!'),
                                    backgroundColor: AppColors.veg,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to create restaurant: $e'), backgroundColor: AppColors.error),
                                );
                              }
                            }
                          }
                        },
                        child: const Text('Create & Activate Restaurant', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCampaignAnalytics(int promoId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get('/admin/promotions/$promoId/analytics');
      final data = response.data;
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.analytics_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Campaign Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Coupon: ${data['coupon']['code']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              _kpiRow('Total Redemptions', '${data['total_redemptions']} times'),
              const SizedBox(height: 8),
              _kpiRow('Total Discount Given', CurrencyFormatter.formatPaise(data['total_discount_given_paise'] ?? 0)),
              const SizedBox(height: 8),
              _kpiRow('Orders Generated', '${data['total_orders_generated']} orders'),
              const SizedBox(height: 8),
              _kpiRow('Gross Revenue Generated', CurrencyFormatter.formatPaise(data['total_gross_revenue_paise'] ?? 0)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load campaign analytics: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Widget _kpiRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  void _showCreateCampaignDialog() {
    final codeController = TextEditingController();
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final discountValController = TextEditingController(text: '50');
    final minOrderController = TextEditingController(text: '150');
    final maxDiscountController = TextEditingController(text: '100');
    String discountType = 'PERCENTAGE';
    bool firstOrderOnly = false;

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Create Platform Promotion', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Coupon Code (e.g. MEGA50)'),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title (e.g. 50% Platform Mega Sale)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: discountType,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: const [
                          DropdownMenuItem(value: 'PERCENTAGE', child: Text('Percentage %')),
                          DropdownMenuItem(value: 'FLAT', child: Text('Flat ₹')),
                          DropdownMenuItem(value: 'FREE_DELIVERY', child: Text('Free Delivery')),
                        ],
                        onChanged: (v) => setModalState(() => discountType = v ?? 'PERCENTAGE'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: discountValController,
                        decoration: const InputDecoration(labelText: 'Discount Value'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minOrderController,
                        decoration: const InputDecoration(labelText: 'Min Order (₹)', prefixText: '₹ '),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: maxDiscountController,
                        decoration: const InputDecoration(labelText: 'Max Cap (₹)', prefixText: '₹ '),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('First-Time Customers Only'),
                  value: firstOrderOnly,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setModalState(() => firstOrderOnly = v),
                ),
                const SizedBox(height: 24),
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
                      if (codeController.text.trim().isEmpty) return;
                      try {
                        final api = ref.read(apiClientProvider);
                        final minOrderPaise = (double.parse(minOrderController.text.trim()) * 100).toInt();
                        final maxDiscountPaise = (double.parse(maxDiscountController.text.trim()) * 100).toInt();
                        final discountVal = int.parse(discountValController.text.trim());

                        await api.dio.post(
                          '/admin/promotions',
                          data: {
                            'code': codeController.text.trim().toUpperCase(),
                            'title': titleController.text.trim(),
                            'description': descController.text.trim(),
                            'discount_type': discountType,
                            'discount_value': discountVal,
                            'min_order_paise': minOrderPaise,
                            'max_discount_paise': maxDiscountPaise,
                            'usage_limit': 1000,
                            'per_user_limit': 2,
                            'first_order_only': firstOrderOnly,
                          },
                        );
                        ref.invalidate(adminPromotionsProvider);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Platform Campaign Published!'), backgroundColor: AppColors.veg),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to publish campaign: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
                    child: const Text('Publish Platform Campaign', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final analyticsAsync = ref.watch(adminAnalyticsProvider);
    final usersAsync = ref.watch(adminUsersProvider);
    final restaurantsAsync = ref.watch(adminRestaurantsProvider);
    final promosAsync = ref.watch(adminPromotionsProvider);
    final ordersAsync = ref.watch(adminOrdersProvider);
    final auditLogsAsync = ref.watch(adminAuditLogsProvider);
    final timeframe = ref.watch(adminTimeframeProvider);
    final promoFilter = ref.watch(adminPromotionsFilterProvider);

    final oledTheme = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF000000),
      canvasColor: const Color(0xFF121212),
      cardColor: const Color(0xFF121212),
      dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF121212)),
      dividerColor: const Color(0xFF242424),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFF5722),
        secondary: Color(0xFFFF7043),
        surface: Color(0xFF121212),
        onPrimary: Colors.white,
        onSurface: Colors.white,
        onSurfaceVariant: Color(0xFFB0B0B0),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121212),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (_tabController.index != 0) {
          _tabController.animateTo(0);
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
      child: Theme(
      data: oledTheme,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          final tabViews = TabBarView(
          controller: _tabController,
          children: [
            // TAB 0: ADVANCED ANALYTICS & METRICS
            RefreshIndicator(
              onRefresh: () async => ref.invalidate(adminAnalyticsProvider),
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeframe selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Executive Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        DropdownButton<String>(
                          value: timeframe,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(value: 'today', child: Text('Today')),
                            DropdownMenuItem(value: '7d', child: Text('Last 7 Days')),
                            DropdownMenuItem(value: '30d', child: Text('Last 30 Days')),
                            DropdownMenuItem(value: 'all', child: Text('All Time')),
                          ],
                          onChanged: (val) {
                            if (val != null) ref.read(adminTimeframeProvider.notifier).state = val;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    analyticsAsync.when(
                      data: (a) => Column(
                        children: [
                          // Row 1: Revenue KPIs
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  'Gross Order Value (GMV)',
                                  CurrencyFormatter.formatPaise(a['gross_order_value_paise'] ?? 0),
                                  Icons.account_balance_wallet_rounded,
                                  AppColors.veg,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  'Net Platform Revenue',
                                  CurrencyFormatter.formatPaise(a['net_revenue_paise'] ?? 0),
                                  Icons.payments_rounded,
                                  AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Row 2: Promo Discount & Total Orders
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  'Discounts Funded',
                                  CurrencyFormatter.formatPaise(a['promotion_discounts_paise'] ?? 0),
                                  Icons.discount_rounded,
                                  AppColors.secondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  'Total Orders',
                                  '${a['total_orders'] ?? 0}',
                                  Icons.receipt_long_rounded,
                                  AppColors.info,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Row 3: Order Breakdown
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  'Active In-Flight',
                                  '${a['active_orders'] ?? 0}',
                                  Icons.two_wheeler_rounded,
                                  Colors.amber.shade800,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  'Delivered Successfully',
                                  '${a['completed_orders'] ?? 0}',
                                  Icons.check_circle_rounded,
                                  AppColors.veg,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Row 4: Ecosystem Breakdown
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  'Active Restaurants',
                                  '${a['total_restaurants'] ?? 0}',
                                  Icons.storefront_rounded,
                                  Colors.teal,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  'Registered Customers',
                                  '${a['total_customers'] ?? 0}',
                                  Icons.person_pin_circle_rounded,
                                  Colors.indigo,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      loading: () => Column(
                        children: [
                          Row(
                            children: const [
                              Expanded(child: FoodShimmerLoading(width: double.infinity, height: 95)),
                              SizedBox(width: 12),
                              Expanded(child: FoodShimmerLoading(width: double.infinity, height: 95)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: const [
                              Expanded(child: FoodShimmerLoading(width: double.infinity, height: 95)),
                              SizedBox(width: 12),
                              Expanded(child: FoodShimmerLoading(width: double.infinity, height: 95)),
                            ],
                          ),
                        ],
                      ),
                      error: (err, _) => CustomErrorView(
                        message: 'Failed to load executive analytics: ${ApiClient.formatError(err)}',
                        onRetry: () => ref.invalidate(adminAnalyticsProvider),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // TAB 1: USERS DIRECTORY & MANAGEMENT
            RefreshIndicator(
              onRefresh: () async => ref.invalidate(adminUsersProvider),
              color: AppColors.primary,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'User Accounts Directory',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                              label: const Text('Add Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _showCreateUserDialog,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Search Box
                        TextField(
                          controller: _userSearchController,
                          decoration: InputDecoration(
                            hintText: 'Search users by name, email, or phone...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _userSearchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _userSearchController.clear();
                                      setState(() => _userSearchQuery = '');
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (val) => setState(() => _userSearchQuery = val),
                        ),
                        const SizedBox(height: 8),
                        // Role Filters
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildUserRoleChip('ALL', 'All Roles'),
                              const SizedBox(width: 6),
                              _buildUserRoleChip('CUSTOMER', 'Customers'),
                              const SizedBox(width: 6),
                              _buildUserRoleChip('OWNER', 'Restaurant Owners'),
                              const SizedBox(width: 6),
                              _buildUserRoleChip('DRIVER', 'Riders / Drivers'),
                              const SizedBox(width: 6),
                              _buildUserRoleChip('ADMIN', 'Admins'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: usersAsync.when(
                      data: (rawUsers) {
                        final q = _userSearchQuery.trim().toLowerCase();
                        final users = rawUsers.where((u) {
                          if (_userRoleFilter != 'ALL' && u.role.toUpperCase() != _userRoleFilter) {
                            return false;
                          }
                          if (q.isNotEmpty) {
                            final matchName = u.fullName.toLowerCase().contains(q);
                            final matchEmail = u.email.toLowerCase().contains(q);
                            final matchPhone = (u.phone ?? '').toLowerCase().contains(q);
                            if (!matchName && !matchEmail && !matchPhone) return false;
                          }
                          return true;
                        }).toList();

                        if (users.isEmpty) {
                          return CustomEmptyView(
                            title: 'No User Accounts Found',
                            description: _userSearchQuery.isNotEmpty || _userRoleFilter != 'ALL'
                                ? 'No users matched your current search or filter criteria.'
                                : 'No users registered yet. Tap "Add Account" to create one.',
                            icon: Icons.people_outline_rounded,
                          );
                        }

                        final currentAdminId = ref.watch(authProvider).user?.id;

                        return ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final u = users[index];
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            final isCurrentAdmin = currentAdminId == u.id;
                            final isProcessing = _processingUserIds.contains(u.id);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfaceDark : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                                  width: 1,
                                ),
                                boxShadow: AppColors.softShadow,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                      child: Text(
                                        u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : 'U',
                                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 16),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  u.fullName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 15,
                                                    color: isDark ? Colors.white : const Color(0xFF111827),
                                                  ),
                                                ),
                                              ),
                                              if (isCurrentAdmin)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'YOU (ACTIVE ADMIN)',
                                                    style: TextStyle(
                                                      color: AppColors.primary,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            u.email,
                                            style: TextStyle(
                                              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (u.phone != null && u.phone!.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Phone: ${u.phone}',
                                              style: TextStyle(
                                                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              _buildRoleBadge(u.role, isDark),
                                              if (!u.isApproved)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFEF3C7),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                                  ),
                                                  child: const Text(
                                                    '⏳ PENDING APPROVAL',
                                                    style: TextStyle(
                                                      color: Color(0xFFB45309),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: u.isActive
                                                      ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFDCFCE7))
                                                      : (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.4) : const Color(0xFFFEE2E2)),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: u.isActive
                                                        ? (isDark ? const Color(0xFF15803D) : const Color(0xFFBBF7D0))
                                                        : (isDark ? const Color(0xFFB91C1C) : const Color(0xFFFECACA)),
                                                  ),
                                                ),
                                                child: Text(
                                                  u.isActive ? '● Active' : '● Inactive',
                                                  style: TextStyle(
                                                    color: u.isActive
                                                        ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D))
                                                        : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C)),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isProcessing)
                                      const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                      )
                                    else if (!u.isApproved)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.close_rounded, color: AppColors.error, size: 22),
                                            tooltip: 'Reject Application',
                                            onPressed: () => _confirmRejectUser(u),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.check_circle_rounded, color: AppColors.veg, size: 22),
                                            tooltip: 'Approve Application',
                                            onPressed: () => _approveUser(u.id),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete_outline_rounded,
                                              color: isCurrentAdmin ? Colors.grey.shade400 : AppColors.error,
                                              size: 22,
                                            ),
                                            tooltip: isCurrentAdmin ? 'Cannot delete your own account' : 'Delete Account',
                                            onPressed: isCurrentAdmin ? null : () => _confirmDeleteUser(u),
                                          ),
                                        ],
                                      )
                                    else
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Tooltip(
                                            message: u.isActive ? 'Deactivate User Account' : 'Activate User Account',
                                            child: Switch(
                                              value: u.isActive,
                                              activeThumbColor: AppColors.veg,
                                              onChanged: isCurrentAdmin ? null : (v) => _toggleUserActive(u.id),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete_outline_rounded,
                                              color: isCurrentAdmin ? Colors.grey.shade400 : AppColors.error,
                                              size: 22,
                                            ),
                                            tooltip: isCurrentAdmin ? 'Cannot delete your own account' : 'Delete Account',
                                            onPressed: isCurrentAdmin ? null : () => _confirmDeleteUser(u),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: 5,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, _) => const FoodShimmerLoading(width: double.infinity, height: 80),
                      ),
                      error: (err, _) => CustomErrorView(
                        message: 'Failed to load user accounts: ${ApiClient.formatError(err)}',
                        onRetry: () => ref.invalidate(adminUsersProvider),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // TAB 2: RESTAURANTS DIRECTORY & APPROVAL
            RefreshIndicator(
              onRefresh: () async => ref.invalidate(adminRestaurantsProvider),
              color: AppColors.primary,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Partner Stores & Approvals',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add_business_rounded, size: 16),
                              label: const Text('Add Restaurant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _showCreateRestaurantDialog,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Search Box
                        TextField(
                          controller: _restaurantSearchController,
                          decoration: InputDecoration(
                            hintText: 'Search restaurants by name, cuisine, address...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _restaurantSearchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _restaurantSearchController.clear();
                                      setState(() => _restaurantSearchQuery = '');
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (val) => setState(() => _restaurantSearchQuery = val),
                        ),
                        const SizedBox(height: 8),
                        // Status Filters
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildRestaurantStatusChip('ALL', 'All Stores'),
                              const SizedBox(width: 6),
                              _buildRestaurantStatusChip('ACTIVE', 'Active & Approved'),
                              const SizedBox(width: 6),
                              _buildRestaurantStatusChip('PENDING', 'Pending Review'),
                              const SizedBox(width: 6),
                              _buildRestaurantStatusChip('DISABLED', 'Paused / Inactive'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: restaurantsAsync.when(
                      data: (rawRestaurants) {
                        final q = _restaurantSearchQuery.trim().toLowerCase();
                        final restaurants = rawRestaurants.where((r) {
                          if (_restaurantStatusFilter == 'ACTIVE' && (!r.isApproved || !r.isActive)) return false;
                          if (_restaurantStatusFilter == 'PENDING' && r.isApproved) return false;
                          if (_restaurantStatusFilter == 'DISABLED' && (!r.isApproved || r.isActive)) return false;
                          if (q.isNotEmpty) {
                            final matchName = r.name.toLowerCase().contains(q);
                            final matchCuisine = r.cuisine.toLowerCase().contains(q);
                            final matchAddr = (r.addressText ?? '').toLowerCase().contains(q);
                            if (!matchName && !matchCuisine && !matchAddr) return false;
                          }
                          return true;
                        }).toList();

                        if (restaurants.isEmpty) {
                          return ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.storefront_outlined, size: 72, color: Colors.grey.shade300),
                                    const SizedBox(height: 16),
                                    Text(
                                      _restaurantSearchQuery.isNotEmpty || _restaurantStatusFilter != 'ALL'
                                          ? 'No Stores Found'
                                          : 'No Restaurants Registered Yet',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _restaurantSearchQuery.isNotEmpty || _restaurantStatusFilter != 'ALL'
                                          ? 'Try adjusting your search keywords or filter status.'
                                          : 'Click "Add Restaurant" to onboard directly, or invite owners to register.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: _showCreateRestaurantDialog,
                                      icon: const Icon(Icons.add_business_rounded),
                                      label: const Text('Direct Onboard Restaurant'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: restaurants.length,
                          itemBuilder: (context, index) {
                            final r = restaurants[index];
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            final isProcessing = _processingRestaurantIds.contains(r.id);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfaceDark : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                                  width: 1,
                                ),
                                boxShadow: AppColors.softShadow,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: CachedNetworkImage(
                                            imageUrl: AppConstants.resolveImageUrl(r.imageUrl),
                                            width: 58,
                                            height: 58,
                                            fit: BoxFit.cover,
                                            errorWidget: (context, url, error) => Container(
                                              width: 58,
                                              height: 58,
                                              color: isDark ? Colors.white10 : Colors.grey.shade200,
                                              child: const Icon(Icons.storefront_rounded, color: AppColors.primary),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      r.name,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w800,
                                                        fontSize: 16,
                                                        color: isDark ? Colors.white : const Color(0xFF111827),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: r.isApproved
                                                          ? (r.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6))
                                                          : const Color(0xFFFEF3C7),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(
                                                        color: r.isApproved
                                                            ? (r.isActive ? const Color(0xFF86EFAC) : const Color(0xFFD1D5DB))
                                                            : const Color(0xFFFDE68A),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          r.isApproved
                                                              ? (r.isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded)
                                                              : Icons.pending_actions_rounded,
                                                          size: 12,
                                                          color: r.isApproved
                                                              ? (r.isActive ? const Color(0xFF15803D) : const Color(0xFF4B5563))
                                                              : const Color(0xFFB45309),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          r.isApproved ? (r.isActive ? 'ACTIVE & APPROVED' : 'STORE PAUSED') : 'PENDING REVIEW',
                                                          style: TextStyle(
                                                            color: r.isApproved
                                                                ? (r.isActive ? const Color(0xFF15803D) : const Color(0xFF4B5563))
                                                                : const Color(0xFFB45309),
                                                            fontWeight: FontWeight.w800,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${r.cuisine} • Rating: ${r.rating} ⭐ • Est. ${r.estimatedDeliveryTime}',
                                                style: TextStyle(
                                                  color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              if (r.addressText != null && r.addressText!.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  r.addressText!,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Divider(height: 1, color: isDark ? AppColors.borderDark : const Color(0xFFF3F4F6)),
                                    const SizedBox(height: 10),
                                    if (!r.isApproved) ...[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Store ID: #${r.id}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF3B2506) : const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Action Required',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFFD97706),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      if (isProcessing)
                                        const Center(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(vertical: 8),
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                                            ),
                                          ),
                                        )
                                      else
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: AppColors.error,
                                                  side: const BorderSide(color: AppColors.error, width: 1.2),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                  minimumSize: const Size(0, 44),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                icon: const Icon(Icons.close_rounded, size: 16),
                                                onPressed: () => _confirmRejectRestaurant(r),
                                                label: const Text('Reject', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.veg,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                  minimumSize: const Size(0, 44),
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                                onPressed: () => _approveRestaurant(r.id),
                                                label: const Text('Approve Store', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                                              ),
                                            ),
                                          ],
                                        ),
                                    ] else ...[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Store ID: #${r.id}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                                            ),
                                          ),
                                          if (isProcessing)
                                            const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                                            )
                                          else
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  r.isActive ? 'Accepting Orders' : 'Store Disabled',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: r.isActive ? AppColors.veg : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Tooltip(
                                                  message: r.isActive ? 'Suspend Restaurant' : 'Activate Restaurant',
                                                  child: Switch(
                                                    value: r.isActive,
                                                    activeThumbColor: AppColors.veg,
                                                    onChanged: (v) => _toggleRestaurantActive(r.id),
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: 4,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, _) => const FoodShimmerLoading(width: double.infinity, height: 130),
                      ),
                      error: (err, _) => CustomErrorView(
                        message: 'Failed to load restaurants directory: ${ApiClient.formatError(err)}',
                        onRetry: () => ref.invalidate(adminRestaurantsProvider),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // TAB 3: LIVE ORDERS MONITORING
            RefreshIndicator(
              onRefresh: () async => ref.invalidate(adminOrdersProvider),
              color: AppColors.primary,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Live Orders Monitoring',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        // Search Box
                        TextField(
                          controller: _orderSearchController,
                          decoration: InputDecoration(
                            hintText: 'Search orders by #ID, customer name, restaurant...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _orderSearchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _orderSearchController.clear();
                                      setState(() => _orderSearchQuery = '');
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (val) => setState(() => _orderSearchQuery = val),
                        ),
                        const SizedBox(height: 8),
                        // Order Status Filters
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildOrderStatusChip('ALL', 'All Orders'),
                              const SizedBox(width: 6),
                              _buildOrderStatusChip('PENDING', 'Pending'),
                              const SizedBox(width: 6),
                              _buildOrderStatusChip('CONFIRMED', 'Confirmed'),
                              const SizedBox(width: 6),
                              _buildOrderStatusChip('PREPARING', 'Preparing'),
                              const SizedBox(width: 6),
                              _buildOrderStatusChip('OUT_FOR_DELIVERY', 'Out for Delivery'),
                              const SizedBox(width: 6),
                              _buildOrderStatusChip('DELIVERED', 'Delivered'),
                              const SizedBox(width: 6),
                              _buildOrderStatusChip('CANCELLED', 'Cancelled'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ordersAsync.when(
                      data: (rawOrders) {
                        final q = _orderSearchQuery.trim().toLowerCase();
                        final orders = rawOrders.where((o) {
                          if (_orderStatusFilter != 'ALL' && o.status.toUpperCase() != _orderStatusFilter) {
                            return false;
                          }
                          if (q.isNotEmpty) {
                            final matchId = '${o.id}'.contains(q);
                            final matchRest = o.restaurant.name.toLowerCase().contains(q);
                            final matchAddr = o.deliveryAddress.toLowerCase().contains(q);
                            final matchStatus = o.status.toLowerCase().contains(q);
                            if (!matchId && !matchRest && !matchAddr && !matchStatus) return false;
                          }
                          return true;
                        }).toList();

                        if (orders.isEmpty) {
                          return CustomEmptyView(
                            title: 'No Orders Found',
                            description: _orderSearchQuery.isNotEmpty || _orderStatusFilter != 'ALL'
                                ? 'No orders match your active search and status filters.'
                                : 'No customer orders have been placed in this system yet.',
                            icon: Icons.receipt_long_rounded,
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: orders.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final o = orders[index];
                            final isDark = Theme.of(context).brightness == Brightness.dark;

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfaceDark : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                                ),
                                boxShadow: AppColors.softShadow,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Order #${o.id}',
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: o.status == 'DELIVERED'
                                              ? const Color(0xFFDCFCE7)
                                              : o.status == 'CANCELLED'
                                                  ? const Color(0xFFFEE2E2)
                                                  : const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          o.status,
                                          style: TextStyle(
                                            color: o.status == 'DELIVERED'
                                                ? const Color(0xFF15803D)
                                                : o.status == 'CANCELLED'
                                                    ? const Color(0xFFB91C1C)
                                                    : const Color(0xFFB45309),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.storefront_rounded, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          o.restaurant.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 16, color: Colors.blueGrey),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Address: ${o.deliveryAddress}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Divider(height: 1, color: isDark ? AppColors.borderDark : const Color(0xFFF3F4F6)),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${o.items.length} items • ${o.paymentMethod}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            CurrencyFormatter.formatPaise(o.totalPaise),
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.veg),
                                          ),
                                        ],
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () => _showOrderDetailsDialog(o),
                                        icon: const Icon(Icons.visibility_outlined, size: 16),
                                        label: const Text('View Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                          foregroundColor: AppColors.primary,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () => ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: 4,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, _) => const FoodShimmerLoading(width: double.infinity, height: 110),
                      ),
                      error: (err, _) => CustomErrorView(
                        message: 'Failed to load live orders: ${ApiClient.formatError(err)}',
                        onRetry: () => ref.invalidate(adminOrdersProvider),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // TAB 4: PROMOTION ENGINE & CAMPAIGNS
            Scaffold(
              backgroundColor: Colors.grey.shade50,
              floatingActionButton: FloatingActionButton.extended(
                onPressed: _showCreateCampaignDialog,
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Create Campaign', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              body: RefreshIndicator(
                onRefresh: () async => ref.invalidate(adminPromotionsProvider),
                color: AppColors.primary,
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          _filterChip('all', 'All Campaigns', promoFilter),
                          const SizedBox(width: 8),
                          _filterChip('active', 'Active Now', promoFilter),
                          const SizedBox(width: 8),
                          _filterChip('scheduled', 'Scheduled', promoFilter),
                          const SizedBox(width: 8),
                          _filterChip('expired', 'Expired', promoFilter),
                        ],
                      ),
                    ),
                    Expanded(
                      child: promosAsync.when(
                        data: (promos) {
                          if (promos.isEmpty) {
                            return const CustomEmptyView(
                              title: 'No Campaigns Found',
                              description: 'No promotions match this status filter. Tap "Create Campaign" to launch one.',
                              icon: Icons.local_offer_outlined,
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: promos.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final promo = promos[index];
                              return Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: AppColors.softShadow,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                promo.code,
                                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.blueGrey.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                promo.restaurantName ?? 'Platform-Wide',
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Switch(
                                          value: promo.isActive,
                                          activeThumbColor: AppColors.veg,
                                          onChanged: (v) async {
                                            final apiClient = ref.read(apiClientProvider);
                                            await apiClient.dio.put('/admin/promotions/${promo.id}/toggle');
                                            ref.invalidate(adminPromotionsProvider);
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(promo.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(promo.description, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Redeemed: ${promo.usedCount}/${promo.usageLimit}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        TextButton.icon(
                                          onPressed: () => _showCampaignAnalytics(promo.id),
                                          icon: const Icon(Icons.insights_rounded, size: 16),
                                          label: const Text('Performance'),
                                          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        loading: () => ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: 4,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (_, _) => const FoodShimmerLoading(width: double.infinity, height: 110),
                        ),
                        error: (err, _) => CustomErrorView(
                          message: 'Failed to load promotions: ${ApiClient.formatError(err)}',
                          onRetry: () => ref.invalidate(adminPromotionsProvider),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // TAB 5: SYSTEM AUDIT LOGS & ACTIVITY HISTORY
            RefreshIndicator(
              onRefresh: () async => ref.invalidate(adminAuditLogsProvider),
              color: AppColors.primary,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Admin Activity & Audit History',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  Expanded(
                    child: auditLogsAsync.when(
                      data: (logs) {
                        if (logs.isEmpty) {
                          return const CustomEmptyView(
                            title: 'No Activity Recorded Yet',
                            description: 'Admin operations such as approvals, profile changes, and account updates will be tracked here.',
                            icon: Icons.history_rounded,
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: logs.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            final actionStr = log['action']?.toString() ?? 'ACTION';
                            final targetTypeStr = log['target_type']?.toString();
                            final targetIdStr = log['target_id']?.toString();
                            final detailsStr = log['details']?.toString() ?? actionStr;
                            final adminNameStr = log['admin_name']?.toString() ?? 'Admin #${log['admin_id'] ?? ""}';
                            final createdAtStr = log['created_at']?.toString();

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfaceDark : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                                ),
                                boxShadow: AppColors.softShadow,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                    child: const Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blueGrey.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: Colors.blueGrey.shade200),
                                              ),
                                              child: Text(
                                                actionStr,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.blueGrey),
                                              ),
                                            ),
                                            if (targetTypeStr != null) ...[
                                              const SizedBox(width: 6),
                                              Text(
                                                '$targetTypeStr #${targetIdStr ?? ""}',
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          detailsStr,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? Colors.white : const Color(0xFF111827),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'By Admin: $adminNameStr • ${createdAtStr != null && createdAtStr.length >= 16 ? createdAtStr.substring(0, 16) : (createdAtStr ?? "")}',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () => ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: 5,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, _) => const FoodShimmerLoading(width: double.infinity, height: 75),
                      ),
                      error: (err, _) => CustomErrorView(
                        message: 'Failed to load audit history: ${ApiClient.formatError(err)}',
                        onRetry: () => ref.invalidate(adminAuditLogsProvider),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        if (isDesktop) {
          final titles = [
            'Executive Dashboard & Overview',
            'User Accounts Directory',
            'Restaurants Directory',
            'Live Orders Monitoring',
            'Promotions & Campaigns',
            'System Activity & Audit Logs',
          ];

          return Scaffold(
            backgroundColor: const Color(0xFF000000),
            body: Row(
              children: [
                DashboardSidebar(
                  portalTitle: 'Admin Portal',
                  portalSubtitle: 'Super Admin',
                  selectedIndex: _tabController.index,
                  onItemSelected: (idx) {
                    setState(() {
                      _tabController.index = idx;
                    });
                  },
                  items: const [
                    SidebarItem(index: 0, label: 'Executive Overview', icon: Icons.dashboard_rounded),
                    SidebarItem(index: 1, label: 'Users Management', icon: Icons.people_alt_rounded),
                    SidebarItem(index: 2, label: 'Restaurants Directory', icon: Icons.storefront_rounded),
                    SidebarItem(index: 3, label: 'Live Orders', icon: Icons.receipt_long_rounded),
                    SidebarItem(index: 4, label: 'Offers & Coupons', icon: Icons.local_offer_rounded),
                    SidebarItem(index: 5, label: 'Activity Logs', icon: Icons.history_rounded),
                  ],
                ),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 64,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: const BoxDecoration(
                          color: Color(0xFF121212),
                          border: Border(bottom: BorderSide(color: Color(0xFF242424))),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _tabController.index < titles.length ? titles[_tabController.index] : 'Admin Portal',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Admin Profile Settings',
                              icon: const Icon(Icons.manage_accounts_outlined, color: Color(0xFFFF5722)),
                              onPressed: _showAdminProfileDialog,
                            ),
                            IconButton(
                              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                              onPressed: () => NotificationSheet.show(context),
                            ),
                            IconButton(
                              tooltip: 'Logout',
                              icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                              onPressed: () => ref.read(authProvider.notifier).logout(),
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: tabViews),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF000000),
          appBar: AppBar(
            title: const Text('Admin System Portal', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
            backgroundColor: const Color(0xFF121212),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'Profile Settings',
                icon: const Icon(Icons.manage_accounts_outlined, color: Color(0xFFFF5722)),
                onPressed: _showAdminProfileDialog,
              ),
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () => NotificationSheet.show(context),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                onPressed: () => ref.read(authProvider.notifier).logout(),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFFFF5722),
              unselectedLabelColor: Colors.white70,
              indicatorColor: const Color(0xFFFF5722),
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              tabAlignment: TabAlignment.start,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.dashboard_rounded, size: 20), text: 'Analytics'),
                Tab(icon: Icon(Icons.people_alt_rounded, size: 20), text: 'Users'),
                Tab(icon: Icon(Icons.storefront_rounded, size: 20), text: 'Restaurants'),
                Tab(icon: Icon(Icons.receipt_long_rounded, size: 20), text: 'Orders'),
                Tab(icon: Icon(Icons.local_offer_rounded, size: 20), text: 'Promotions'),
                Tab(icon: Icon(Icons.history_rounded, size: 20), text: 'Audit Logs'),
              ],
            ),
          ),
          body: tabViews,
        );
      },
    ),
  ),
  );
}

  Widget _buildUserRoleChip(String role, String label) {
    final isSelected = _userRoleFilter == role;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
      onSelected: (_) => setState(() => _userRoleFilter = role),
    );
  }

  Widget _buildRestaurantStatusChip(String status, String label) {
    final isSelected = _restaurantStatusFilter == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
      onSelected: (_) => setState(() => _restaurantStatusFilter = status),
    );
  }

  Widget _buildOrderStatusChip(String status, String label) {
    final isSelected = _orderStatusFilter == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
      onSelected: (_) => setState(() => _orderStatusFilter = status),
    );
  }

  Widget _buildRoleBadge(String role, bool isDark) {
    Color bg;
    Color text;
    Color border;

    switch (role.toUpperCase()) {
      case 'ADMIN':
        bg = isDark ? const Color(0xFF581C87).withValues(alpha: 0.4) : const Color(0xFFF3E8FF);
        text = isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7E22CE);
        border = isDark ? const Color(0xFF7E22CE) : const Color(0xFFE9D5FF);
        break;
      case 'RESTAURANT_OWNER':
      case 'OWNER':
        bg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFEF3C7);
        text = isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309);
        border = isDark ? const Color(0xFFB45309) : const Color(0xFFFDE68A);
        break;
      case 'DELIVERY_PARTNER':
      case 'DRIVER':
        bg = isDark ? const Color(0xFF0C4A6E).withValues(alpha: 0.4) : const Color(0xFFE0F2FE);
        text = isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1);
        border = isDark ? const Color(0xFF0369A1) : const Color(0xFFBAE6FD);
        break;
      case 'CUSTOMER':
      default:
        bg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFDCFCE7);
        text = isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
        border = isDark ? const Color(0xFF15803D) : const Color(0xFFBBF7D0);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: text,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _filterChip(String key, String label, String current) {
    final isSelected = key == current;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
      onSelected: (_) => ref.read(adminPromotionsFilterProvider.notifier).state = key,
    );
  }

  Widget _buildMetricCard(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF242424)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
