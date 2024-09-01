import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';

class ImageTextOverlay extends StatefulWidget {
  final String imagePath;

  const ImageTextOverlay({super.key, required this.imagePath});

  @override
  ImageTextOverlayState createState() => ImageTextOverlayState();
}

class ImageTextOverlayState extends State<ImageTextOverlay> {
  String text = '';
  final TextEditingController _controller = TextEditingController();
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Text to Image'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveImage,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Screenshot(
              controller: _screenshotController,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(widget.imagePath), fit: BoxFit.contain),
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Enter text to add to the image',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  text = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveImage() async {
    final image = await _screenshotController.capture();
    if (image == null) return;

    final directory = await getTemporaryDirectory();
    final imagePath =
        '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.png';
    final File imageFile = File(imagePath);
    await imageFile.writeAsBytes(image);

    if (!mounted) return;
    Navigator.of(context).pop({
      'imagePath': imagePath,
      'text': text,
    });
  }
}
