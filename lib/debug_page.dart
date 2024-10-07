import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'web_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

class DebugPage extends StatefulWidget {
  @override
  _DebugPageState createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  Uint8List? _capturedImage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Debug Page'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _openWebPicker,
              child: Text('Open Web Picker'),
            ),
            SizedBox(height: 20),
            if (_capturedImage != null)
              Image.memory(
                _capturedImage!,
                width: 300,
                height: 300,
                fit: BoxFit.contain,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWebPicker() async {
    print('Before WebPicker, mounted: $mounted');
    final image = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(builder: (context) => WebViewScreenshotPage()),
    );
    print('After WebPicker, mounted: $mounted');
    if (image == null) return;

    final Directory tempDir = await getTemporaryDirectory();
    final String tempPath = '${tempDir.path}/${Uuid().v4()}.png';
    final File tempFile = File(tempPath);
    await tempFile.writeAsBytes(image);

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: tempPath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: const Color.fromARGB(255, 62, 49, 34),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Image',
        ),
      ],
      compressQuality: 70,
      maxWidth: 1000,
      maxHeight: 1000,
    );
    print('After ImageCropper, mounted: $mounted');
    if (croppedFile == null) return;
    final Uint8List croppedBytes = await croppedFile.readAsBytes();

    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    setState(() {
      _capturedImage = croppedBytes;
    });
  }
}
