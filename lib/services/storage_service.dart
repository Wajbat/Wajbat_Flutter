import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/config/supabase_config.dart';

class StorageService {
  final SupabaseClient _client = SupabaseConfig.client;
  final Uuid _uuid = const Uuid();

  // Upload Profile Image
  Future<String?> uploadProfileImage(File image, String userId) async {
    try {
      final File compressedImage = await _compressImage(image);
      final String fileExt = image.path.split('.').last;
      final String fileName = '${_uuid.v4()}.$fileExt';
      // Bucket: profile_images
      // Path: userId/filename
      final String filePath = '$userId/$fileName';

      await _client.storage.from('profile_images').upload(
        filePath,
        compressedImage,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );

      return _client.storage.from('profile_images').getPublicUrl(filePath);
    } catch (e) {
      throw Exception('Error uploading profile image: $e');
    }
  }

  // Upload Food Image
  Future<String?> uploadFoodImage(File image, String userId) async {
    try {
      final File compressedImage = await _compressImage(image);
      final String fileExt = image.path.split('.').last;
      final String fileName = '${_uuid.v4()}.$fileExt';
      // Bucket: food_images
      // Path: userId/filename
      final String filePath = '$userId/$fileName';

      await _client.storage.from('food_images').upload(
        filePath,
        compressedImage,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );

      return _client.storage.from('food_images').getPublicUrl(filePath);
    } catch (e) {
      throw Exception('Error uploading food image: $e');
    }
  }

  // Delete Image
  Future<void> deleteImage(String imageUrl) async {
    try {
      // Extract file path from URL
      String path;
      String bucket;
      
      if (imageUrl.contains('/profile_images/')) {
        bucket = 'profile_images';
        path = imageUrl.split('/profile_images/').last;
      } else if (imageUrl.contains('/food_images/')) {
        bucket = 'food_images';
        path = imageUrl.split('/food_images/').last;
      } else {
        return; // Unknown bucket
      }

      await _client.storage.from(bucket).remove([path]);
    } catch (e) {
      throw Exception('Error deleting image: $e');
    }
  }

  // Helper: Compress Image
  Future<File> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final path = tempDir.path;
    final String fileExt = file.path.split('.').last;
    final String fileName = '${_uuid.v4()}.$fileExt';
    final targetPath = '$path/$fileName';

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70, // Adjust quality as needed
      minWidth: 1024,
      minHeight: 1024,
    );

    if (result == null) {
      return file; // Return original if compression fails
    }

    // Returning File object from XFile
    return File(result.path);
  }
}
