import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/cart_repository.dart';
import '../../restaurant/domain/models.dart';
import '../../auth/presentation/auth_providers.dart';

final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => CartRepository(ref.watch(apiClientProvider)),
);

final cartSummaryProvider = FutureProvider<CartSummaryModel>((ref) async {
  final repo = ref.watch(cartRepositoryProvider);
  return repo.getCart();
});

// Applied coupon provider
final appliedCouponProvider = StateProvider<CouponModel?>((ref) => null);
final couponDiscountPaiseProvider = StateProvider<int>((ref) => 0);

final availableCouponsProvider = FutureProvider.family<List<CouponModel>, int?>((ref, restaurantId) async {
  final repo = ref.watch(cartRepositoryProvider);
  return repo.getAvailableCoupons(restaurantId: restaurantId);
});

class CartNotifier extends StateNotifier<AsyncValue<void>> {
  final CartRepository _repository;
  final Ref _ref;

  CartNotifier(this._repository, this._ref) : super(const AsyncValue.data(null));

  Future<void> addToCart(int foodItemId, {int quantity = 1, String? instructions}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.addToCart(foodItemId, quantity: quantity, specialInstructions: instructions);
      _ref.invalidate(cartSummaryProvider);
    });
  }

  Future<void> updateQuantity(int cartItemId, int quantity) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      if (quantity <= 0) {
        await _repository.removeFromCart(cartItemId);
      } else {
        await _repository.updateQuantity(cartItemId, quantity);
      }
      _ref.invalidate(cartSummaryProvider);
      // Re-validate coupon if any is applied
      _revalidateAppliedCoupon();
    });
  }

  Future<void> removeFromCart(int cartItemId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.removeFromCart(cartItemId);
      _ref.invalidate(cartSummaryProvider);
      _revalidateAppliedCoupon();
    });
  }

  Future<void> clearCart() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.clearCart();
      _ref.read(appliedCouponProvider.notifier).state = null;
      _ref.read(couponDiscountPaiseProvider.notifier).state = 0;
      _ref.invalidate(cartSummaryProvider);
    });
  }

  Future<CouponValidationResult> applyCoupon(String code, {int? restaurantId, required int subtotalPaise, int deliveryFeePaise = 3000}) async {
    try {
      final result = await _repository.validateCoupon(
        code: code,
        restaurantId: restaurantId,
        subtotalPaise: subtotalPaise,
        deliveryFeePaise: deliveryFeePaise,
      );

      if (result.valid && result.coupon != null) {
        _ref.read(appliedCouponProvider.notifier).state = result.coupon;
        _ref.read(couponDiscountPaiseProvider.notifier).state = result.discountPaise;
      }
      return result;
    } catch (e) {
      return CouponValidationResult(
        valid: false,
        discountPaise: 0,
        message: 'Unable to validate coupon at this moment',
      );
    }
  }

  void removeCoupon() {
    _ref.read(appliedCouponProvider.notifier).state = null;
    _ref.read(couponDiscountPaiseProvider.notifier).state = 0;
  }

  void _revalidateAppliedCoupon() async {
    final coupon = _ref.read(appliedCouponProvider);
    if (coupon == null) return;

    try {
      final cart = await _repository.getCart();
      if (cart.items.isEmpty) {
        removeCoupon();
        return;
      }

      final result = await _repository.validateCoupon(
        code: coupon.code,
        restaurantId: cart.restaurant?.id,
        subtotalPaise: cart.subtotalPaise,
        deliveryFeePaise: cart.deliveryFeePaise,
      );

      if (result.valid) {
        _ref.read(couponDiscountPaiseProvider.notifier).state = result.discountPaise;
      } else {
        removeCoupon();
      }
    } catch (_) {
      removeCoupon();
    }
  }
}

final cartNotifierProvider = StateNotifierProvider<CartNotifier, AsyncValue<void>>((ref) {
  return CartNotifier(ref.watch(cartRepositoryProvider), ref);
});
