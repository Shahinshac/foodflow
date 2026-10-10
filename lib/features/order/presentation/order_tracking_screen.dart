import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'order_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/error_and_empty_views.dart';

class OrderTrackingScreen extends ConsumerWidget {
  final int orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  static const List<String> statusSteps = [
    'PLACED',
    'CONFIRMED',
    'PREPARING',
    'READY_FOR_PICKUP',
    'OUT_FOR_DELIVERY',
    'DELIVERED',
  ];

  void _advanceStatus(WidgetRef ref, String currentStatus) async {
    final currentIndex = statusSteps.indexOf(currentStatus);
    if (currentIndex < statusSteps.length - 1) {
      final nextStatus = statusSteps[currentIndex + 1];
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.put('/orders/$orderId/status', data: {'status': nextStatus});
      ref.invalidate(orderDetailProvider(orderId));
      ref.invalidate(userOrdersProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #$orderId'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(orderDetailProvider(orderId)),
        color: AppColors.primary,
        child: orderAsync.when(
        data: (order) {
          final currentStepIndex = statusSteps.indexOf(order.status);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              order.restaurant.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                order.status,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('Estimated Delivery: 30-40 mins'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Order Lifecycle Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Column(
                  children: List.generate(statusSteps.length, (index) {
                    final isCompleted = index <= currentStepIndex;
                    final isCurrent = index == currentStepIndex;
                    final stepName = statusSteps[index];

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Icon(
                              isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isCompleted
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey.shade400,
                            ),
                            if (index < statusSteps.length - 1)
                              Container(
                                width: 2,
                                height: 32,
                                color: isCompleted
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey.shade300,
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            stepName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              color: isCompleted ? Colors.black : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
                if (order.status != 'DELIVERED') ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.fast_forward_rounded),
                    label: const Text('Simulate Next Status Step (Demo)'),
                    onPressed: () => _advanceStatus(ref, order.status),
                  ),
                ],
                const Divider(height: 32),
                const Text(
                  'Items Ordered',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: order.items.length,
                  itemBuilder: (context, index) {
                    final item = order.items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${item.quantity}x ${item.foodItem.name}'),
                          Text(CurrencyFormatter.formatPaise(item.pricePaise * item.quantity)),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 24),
                _buildRow('Subtotal', CurrencyFormatter.formatPaise(order.subtotalPaise)),
                _buildRow('Delivery Fee', CurrencyFormatter.formatPaise(order.deliveryFeePaise)),
                _buildRow('Tax (5% GST)', CurrencyFormatter.formatPaise(order.taxPaise)),
                const Divider(),
                _buildRow('Total Amount', CurrencyFormatter.formatPaise(order.totalPaise),
                    isTotal: true),
                const SizedBox(height: 16),
                Text('Delivery Address:\n${order.deliveryAddress}',
                    style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),
          );
        },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, stack) => CustomErrorView(
            message: 'Failed to track order: ${ApiClient.formatError(err)}',
            onRetry: () => ref.refresh(orderDetailProvider(orderId)),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String val, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(val,
              style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
