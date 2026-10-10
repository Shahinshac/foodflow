import 'package:flutter/material.dart';
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

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<int> _processingRestaurantIds = {};
  final Set<int> _processingUserIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    final timeframe = ref.watch(adminTimeframeProvider);
    final promoFilter = ref.watch(adminPromotionsFilterProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        final tabViews = TabBarView(
          controller: _tabController,
          children: [
            // TAB 1: ADVANCED ANALYTICS & METRICS
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

          // TAB 2: PROMOTION ENGINE & CAMPAIGNS
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
                  // Filter Chips
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

          // TAB 3: RESTAURANTS DIRECTORY & APPROVAL
          RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminRestaurantsProvider),
            color: AppColors.primary,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
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
                ),
                Expanded(
                  child: restaurantsAsync.when(
                    data: (restaurants) {
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
                                  const Text('No Restaurants Registered Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Click "Add Restaurant" to onboard directly, or invite owners to register.',
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
                                                // Status Badge
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
                                  // Action Buttons Area
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        r.isApproved ? 'Store ID: #${r.id}' : 'Store ID: #${r.id} • Requires Approval',
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
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            if (!r.isApproved) ...[
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: AppColors.error,
                                                  side: const BorderSide(color: AppColors.error, width: 1.2),
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                icon: const Icon(Icons.close_rounded, size: 16),
                                                onPressed: () => _confirmRejectRestaurant(r),
                                                label: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                              ),
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.veg,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                                onPressed: () => _approveRestaurant(r.id),
                                                label: const Text('Approve Store', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                              ),
                                            ] else ...[
                                              Text(
                                                r.isActive ? 'Accepting Orders' : 'Store Disabled',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: r.isActive ? AppColors.veg : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                                                ),
                                              ),
                                              Tooltip(
                                                message: r.isActive ? 'Suspend Restaurant' : 'Activate Restaurant',
                                                child: Switch(
                                                  value: r.isActive,
                                                  activeThumbColor: AppColors.veg,
                                                  onChanged: (v) => _toggleRestaurantActive(r.id),
                                                ),
                                              ),
                                            ],
                                          ],
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

          // TAB 4: USERS DIRECTORY & MANAGEMENT
          RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminUsersProvider),
            color: AppColors.primary,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'User Accounts Management',
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
                ),
                Expanded(
                  child: usersAsync.when(
                    data: (users) {
                      if (users.isEmpty) {
                        return const CustomEmptyView(
                          title: 'No User Accounts',
                          description: 'No users registered yet. Tap "Add Account" to create one.',
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
                                  // User Avatar
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                    child: Text(
                                      u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : 'U',
                                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 16),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // User Details & Badges
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

                                  // Actions: Switch + Delete Button
                                  if (isProcessing)
                                    const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
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
        ],
      );

        if (isDesktop) {
          return Scaffold(
            backgroundColor: Colors.grey.shade50,
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
                    SidebarItem(index: 0, label: 'Dashboard & Analytics', icon: Icons.dashboard_rounded),
                    SidebarItem(index: 1, label: 'Offers & Coupons', icon: Icons.local_offer_rounded),
                    SidebarItem(index: 2, label: 'Restaurants Directory', icon: Icons.storefront_rounded),
                    SidebarItem(index: 3, label: 'Users Management', icon: Icons.people_alt_rounded),
                  ],
                ),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 64,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _tabController.index == 0
                                  ? 'Executive Dashboard & Overview'
                                  : _tabController.index == 1
                                      ? 'Promotions & Campaigns'
                                      : _tabController.index == 2
                                          ? 'Restaurants Directory'
                                          : 'User Accounts Directory',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.notifications_outlined),
                              onPressed: () => NotificationSheet.show(context),
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
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: const Text('Admin System Portal', style: TextStyle(fontWeight: FontWeight.w900)),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => NotificationSheet.show(context),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () => ref.read(authProvider.notifier).logout(),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: AppColors.primary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.dashboard_rounded), text: 'Analytics'),
                Tab(icon: Icon(Icons.local_offer_rounded), text: 'Promotions'),
                Tab(icon: Icon(Icons.storefront_rounded), text: 'Restaurants'),
                Tab(icon: Icon(Icons.people_alt_rounded), text: 'Users'),
              ],
            ),
          ),
          body: tabViews,
        );
      },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB)),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}
