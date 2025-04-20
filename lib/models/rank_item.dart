import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:rea/web_picker.dart';
import 'package:device_info_plus/device_info_plus.dart';

class RankItem extends ChangeNotifier {
  final GlobalKey key = GlobalKey();
  final String id;
  String content;
  ValueNotifier<String?> imagePathNotifier;
  int? tierId; // ← was String? tier
  String? tier;
  int? intertier;
  final Function({bool forceRebuild}) onUpdate;

  RankItem({
    required this.content,
    String? imagePath,
    this.tierId,
    this.tier,
    this.intertier,
    String? id,
    required this.onUpdate,
  })  : id = id ?? const Uuid().v4(),
        imagePathNotifier = ValueNotifier(imagePath);

  String? get imagePath => imagePathNotifier.value;

  set imagePath(String? value) {
    print('Setter called with value: $value');
    if (imagePathNotifier.value != value) {
      imagePathNotifier.value = value;
      notifyListeners();
      onUpdate();
    } else {
      print('imagePath unchanged');
    }
  }

  void _notifyUpdate({bool forceRebuild = false}) {
    onUpdate(forceRebuild: forceRebuild);
    notifyListeners();
  }

  // Factory constructor to create a RankItem from JSON
  factory RankItem.fromJson(Map<String, dynamic> json,
      {required Function({bool forceRebuild}) onUpdate}) {
    int? id = json['tierId']; // new field (may be null)

    if (id == null && json['tier'] != null) {
      // <- old file?
      const Map<String, int> map = {
        // default 1‑based order
        'S': 1, 'A': 2, 'B': 3, 'C': 4,
        'D': 5, 'E': 6, 'F': 7,
      };
      id = map[json['tier']]; // null if label unknown
    }
    return RankItem(
      content: json['content'],
      imagePath: json['imagePath'],
      tierId: id,
      tier: json['tier'],
      intertier: json['intertier'],
      id: json['id'],
      onUpdate: onUpdate,
    );
  }

  // Convert a RankItem to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'imagePath': imagePath,
      'tierId': tierId,
      'tier': tier,
      'intertier': intertier,
    };
  }

  // Widget to display the item
  Widget buildWidget(double size) {
    return ValueListenableBuilder<String?>(
      valueListenable: imagePathNotifier,
      builder: (context, imagePath, child) {
        print('Building widget with imagePath: $imagePath');
        return Container(
          key: ValueKey('$id-$imagePath'),
          width: size,
          height: size,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(4),
            image: imagePath != null
                ? DecorationImage(
                    image: FileImage(File(imagePath)),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: Stack(
            children: [
              if (imagePath == null)
                Center(
                  child: Text(
                    content,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (imagePath != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 1, horizontal: 1),
                    child: Center(
                      child: Stack(
                        children: [
                          // Outline
                          Text(
                            content,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 3
                                ..color = Colors.black,
                            ),
                          ),
                          // Fill
                          Text(
                            content,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _requestPermission(Permission permission) async {
    if (kIsWeb) return true; // Permissions are handled differently on web

    if (await permission.isGranted) {
      return true;
    } else {
      var result = await permission.request();
      if (result.isPermanentlyDenied) {
        // Open app settings if permission is permanently denied
        await openAppSettings();
      }
      return result.isGranted;
    }
  }

  Future<bool> pickAndSetImage(ImageSource source) async {
    try {
      print('pickAndSetImage');
      bool hasPermission = true;

      if (!kIsWeb) {
        if (source == ImageSource.gallery) {
          if (Platform.isAndroid) {
            // Get Android SDK version using device_info_plus
            final deviceInfo = DeviceInfoPlugin();
            final androidInfo = await deviceInfo.androidInfo;
            final sdkInt = androidInfo.version.sdkInt;

            if (sdkInt >= 33) {
              // Android 13+ (API 33+)
              hasPermission = await _requestPermission(Permission.photos);
            } else {
              // Android 12 and below
              hasPermission = await _requestPermission(Permission.storage);
            }
          } else {
            hasPermission = await _requestPermission(Permission.photos);
          }
        } else {
          hasPermission = await _requestPermission(Permission.camera);
        }
      }

      if (hasPermission) {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(source: source);

        if (image != null) {
          final bool cropSuccess = await _cropAndProcessImage(image.path);
          if (cropSuccess) {
            notifyListeners();
            imagePathNotifier.notifyListeners();
            print('Image updated, notified listeners');
            return true;
          }
        }
        print('No image selected or cropping cancelled');
        return false;
      } else {
        print('Permission not granted');
        throw Exception('Permission not granted');
      }
    } catch (e, stackTrace) {
      print('Error picking image: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to pick image: $e');
    }
  }

  Future<bool> _cropAndProcessImage(String imagePath) async {
    try {
      print('cropAndProcessImage');
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imagePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: const Color.fromARGB(255, 51, 45, 38),
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

      if (croppedFile != null) {
        await _processAndSaveImage(croppedFile.path);
        return true;
      }
      return false;
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
      // Delete the old image file if it exists
      if (imagePathNotifier.value != null) {
        File oldFile = File(imagePathNotifier.value!);
        if (await oldFile.exists()) {
          await oldFile.delete();
          print('Deleted old image file: ${imagePathNotifier.value}');
        }
      }

      final File imageFile = File(imagePath);
      final img.Image? image = img.decodeImage(await imageFile.readAsBytes());

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      final img.Image resizedImage =
          img.copyResize(image, width: 800, height: 800);

      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName =
          '${id}_${DateTime.now().millisecondsSinceEpoch}.png';
      final String filePath = '${appDir.path}/$fileName';

      final File newImage = File(filePath);
      await newImage.writeAsBytes(img.encodePng(resizedImage));
      print('Wrote new image to $filePath');

      // Use the setter to update the imagePath
      this.imagePath = filePath;
      print('Set new imagePath to $filePath');
    } catch (e, stackTrace) {
      print('Error processing and saving image: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to process and save image: $e');
    }
  }

  Future<void> deleteAssociatedFiles() async {
    if (imagePath != null) {
      try {
        final File imageFile = File(imagePath!);
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      } catch (e) {
        print('Error deleting image file: $e');
      }
    }
  }

  void rename(String newName) {
    content = newName;
    notifyListeners();
    _notifyUpdate();
  }

  Future<void> showImageSourceDialog(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Web Image Search'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final Uint8List? imageBytes = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => WebViewScreenshotPage()),
                    );
                    if (imageBytes != null) {
                      await saveWebImage(imageBytes);
                    }
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Device'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await pickAndSetImage(ImageSource.gallery);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Open Camera'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await pickAndSetImage(ImageSource.camera);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> saveWebImage(Uint8List imageBytes) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = '${tempDir.path}/${Uuid().v4()}.png';
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(imageBytes);

      print('Temporary file saved at: $tempPath');
      print('File size: ${await tempFile.length()} bytes');

      // Verify the image data
      final Uint8List savedBytes = await tempFile.readAsBytes();
      print('Saved image byte length: ${savedBytes.length}');
      print('First few bytes: ${savedBytes.take(10)}');

      final bool cropSuccess = await _cropAndProcessImage(tempPath);

      // Delete the temporary file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      if (cropSuccess) {
        notifyListeners();
        imagePathNotifier.notifyListeners();
        onUpdate(forceRebuild: true);
        print('Image updated, notified listeners');
        return true;
      }
      print('No image selected or cropping cancelled');
      return false;
    } catch (e) {
      print('Error saving web image: $e');
      throw Exception('Failed to save web image: $e');
    }
  }

  Future<void> showRenameDialog(BuildContext context) async {
    String newName = content;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rename Item'),
          content: TextField(
            onChanged: (value) {
              newName = value;
            },
            textCapitalization: TextCapitalization.sentences,
            controller: TextEditingController(text: content),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Rename'),
              onPressed: () {
                rename(newName);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool> showDeleteConfirmationDialog(BuildContext context) async {
    bool shouldDelete = false;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Item'),
          content: Text('Are you sure you want to delete "$content"?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                shouldDelete = true;
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
    return shouldDelete;
  }

  Future<bool> delete(BuildContext context) async {
    bool shouldDelete = await showDeleteConfirmationDialog(context);
    if (shouldDelete) {
      await deleteAssociatedFiles();
      return true;
    }
    return false;
  }

  void showItemOptions(
      BuildContext context, Function onUpdate, Function onDelete) {
    // Calculate the maximum width and height based on screen size
    final screenSize = MediaQuery.of(context).size;
    final maxWidth = screenSize.width * 0.9; // 90% of screen width
    final maxHeight = screenSize.height * 0.8; // 80% of screen height

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          content,
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (imagePath != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: FileImage(File(imagePath!)),
                                  fit: BoxFit.contain,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('Rename'),
                        onTap: () async {
                          Navigator.pop(context);
                          await showRenameDialog(context);
                          onUpdate(); // Call this to trigger save in parent
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.image),
                        title: const Text('Set Image'),
                        onTap: () async {
                          Navigator.pop(context);
                          await showImageSourceDialog(context);
                          onUpdate(); // This will trigger a rebuild and save in the parent
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete),
                        title: const Text('Delete'),
                        onTap: () async {
                          Navigator.pop(context);
                          bool deleted = await delete(context);
                          if (deleted) {
                            onDelete();
                          } else {
                            onUpdate();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${tier ?? "-"}${intertier ?? ""}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
