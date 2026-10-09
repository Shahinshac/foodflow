import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/order_repository.dart';
import '../../restaurant/domain/models.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../cart/presentation/cart_providers.dart';

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(ref.watch(apiClientProvider)),
);

final userOrdersProvider = FutureProvider<List<OrderModel>>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  return repo.getUserOrders();
});

final orderDetailProvider = FutureProvider.family<OrderModel, int>((ref, orderId) async {
  final repo = ref.watch(orderRepositoryProvider);
  return repo.getOrderDetail(orderId);
});

class OrderActionNotifier extends StateNotifier<AsyncValue<void>> {
  final OrderRepository _repo;
  final Ref _ref;

  OrderActionNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<ReorderResultModel?> reorder(int orderId) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.reorder(orderId);
      _ref.invalidate(cartSummaryProvider);
      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> cancelOrder(int orderId, String reason) async {
    state = const AsyncValue.loading();
    try {
      await _repo.cancelOrder(orderId, reason);
      _ref.invalidate(userOrdersProvider);
      _ref.invalidate(orderDetailProvider(orderId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final orderActionNotifierProvider = StateNotifierProvider<OrderActionNotifier, AsyncValue<void>>((ref) {
  return OrderActionNotifier(ref.watch(orderRepositoryProvider), ref);
});
