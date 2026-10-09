import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
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
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.put('/admin/users/$userId/toggle-active');
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminAnalyticsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User status updated'), backgroundColor: AppColors.veg),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update user: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _approveRestaurant(int restaurantId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.put('/admin/restaurants/$restaurantId/approve');
      ref.invalidate(adminRestaurantsProvider);
      ref.invalidate(adminAnalyticsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restaurant approved successfully!'), backgroundColor: AppColors.veg),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve: $e'), backgroundColor: AppColors.error),
        );
      }
    }
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
      body: TabBarView(
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
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    error: (err, _) => Center(child: Text('Error: $err')),
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
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.local_offer_outlined, size: 64, color: Colors.black26),
                                SizedBox(height: 12),
                                Text('No campaigns match this filter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
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
                      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      error: (err, _) => Center(child: Text('Error: $err')),
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
            child: restaurantsAsync.when(
              data: (restaurants) => ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: restaurants.length,
                itemBuilder: (context, index) {
                  final r = restaurants[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: AppConstants.resolveImageUrl(r.imageUrl),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text('${r.cuisine} • Rating: ${r.rating} ⭐', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: r.isActive ? AppColors.veg : AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _approveRestaurant(r.id),
                        child: Text(r.isActive ? 'Active' : 'Approve', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),

          // TAB 4: USERS DIRECTORY
          RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminUsersProvider),
            color: AppColors.primary,
            child: usersAsync.when(
              data: (users) => ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final u = users[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        child: Text(u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : 'U', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: Text('${u.email} • ${u.role}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      trailing: Switch(
                        value: true,
                        activeThumbColor: AppColors.veg,
                        onChanged: (v) => _toggleUserActive(u.id),
                      ),
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(val, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.black87)),
        ],
      ),
    );
  }
}
