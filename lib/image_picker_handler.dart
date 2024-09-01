import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'image_text_overlay.dart';

class ImagePickerHandler {
  Future<Map<String, dynamic>?> pickAndEditImage(BuildContext context) async {
    // Pick image
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return null;

    // Crop image
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 100,
      maxWidth: 1080,
      maxHeight: 1080,
      // Remove the cropStyle parameter
    );

    if (croppedFile == null) return null;

    // Add text
    if (!context.mounted) return null;
    final result = await _navigateToImageTextOverlay(context, croppedFile.path);

    if (result == null) return null;

    // Save the image with text overlay
    final directory = await getApplicationDocumentsDirectory();
    final String path =
        '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.png';
    await File(result['imagePath']).copy(path);

    // Return the processed image data
    return {
      'type': 'image',
      'content': path,
      'text': result['text'],
    };
  }

  Future<Map<String, dynamic>?> _navigateToImageTextOverlay(
      BuildContext context, String imagePath) async {
    if (!context.mounted) return null;
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageTextOverlay(imagePath: imagePath),
      ),
    );
  }
}
