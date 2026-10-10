import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/error_and_empty_views.dart';
import 'cart_providers.dart';
import 'coupon_bottom_sheet.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartSummaryProvider);
    final appliedCoupon = ref.watch(appliedCouponProvider);
    final couponDiscount = ref.watch(couponDiscountPaiseProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Your Cart', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
            label: const Text('Clear', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            onPressed: () {
              ref.read(cartNotifierProvider.notifier).clearCart();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: cartAsync.when(
        data: (cart) {
          if (cart.items.isEmpty) {
            return Center(
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
                      child: Icon(Icons.shopping_bag_outlined, size: 72, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Your cart is empty',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Good food is waiting for you! Explore tasty meals from our top restaurants.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => context.go('/'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('Browse Restaurants', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            );
          }

          final subtotal = cart.subtotalPaise;
          final deliveryFee = cart.deliveryFeePaise;
          final tax = cart.taxPaise;
          final discount = couponDiscount > 0 ? couponDiscount : cart.discountPaise;
          final totalPayable = (subtotal + deliveryFee + tax - discount).clamp(0, 99999999);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // Restaurant Card
                if (cart.restaurant != null) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppColors.softShadow,
                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.storefront_rounded, size: 24, color: AppColors.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cart.restaurant!.name,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.timer_outlined, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Delivery in ${cart.restaurant!.estimatedDeliveryTime}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Order Items Section
                Text(
                  'Order Items',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.softShadow,
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cart.items.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? AppColors.borderDark : AppColors.dividerLight),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: item.foodItem.isVeg ? AppColors.veg : AppColors.nonVeg,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                Icons.circle,
                                size: 8,
                                color: item.foodItem.isVeg ? AppColors.veg : AppColors.nonVeg,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.foodItem.name,
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    CurrencyFormatter.formatPaise(item.foodItem.pricePaise),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Quantity selector
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                              ),
                              child: Row(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      ref.read(cartNotifierProvider.notifier).updateQuantity(item.id, item.quantity - 1);
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      child: Icon(Icons.remove, size: 16),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(
                                      '${item.quantity}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      ref.read(cartNotifierProvider.notifier).updateQuantity(item.id, item.quantity + 1);
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      child: Icon(Icons.add, size: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 65,
                              child: Text(
                                CurrencyFormatter.formatPaise(item.foodItem.pricePaise * item.quantity),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Offers & Coupons Card
                Text(
                  'Offers & Benefits',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.softShadow,
                    border: Border.all(
                      color: appliedCoupon != null ? AppColors.veg.withValues(alpha: 0.5) : (isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                  ),
                  child: appliedCoupon != null
                      ? Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.veg.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.verified_rounded, color: AppColors.veg, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        appliedCoupon.code,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.veg.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('APPLIED', style: TextStyle(color: AppColors.veg, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Saved ${CurrencyFormatter.formatPaise(discount)} with this offer!',
                                    style: const TextStyle(color: AppColors.veg, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                ref.read(cartNotifierProvider.notifier).removeCoupon();
                              },
                              style: TextButton.styleFrom(foregroundColor: AppColors.error),
                              child: const Text('REMOVE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        )
                      : InkWell(
                          onTap: () {
                            CouponBottomSheet.show(
                              context,
                              restaurantId: cart.restaurant?.id,
                              subtotalPaise: subtotal,
                              deliveryFeePaise: deliveryFee,
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Apply Coupon / View Offers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Save more on your delicious feast',
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.primary),
                            ],
                          ),
                        ),
                ),

                const SizedBox(height: 24),

                // Bill Details Section
                Text(
                  'Bill Summary',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.softShadow,
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      _buildBillRow('Item Subtotal', CurrencyFormatter.formatPaise(subtotal), theme, isDark),
                      const SizedBox(height: 12),
                      _buildBillRow('Delivery Fee', CurrencyFormatter.formatPaise(deliveryFee), theme, isDark),
                      const SizedBox(height: 12),
                      _buildBillRow('Taxes & Charges (5% GST)', CurrencyFormatter.formatPaise(tax), theme, isDark),
                      if (discount > 0) ...[
                        const SizedBox(height: 12),
                        _buildBillRow(
                          'Offer Discount (${appliedCoupon?.code ?? 'PROMO'})',
                          '- ${CurrencyFormatter.formatPaise(discount)}',
                          theme,
                          isDark,
                          isDiscount: true,
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Divider(height: 1, color: isDark ? AppColors.borderDark : AppColors.dividerLight),
                      ),
                      _buildBillRow('Total Payable', CurrencyFormatter.formatPaise(totalPayable), theme, isDark, isTotal: true),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      );
    },
    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    error: (err, stack) => CustomErrorView(
      message: 'Failed to load cart: ${ApiClient.formatError(err)}',
      onRetry: () => ref.refresh(cartSummaryProvider),
    ),
  ),
  bottomNavigationBar: cartAsync.when(
    data: (cart) {
      if (cart.items.isEmpty) return const SizedBox.shrink();
      final discount = couponDiscount > 0 ? couponDiscount : cart.discountPaise;
      final totalPayable = (cart.subtotalPaise + cart.deliveryFeePaise + cart.taxPaise - discount).clamp(0, 99999999);

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ElevatedButton(
                onPressed: () => context.push('/checkout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkAction,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Proceed to Checkout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(CurrencyFormatter.formatPaise(totalPayable), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    loading: () => const SizedBox.shrink(),
    error: (_, _) => const SizedBox.shrink(),
  ),
);
  }

  Widget _buildBillRow(
    String label,
    String value,
    ThemeData theme,
    bool isDark, {
    bool isTotal = false,
    bool isDiscount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w500,
            color: isDiscount ? AppColors.veg : (isTotal ? (isDark ? Colors.white : Colors.black87) : theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
            color: isDiscount ? AppColors.veg : (isTotal ? AppColors.primary : (isDark ? Colors.white : Colors.black87)),
          ),
        ),
      ],
    );
  }
}
