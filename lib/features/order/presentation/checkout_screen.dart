import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/error_and_empty_views.dart';
import '../../auth/presentation/profile_screen.dart';
import '../../cart/presentation/cart_providers.dart';
import '../../cart/presentation/coupon_bottom_sheet.dart';
import 'order_providers.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _addressController = TextEditingController();
  double? _deliveryLat;
  double? _deliveryLng;
  bool _isLocating = false;
  String _selectedPayment = 'COD';
  bool _isSubmitting = false;
  int? _selectedAddressId;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    final pos = await LocationService.determinePosition(
      onError: (msg) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.error),
          );
        }
      },
    );
    if (pos != null) {
      final addr = await LocationService.reverseGeocode(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _deliveryLat = pos.latitude;
          _deliveryLng = pos.longitude;
          _selectedAddressId = null;
          _addressController.text = addr;
          _isLocating = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _pickOnMap() async {
    final result = await LocationService.showMapPicker(
      context,
      initialCenter: _deliveryLat != null && _deliveryLng != null
          ? LatLng(_deliveryLat!, _deliveryLng!)
          : null,
      initialAddress: _addressController.text.trim(),
    );
    if (result != null && mounted) {
      setState(() {
        _deliveryLat = result.coordinates.latitude;
        _deliveryLng = result.coordinates.longitude;
        _selectedAddressId = null;
        _addressController.text = result.address;
      });
    }
  }

  void _placeOrder() async {
    if (_isSubmitting) return; // Prevent duplicate order creation on multiple taps
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or select a delivery address'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(orderRepositoryProvider);
      final appliedCoupon = ref.read(appliedCouponProvider);

      final order = await repo.createOrder(
        deliveryAddress: _addressController.text.trim(),
        paymentMethod: _selectedPayment,
        couponCode: appliedCoupon?.code,
        deliveryLat: _deliveryLat,
        deliveryLng: _deliveryLng,
      );

      // Reset cart and coupon states
      ref.read(appliedCouponProvider.notifier).state = null;
      ref.read(couponDiscountPaiseProvider.notifier).state = 0;
      ref.invalidate(cartSummaryProvider);
      ref.invalidate(userOrdersProvider);

      if (mounted) {
        context.go('/order/${order.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiClient.formatError(e)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartSummaryProvider);
    final addressesAsync = ref.watch(userAddressesProvider);
    final appliedCoupon = ref.watch(appliedCouponProvider);
    final couponDiscount = ref.watch(couponDiscountPaiseProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: cartAsync.when(
          data: (cart) {
            if (cart.items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('Your cart is empty', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Browse Restaurants'),
                    ),
                  ],
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
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // Delivery Address Section
                  Text(
                    'Delivery Address',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  addressesAsync.when(
                    data: (addresses) {
                      if (addresses.isNotEmpty) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                            boxShadow: AppColors.softShadow,
                          ),
                          child: Column(
                            children: addresses.map((addr) {
                              final isSel = _selectedAddressId == addr.id ||
                                  (_selectedAddressId == null && addr.isDefault);
                              return ListTile(
                                leading: Icon(
                                  isSel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                  color: isSel ? AppColors.primary : Colors.grey,
                                ),
                                title: Text(
                                  addr.label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSel ? AppColors.primary : (isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                                subtitle: Text('${addr.streetAddress}, ${addr.city} ${addr.pincode}'),
                                onTap: () {
                                  setState(() {
                                    _selectedAddressId = addr.id;
                                    _addressController.text = '${addr.streetAddress}, ${addr.city} ${addr.pincode}';
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: LinearProgressIndicator(
                        color: AppColors.primary,
                        backgroundColor: Colors.transparent,
                        minHeight: 2,
                      ),
                    ),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Could not load saved addresses (${ApiClient.formatError(err)})',
                              style: const TextStyle(fontSize: 12, color: AppColors.error),
                            ),
                          ),
                          TextButton(
                            onPressed: () => ref.invalidate(userAddressesProvider),
                            child: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLocating ? null : _useCurrentLocation,
                          icon: _isLocating
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                )
                              : const Icon(Icons.my_location_rounded, size: 16),
                          label: Text(_isLocating ? 'Locating...' : 'Use GPS', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickOnMap,
                          icon: const Icon(Icons.map_rounded, size: 16),
                          label: const Text('Pick on Map', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.secondary,
                            side: const BorderSide(color: AppColors.secondary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Full Delivery Address',
                      hintText: 'Building, Street, Landmark, City',
                      prefixIcon: const Icon(Icons.location_on_rounded, color: AppColors.primary),
                      filled: true,
                      fillColor: isDark ? AppColors.surfaceDark : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Offers & Coupon section in checkout
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(18),
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
                                        'Save more on your order',
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

                  const SizedBox(height: 20),

                  // Payment Method Section
                  Text(
                    'Payment Method',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: AppColors.softShadow,
                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            _selectedPayment == 'COD' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: AppColors.primary,
                          ),
                          title: const Text('Cash on Delivery (COD)', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Pay with cash or UPI on delivery'),
                          onTap: () => setState(() => _selectedPayment = 'COD'),
                        ),
                        Divider(height: 1, color: isDark ? AppColors.borderDark : AppColors.dividerLight),
                        ListTile(
                          leading: Icon(
                            _selectedPayment == 'ONLINE' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: AppColors.primary,
                          ),
                          title: const Text('UPI & Online Payment', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Google Pay, PhonePe, Cards & NetBanking'),
                          onTap: () => setState(() => _selectedPayment = 'ONLINE'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // First-Order Free Delivery Welcome Offer Banner
                  if (cart.isFirstOrderFreeDelivery) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.veg.withValues(alpha: 0.15),
                            AppColors.primary.withValues(alpha: 0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.veg.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.veg.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.celebration_rounded, color: AppColors.veg, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'First Order Free Delivery Applied! 🎉',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.veg),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₹0 delivery fee automatically applied to your checkout.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.veg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('FREE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Bill Breakdown
                  Text(
                    'Order Bill Breakdown',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: AppColors.softShadow,
                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    child: Column(
                      children: [
                        _buildRow('Item Subtotal (${cart.items.length} items)', CurrencyFormatter.formatPaise(subtotal), theme, isDark),
                        const SizedBox(height: 10),
                        if (cart.isFirstOrderFreeDelivery)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text('Delivery Fee', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.veg.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('1st Order Free', style: TextStyle(color: AppColors.veg, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  if (cart.originalDeliveryFeePaise > 0) ...[
                                    Text(
                                      CurrencyFormatter.formatPaise(cart.originalDeliveryFeePaise),
                                      style: const TextStyle(
                                        decoration: TextDecoration.lineThrough,
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  const Text(
                                    'FREE',
                                    style: TextStyle(color: AppColors.veg, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          _buildRow('Delivery Fee', CurrencyFormatter.formatPaise(deliveryFee), theme, isDark),
                        const SizedBox(height: 10),
                        _buildRow('Taxes & Charges (5% GST)', CurrencyFormatter.formatPaise(tax), theme, isDark),
                        if (discount > 0) ...[
                          const SizedBox(height: 10),
                          _buildRow('Coupon Discount (${appliedCoupon?.code ?? 'PROMO'})', '- ${CurrencyFormatter.formatPaise(discount)}', theme, isDark, isDiscount: true),
                        ],
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          child: Divider(height: 1, color: isDark ? AppColors.borderDark : AppColors.dividerLight),
                        ),
                        _buildRow('Total Amount', CurrencyFormatter.formatPaise(totalPayable), theme, isDark, isTotal: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Place Order Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _placeOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkAction,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : Text(
                              'Confirm & Place Order • ${CurrencyFormatter.formatPaise(totalPayable)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, stack) => CustomErrorView(
            message: 'Failed to load checkout: ${ApiClient.formatError(err)}',
            onRetry: () => ref.refresh(cartSummaryProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String val, ThemeData theme, bool isDark, {bool isTotal = false, bool isDiscount = false}) {
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
          val,
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
