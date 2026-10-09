import '../../../core/network/api_client.dart';
import '../../restaurant/domain/models.dart';

class NotificationRepository {
  final ApiClient apiClient;

  NotificationRepository(this.apiClient);

  Future<List<NotificationModel>> getNotifications() async {
    final response = await apiClient.dio.get('/notifications');
    return (response.data as List)
        .map((e) => NotificationModel.fromJson(e))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final response = await apiClient.dio.get('/notifications/unread-count');
    return response.data['unread_count'] ?? 0;
  }

  Future<void> markAsRead(int id) async {
    await apiClient.dio.put('/notifications/$id/read');
  }

  Future<void> markAllAsRead() async {
    await apiClient.dio.put('/notifications/read-all');
  }
}
