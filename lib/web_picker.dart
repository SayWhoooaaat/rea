//import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:image/image.dart' as img;

// ... existing imports ...

class WebViewScreenshotPage extends StatefulWidget {
  @override
  _WebViewScreenshotPageState createState() => _WebViewScreenshotPageState();
}

class _WebViewScreenshotPageState extends State<WebViewScreenshotPage> {
  InAppWebViewController? _webViewController;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Column(
        children: [
          Container(
            height: screenSize.height * 0.2,
            color: Colors.blueGrey,
            child: Center(
              child: ElevatedButton(
                onPressed: _captureAndReturnScreenshot,
                child: Text('Screenshot'),
              ),
            ),
          ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest:
                  URLRequest(url: WebUri('https://www.google.com/images')),
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
            ),
          ),
        ],
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

      Navigator.of(context).pop(pngBytes);
    } catch (e) {
      print('Error capturing or converting screenshot: $e');
    }
  }
}
