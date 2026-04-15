import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/config/supabase_config.dart';

class StorageService {
  final SupabaseClient _client = SupabaseConfig.client;
  final Uuid _uuid = const Uuid();

  // Upload Profile Image
  Future<String?> uploadProfileImage(dynamic image, String userId) async {
    try {
      final dynamic processedImage = await _processImage(image);
      final String fileExt = image.path.split('.').last;
      final String fileName = '${_uuid.v4()}.$fileExt';
      // Bucket: profile_images
      // Path: userId/filename
      final String filePath = '$userId/$fileName';

      if (kIsWeb) {
        await _client.storage.from('profile_images').uploadBinary(
          filePath,
          processedImage,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
      } else {
        await _client.storage.from('profile_images').upload(
          filePath,
          processedImage,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
      }

      return _client.storage.from('profile_images').getPublicUrl(filePath);
    } catch (e) {
      throw Exception('Error uploading profile image: $e');
    }
  }

  // Upload Food Image
  Future<String?> uploadFoodImage(dynamic image, String userId) async {
    try {
      final dynamic processedImage = await _processImage(image);
      final String fileExt = image.path.split('.').last;
      final String fileName = '${_uuid.v4()}.$fileExt';
      // Bucket: food_images
      // Path: userId/filename
      final String filePath = '$userId/$fileName';

      if (kIsWeb) {
        await _client.storage.from('food_images').uploadBinary(
          filePath,
          processedImage,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
      } else {
        await _client.storage.from('food_images').upload(
          filePath,
          processedImage,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
      }

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

  // Helper: Process/Compress Image
  Future<dynamic> _processImage(dynamic image) async {
    if (kIsWeb) {
      // On Web, we return the bytes for Supabase upload
      return await image.readAsBytes();
    }

    // On Mobile, we compress
    final tempDir = await getTemporaryDirectory();
    final path = tempDir.path;
    final String fileExt = image.path.split('.').last;
    final String fileName = '${_uuid.v4()}.$fileExt';
    final targetPath = '$path/$fileName';

    var result = await FlutterImageCompress.compressAndGetFile(
      image is File ? image.absolute.path : image.path,
      targetPath,
      quality: 70,
      minWidth: 1024,
      minHeight: 1024,
    );

    if (result == null) {
      return image is File ? image : File(image.path);
    }

    return File(result.path);
  }
}
