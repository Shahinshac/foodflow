import '../../../core/network/api_client.dart';
import '../../restaurant/domain/models.dart';

class CartRepository {
  final ApiClient apiClient;

  CartRepository(this.apiClient);

  Future<CartSummaryModel> getCart() async {
    final response = await apiClient.dio.get('/cart');
    return CartSummaryModel.fromJson(response.data);
  }

  Future<void> addToCart(int foodItemId, {int quantity = 1, String? specialInstructions}) async {
    await apiClient.dio.post(
      '/cart/items',
      data: {
        'food_item_id': foodItemId,
        'quantity': quantity,
        'special_instructions': specialInstructions,
      },
    );
  }

  Future<void> updateQuantity(int cartItemId, int quantity) async {
    await apiClient.dio.put(
      '/cart/items/$cartItemId',
      data: {'quantity': quantity},
    );
  }

  Future<void> removeFromCart(int cartItemId) async {
    await apiClient.dio.delete('/cart/items/$cartItemId');
  }

  Future<void> clearCart() async {
    await apiClient.dio.delete('/cart/clear');
  }

  // Promotion Engine API
  Future<CouponValidationResult> validateCoupon({
    required String code,
    int? restaurantId,
    required int subtotalPaise,
    int deliveryFeePaise = 3000,
  }) async {
    final response = await apiClient.dio.post(
      '/coupons/validate',
      data: {
        'code': code,
        'restaurant_id': restaurantId,
        'subtotal_paise': subtotalPaise,
        'delivery_fee_paise': deliveryFeePaise,
      },
    );
    return CouponValidationResult.fromJson(response.data);
  }

  Future<List<CouponModel>> getAvailableCoupons({int? restaurantId}) async {
    final response = await apiClient.dio.get(
      '/coupons/available',
      queryParameters: {
        'restaurant_id': ?restaurantId,
      },
    );
    return (response.data as List)
        .map((e) => CouponModel.fromJson(e))
        .toList();
  }
}
