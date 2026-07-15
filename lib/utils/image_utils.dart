import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class ImageUtils {
  static const int maxWidth = 400;
  static const int maxHeight = 400;
  static const int quality = 85;

  /// Pick image from gallery or camera and compress it
  static Future<String?> pickAndCompressImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile == null) return null;

    final file = File(pickedFile.path);
    final bytes = await file.readAsBytes();

    // Decode image
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return null;

    // Resize if too large
    if (image.width > maxWidth || image.height > maxHeight) {
      image = img.copyResize(
        image,
        width: image.width > image.height ? maxWidth : null,
        height: image.height >= image.width ? maxHeight : null,
      );
    }

    // Encode to JPEG with quality
    final compressedBytes = img.encodeJpg(image, quality: quality);

    // Convert to base64
    return base64Encode(compressedBytes);
  }

  /// Convert base64 string to Image widget
  static Widget base64ToImage(
      String? base64String, {
        double? width,
        double? height,
        BoxFit fit = BoxFit.cover,
        Widget? placeholder,
      }) {
    if (base64String == null || base64String.isEmpty) {
      return placeholder ??
          Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Icon(Icons.person, color: Colors.grey),
          );
    }

    try {
      final bytes = base64Decode(base64String);
      return Image.memory(
        Uint8List.fromList(bytes),
        width: width,
        height: height,
        fit: fit,
      );
    } catch (e) {
      return placeholder ??
          Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Icon(Icons.error, color: Colors.red),
          );
    }
  }

  /// Get memory size of base64 string in KB
  static double getSizeInKB(String base64String) {
    final bytes = base64Decode(base64String);
    return bytes.length / 1024;
  }
}