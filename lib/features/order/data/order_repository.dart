import '../../../core/network/api_client.dart';
import '../../restaurant/domain/models.dart';

class OrderRepository {
  final ApiClient apiClient;

  OrderRepository(this.apiClient);

  Future<OrderModel> createOrder({
    required String deliveryAddress,
    required String paymentMethod,
    String? couponCode,
    double? deliveryLat,
    double? deliveryLng,
  }) async {
    final response = await apiClient.dio.post(
      '/orders',
      data: {
        'delivery_address': deliveryAddress,
        'payment_method': paymentMethod,
        if (couponCode != null && couponCode.isNotEmpty) 'coupon_code': couponCode,
        if (deliveryLat != null) 'delivery_lat': deliveryLat,
        if (deliveryLng != null) 'delivery_lng': deliveryLng,
      },
    );
    return OrderModel.fromJson(response.data);
  }

  Future<List<OrderModel>> getUserOrders() async {
    final response = await apiClient.dio.get('/orders');
    return (response.data as List).map((e) => OrderModel.fromJson(e)).toList();
  }

  Future<OrderModel> getOrderDetail(int orderId) async {
    final response = await apiClient.dio.get('/orders/$orderId');
    return OrderModel.fromJson(response.data);
  }

  Future<ReorderResultModel> reorder(int orderId) async {
    final response = await apiClient.dio.post('/orders/$orderId/reorder');
    return ReorderResultModel.fromJson(response.data);
  }

  Future<OrderModel> cancelOrder(int orderId, String reason) async {
    final response = await apiClient.dio.post(
      '/orders/$orderId/cancel',
      data: {'reason': reason},
    );
    return OrderModel.fromJson(response.data);
  }
}
