import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notification_repository.dart';
import '../../restaurant/domain/models.dart';
import '../../auth/presentation/auth_providers.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(apiClientProvider)),
);

final notificationsListProvider = FutureProvider<List<NotificationModel>>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getNotifications();
});

final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getUnreadCount();
});

class NotificationActionNotifier extends StateNotifier<AsyncValue<void>> {
  final NotificationRepository _repo;
  final Ref _ref;

  NotificationActionNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<void> markAsRead(int id) async {
    try {
      await _repo.markAsRead(id);
      _ref.invalidate(notificationsListProvider);
      _ref.invalidate(unreadNotificationsCountProvider);
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await _repo.markAllAsRead();
      _ref.invalidate(notificationsListProvider);
      _ref.invalidate(unreadNotificationsCountProvider);
    } catch (_) {}
  }
}

final notificationActionNotifierProvider = StateNotifierProvider<NotificationActionNotifier, AsyncValue<void>>((ref) {
  return NotificationActionNotifier(ref.watch(notificationRepositoryProvider), ref);
});
