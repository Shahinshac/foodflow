import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'api_client.dart';

class UploadRepository {
  final ApiClient apiClient;

  UploadRepository(this.apiClient);

  Future<String> uploadImage(XFile file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.name,
        ),
      });

      final response = await apiClient.dio.post(
        '/uploads/image',
        data: formData,
      );

      return response.data['url'];
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }
}
