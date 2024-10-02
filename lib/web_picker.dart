import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebViewScreenshotPage extends StatefulWidget {
  @override
  _WebViewScreenshotPageState createState() => _WebViewScreenshotPageState();
}

class _WebViewScreenshotPageState extends State<WebViewScreenshotPage> {
  bool isSelecting = false;
  Rect? selectionRect;
  InAppWebViewController? _webViewController;
  GlobalKey _webViewKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Get screen size
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      // No AppBar as per requirements
      body: Column(
        children: [
          // Top 20% container
          Container(
            height: screenSize.height * 0.2,
            color: Colors.blueGrey,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // currently greyed out and does nothing
                    setState(() {
                      isSelecting = true;
                    });
                  },
                  child: Text('Screenshot'),
                ),
                // Add other widgets here if needed
              ],
            ),
          ),
          // Bottom 80% WebView
          Expanded(
            child: Stack(
              children: [
                // InAppWebView allows capturing screenshots
                InAppWebView(
                  key: _webViewKey,
                  initialUrlRequest:
                      URLRequest(url: WebUri('https://www.google.com/images')),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                  },
                  // Disable gestures when selecting
                  gestureRecognizers: isSelecting ? {} : null,
                ),
                // Selection overlay
                if (isSelecting)
                  GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        selectionRect = Rect.fromLTWH(
                          details.localPosition.dx,
                          details.localPosition.dy,
                          0,
                          0,
                        );
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        selectionRect = selectionRect != null
                            ? Rect.fromLTWH(
                                selectionRect!.left,
                                selectionRect!.top,
                                details.localPosition.dx - selectionRect!.left,
                                details.localPosition.dy - selectionRect!.top,
                              )
                            : Rect.fromPoints(
                                Offset.zero, details.localPosition);
                      });
                    },
                    onPanEnd: (details) async {
                      // Capture the selected area
                      await _captureSelectedArea();
                      setState(() {
                        isSelecting = false;
                        selectionRect = null;
                      });
                    },
                    child: Stack(
                      children: [
                        if (selectionRect != null)
                          CustomPaint(
                            size: Size.infinite,
                            painter: SelectionPainter(rect: selectionRect!),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureSelectedArea() async {
    if (selectionRect == null || selectionRect!.isEmpty) {
      print('No valid selection made');
      return;
    }
    if (_webViewController == null) {
      print('Web view controller not initialized');
      return;
    }
    try {
      // Capture screenshot using webViewController
      var screenshotData = await _webViewController!.takeScreenshot();
      if (screenshotData == null) {
        print('Failed to capture screenshot');
        return;
      }
      Uint8List screenshotBytes = screenshotData.buffer.asUint8List();

      // Now, crop the screenshot to the selected area
      // Decode the image from the bytes
      ui.Codec codec = await ui.instantiateImageCodec(screenshotBytes);
      ui.FrameInfo frame = await codec.getNextFrame();
      ui.Image fullImage = frame.image;

      // Adjust selectionRect with pixel ratio
      double pixelRatio = MediaQuery.of(context).devicePixelRatio;
      Rect adjustedRect = Rect.fromLTWH(
        selectionRect!.left * pixelRatio,
        selectionRect!.top * pixelRatio,
        selectionRect!.width * pixelRatio,
        selectionRect!.height * pixelRatio,
      );

      // Crop the image
      ui.PictureRecorder recorder = ui.PictureRecorder();
      Canvas canvas = Canvas(recorder);

      // Draw the selected area onto the canvas
      Paint paint = Paint();
      canvas.drawImageRect(fullImage, adjustedRect,
          Rect.fromLTWH(0, 0, adjustedRect.width, adjustedRect.height), paint);

      ui.Image croppedImage = await recorder
          .endRecording()
          .toImage(adjustedRect.width.floor(), adjustedRect.height.floor());

      // Convert the cropped image to bytes
      ByteData? croppedByteData =
          await croppedImage.toByteData(format: ui.ImageByteFormat.png);
      Uint8List croppedPngBytes = croppedByteData!.buffer.asUint8List();

      // Now, you can save croppedPngBytes as an image file or use it as needed
      Navigator.of(context).pop(croppedPngBytes);
    } catch (e) {
      print('Error capturing screenshot: $e');
    }
  }
}

class SelectionPainter extends CustomPainter {
  final Rect? rect;

  SelectionPainter({this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    if (rect != null) {
      // Semi-transparent overlay
      Paint paint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromPoints(rect!.topLeft, rect!.bottomRight), paint);

      // White border around the selection
      Paint borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(
          Rect.fromPoints(rect!.topLeft, rect!.bottomRight), borderPaint);
    }
  }

  @override
  bool shouldRepaint(SelectionPainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}
