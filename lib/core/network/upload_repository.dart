import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'api_client.dart';

class UploadRepository {
  final ApiClient apiClient;

  UploadRepository(this.apiClient);

  Future<String> uploadImage(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final filename = file.name.isNotEmpty ? file.name : 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
        ),
      });

      final response = await apiClient.dio.post(
        '/uploads/image',
        data: formData,
      );

      final url = response.data['url'] as String;
      return url;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }
}
