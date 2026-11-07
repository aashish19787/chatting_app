import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../core/constants/app_config.dart';

/// Uploads images to Cloudinary and returns the image link.
class StorageService {
  static const _cloudName = AppConfig.cloudinaryCloudName;
  static const _uploadPreset = AppConfig.cloudinaryUploadPreset;

  Future<String> uploadChatImage(XFile file) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );

    final bytes = await file.readAsBytes();

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = AppConfig.cloudinaryFolder
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: file.name.isEmpty ? 'image.jpg' : file.name,
        ),
      );

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      // Cloudinary explains the problem in the body.
      throw Exception('Upload failed: $body');
    }

    return jsonDecode(body)['secure_url'] as String;
  }
}
