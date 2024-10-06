//import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:image/image.dart' as img;

// ... existing imports ...

class WebViewScreenshotPage extends StatefulWidget {
  const WebViewScreenshotPage({super.key});
  @override
  WebViewScreenshotPageState createState() => WebViewScreenshotPageState();
}

class WebViewScreenshotPageState extends State<WebViewScreenshotPage> {
  InAppWebViewController? _webViewController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: ElevatedButton(
          onPressed: _captureAndReturnScreenshot,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            textStyle: const TextStyle(fontSize: 16),
            foregroundColor: Colors.white,
            backgroundColor: Colors.black,
          ),
          child: const Text('Capture Image'),
        ),
        backgroundColor: Colors.blueGrey,
        elevation: 0,
        toolbarHeight: 56, // Default AppBar height
        centerTitle: true,
      ),
      body: InAppWebView(
        initialUrlRequest:
            URLRequest(url: WebUri('https://www.google.com/images')),
        onWebViewCreated: (controller) {
          _webViewController = controller;
        },
      ),
    );
  }

  Future<void> _captureAndReturnScreenshot() async {
    if (_webViewController == null) {
      print('Web view controller not initialized');
      return;
    }
    try {
      var screenshotData = await _webViewController!.takeScreenshot();
      if (screenshotData == null) {
        print('Failed to capture screenshot');
        return;
      }

      // Convert Uint8List to PNG
      final image = img.decodeImage(screenshotData);
      if (image == null) {
        print('Failed to decode image');
        return;
      }

      final pngBytes = img.encodePng(image);
      print(
          'Screenshot captured and converted to PNG. Size: ${pngBytes.length} bytes');

      if (mounted) {
        Navigator.of(context).pop(pngBytes);
      }
    } catch (e) {
      print('Error capturing or converting screenshot: $e');
    }
  }
}
