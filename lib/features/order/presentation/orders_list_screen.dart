import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/error_and_empty_views.dart';
import '../../../core/widgets/motion_system.dart';
import 'order_providers.dart';

class OrdersListScreen extends ConsumerWidget {
  const OrdersListScreen({super.key});

  void _showCancelDialog(BuildContext context, WidgetRef ref, int orderId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Order?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel this order? This action cannot be reversed.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Reason for cancellation (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final reason = reasonController.text.trim().isEmpty ? 'Cancelled by customer' : reasonController.text.trim();
              final success = await ref.read(orderActionNotifierProvider.notifier).cancelOrder(orderId, reason);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Order cancelled successfully' : 'Unable to cancel order at this stage'),
                    backgroundColor: success ? AppColors.veg : AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
  }

  void _handleReorder(BuildContext context, WidgetRef ref, int orderId) async {
    final result = await ref.read(orderActionNotifierProvider.notifier).reorder(orderId);
    if (!context.mounted) return;

    if (result != null && result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(result.message, style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
          backgroundColor: AppColors.veg,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.push('/cart');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to reorder. Items may no longer be available.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(userOrdersProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('My Orders', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(userOrdersProvider),
        color: AppColors.primary,
        child: ordersAsync.when(
          data: (orders) {
            if (orders.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.receipt_long_outlined, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No orders placed yet',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your orders will appear here once you make your first delicious purchase.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => context.go('/'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: const Text('Explore Restaurants', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.all(16.0),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];

                Color statusColor = AppColors.info;
                Color statusBgColor = AppColors.info.withValues(alpha: 0.12);
                if (order.status == 'DELIVERED') {
                  statusColor = AppColors.veg;
                  statusBgColor = AppColors.veg.withValues(alpha: 0.12);
                } else if (order.status == 'CANCELLED' || order.status == 'REJECTED') {
                  statusColor = AppColors.error;
                  statusBgColor = AppColors.error.withValues(alpha: 0.12);
                } else if (order.status == 'PLACED' || order.status == 'PREPARING' || order.status == 'RESTAURANT_CONFIRMED') {
                  statusColor = AppColors.primary;
                  statusBgColor = AppColors.primary.withValues(alpha: 0.12);
                }

                final orderDate = order.createdAt.length >= 10
                    ? order.createdAt.substring(0, 10)
                    : order.createdAt;

                final canCancel = order.status == 'PLACED' || order.status == 'RESTAURANT_CONFIRMED';
                final isDelivered = order.status == 'DELIVERED';
                final isCancelled = order.status == 'CANCELLED';

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => context.push('/order/${order.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    order.restaurant.name,
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusBgColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    order.status.replaceAll('_', ' '),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${order.items.length} ${order.items.length == 1 ? 'item' : 'items'} • ${CurrencyFormatter.formatPaise(order.totalPaise)}',
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (order.discountPaise > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.local_offer_rounded, size: 12, color: AppColors.veg),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Saved ${CurrencyFormatter.formatPaise(order.discountPaise)} (${order.couponCode ?? "PROMO"})',
                                    style: const TextStyle(color: AppColors.veg, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              'Placed on $orderDate',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                            if (isCancelled && order.cancellationReason != null) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Cancelled: ${order.cancellationReason}${order.isRefunded ? ' (Refunded)' : ''}',
                                  style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.0),
                              child: Divider(height: 1),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Action button 1: Reorder
                                OutlinedButton.icon(
                                  onPressed: () => _handleReorder(context, ref, order.id),
                                  icon: const Icon(Icons.replay_rounded, size: 16),
                                  label: const Text('Reorder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(color: AppColors.primary),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (canCancel) ...[
                                      TextButton(
                                        onPressed: () => _showCancelDialog(context, ref, order.id),
                                        style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    InkWell(
                                      onTap: () => context.push('/order/${order.id}'),
                                      child: Row(
                                        children: [
                                          Text(
                                            isDelivered ? 'View Details' : 'Live Tracking',
                                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.primary),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 350.ms, delay: (index * 60).ms).slideY(begin: 0.05);
              },
            );
          },
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (_, _) => const FoodShimmerLoading(width: double.infinity, height: 180),
          ),
          error: (err, stack) => CustomErrorView(
            message: 'Failed to load your orders: ${ApiClient.formatError(err)}',
            onRetry: () => ref.invalidate(userOrdersProvider),
          ),
        ),
      ),
    );
  }
}
