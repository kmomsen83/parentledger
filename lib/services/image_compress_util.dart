import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Compress large camera/gallery images before Firebase upload.
abstract final class ImageCompressUtil {
  static const int _maxSide = 1600;
  static const int _quality = 82;

  /// Returns a JPEG path (may be the original if compression fails).
  static Future<File> compressToJpeg(File source) async {
    try {
      final dir = await getTemporaryDirectory();
      final name = source.path.split(Platform.pathSeparator).last;
      final dot = name.lastIndexOf('.');
      final base = dot > 0 ? name.substring(0, dot) : name;
      final targetPath =
          '${dir.path}/pl_upload_${base}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final out = await FlutterImageCompress.compressAndGetFile(
        source.absolute.path,
        targetPath,
        quality: _quality,
        minWidth: _maxSide,
        minHeight: _maxSide,
        format: CompressFormat.jpeg,
      );

      if (out == null) return source;
      final f = File(out.path);
      if (!await f.exists()) return source;
      return f;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
            '[ImageCompressUtil] compress failed, using source: $e\n$st');
      }
      return source;
    }
  }
}
