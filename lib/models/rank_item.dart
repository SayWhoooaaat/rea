import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class RankItem {
  final String id;
  String content; // This is the name
  String? imagePath;
  String? tier;

  RankItem({
    required this.content,
    this.imagePath,
    this.tier,
    String? id,
  }) : id = id ?? const Uuid().v4();

  // Factory constructor to create a RankItem from JSON
  factory RankItem.fromJson(Map<String, dynamic> json) {
    return RankItem(
      content: json['content'],
      imagePath: json['imagePath'],
      tier: json['tier'],
      id: json['id'],
    );
  }

  // Convert a RankItem to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'imagePath': imagePath,
      'tier': tier,
    };
  }

  // Method to handle image importing and processing
  Future<void> importImage(String path) async {
    // TODO: Implement image importing, cropping, and downscaling
    imagePath = path;
  }

  // Widget to display the item
  Widget buildWidget(double size) {
    if (imagePath != null) {
      return Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: FileImage(File(imagePath!)),
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    } else {
      return Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            content,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
  }

  Future<void> pickAndSetImage(ImageSource source) async {
    try {
      print('pickAndSetImage');
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);

      if (image != null) {
        await _cropAndProcessImage(image.path);
      }
    } catch (e, stackTrace) {
      print('Error picking image: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to pick image: $e');
    }
  }

  Future<void> _cropAndProcessImage(String imagePath) async {
    try {
      print('cropAndProcessImage');
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imagePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Colors.deepOrange,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Image',
          ),
        ],
        compressQuality: 70, // Add this line
        maxWidth: 1000, // Add this line
        maxHeight: 1000, // Add this line
      );

      if (croppedFile != null) {
        await _processAndSaveImage(croppedFile.path);
      }
    } catch (e, stackTrace) {
      print('Error cropping image: $e');
      print('Stack trace: $stackTrace');
      // Add more detailed error logging
      if (e is Exception) {
        print('Exception details: ${e.toString()}');
      }
      throw Exception('Failed to crop image: $e');
    }
  }

  Future<void> _processAndSaveImage(String imagePath) async {
    try {
      print('processAndSaveImage');
      final File imageFile = File(imagePath);
      final img.Image? image = img.decodeImage(await imageFile.readAsBytes());

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      final img.Image resizedImage =
          img.copyResize(image, width: 800, height: 800);

      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
      final String filePath = '${appDir.path}/$fileName';

      final File newImage = File(filePath);
      await newImage.writeAsBytes(img.encodePng(resizedImage));

      this.imagePath = filePath;
    } catch (e, stackTrace) {
      print('Error processing and saving image: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to process and save image: $e');
    }
  }
}
