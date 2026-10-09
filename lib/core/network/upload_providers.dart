import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/auth_providers.dart';
import 'upload_repository.dart';

final uploadRepositoryProvider = Provider<UploadRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return UploadRepository(apiClient);
});
