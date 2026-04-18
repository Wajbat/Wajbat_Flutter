import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageService {
  /// Returns a path or URL string suitable for the image cropper.
  /// On mobile, copies the asset to a temporary file.
  /// On web, returns the asset path directly to avoid [MissingPluginException].
  static Future<String> getSampleImagePath(String assetPath) async {
    if (kIsWeb) {
      // In Flutter Web, assets are served relative to the root index.html.
      // Usually, 'assets/images/food1.png' is the correct URL for the browser.
      return assetPath;
    }

    try {
      final ByteData data = await rootBundle.load(assetPath);
      final List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      final String tempDir = (await getTemporaryDirectory()).path;
      final String fileName = p.basename(assetPath);
      final File file = File(p.join(tempDir, fileName));

      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e) {
      throw Exception('Failed to copy asset to temp: $e');
    }
  }
}
