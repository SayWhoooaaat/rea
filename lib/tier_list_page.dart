import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'models/rank_item.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class TierListPage extends StatefulWidget {
  final String name;
  final int index;
  final bool hidden;
  final String password;
  const TierListPage(
      {super.key,
      required this.name,
      required this.index,
      this.hidden = false,
      this.password = ''});

  @override
  State<TierListPage> createState() => TierListPageState();
}

class TierListPageState extends State<TierListPage> {
  final List<String> tiers = ['S', 'A', 'B', 'C', 'D', 'E', 'F'];
  List<RankItem> items = [];

  late Future<void> _loadItemsFuture;

  // Add this constant at the top of the class
  static const double itemSize = 70.0;

  @override
  void initState() {
    super.initState();
    _loadItemsFuture = _loadCustomItems();
  }

  String get _storageKey => 'customItems_${widget.index}';

  Future<void> _loadCustomItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String? itemsJson = prefs.getString(_storageKey);

    setState(() {
      if (itemsJson != null) {
        final List<dynamic> decodedItems = json.decode(itemsJson);
        items = decodedItems.map((item) => RankItem.fromJson(item)).toList();
      } else {
        items = [];
      }
    });
  }

  Future<void> _saveCustomItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String itemsJson =
        json.encode(items.map((item) => item.toJson()).toList());
    await prefs.setString(_storageKey, itemsJson);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadItemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else {
          return Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: Text(widget.name),
            ),
            body: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: tiers.length,
                        itemBuilder: (context, index) {
                          return _buildTierRow(tiers[index]);
                        },
                      ),
                    ),
                    _buildUnrankedItemsRow(),
                  ],
                ),
              ],
            ),
            floatingActionButton: SpeedDial(
              icon: Icons.add,
              activeIcon: Icons.close,
              children: [
                SpeedDialChild(
                  child: const Icon(Icons.photo_library),
                  label: 'Pick from device',
                  onTap: () {
                    // Implement pick from device logic
                  },
                ),
                SpeedDialChild(
                  child: const Icon(Icons.camera_alt),
                  label: 'Open camera',
                  onTap: () {
                    // Implement open camera logic
                  },
                ),
                SpeedDialChild(
                  child: const Icon(Icons.search),
                  label: 'Google image search',
                  onTap: () {
                    // Implement Google image search logic
                  },
                ),
                SpeedDialChild(
                  child: const Icon(Icons.text_fields),
                  label: 'Just use text',
                  onTap: () {
                    _showTextInputDialog(context);
                  },
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildTierRow(String tier) {
    return Container(
      height: itemSize,
      margin: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        children: [
          Container(
            width: itemSize,
            height: itemSize,
            color: _getTierColor(tier),
            alignment: Alignment.center,
            child: Text(
              tier,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: DragTarget<RankItem>(
              builder: (context, candidateData, rejectedData) {
                return Container(
                  color: Colors.grey[800],
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.where((item) => item.tier == tier).length,
                    itemBuilder: (context, index) {
                      return _buildDraggableItem(items
                          .where((item) => item.tier == tier)
                          .toList()[index]);
                    },
                  ),
                );
              },
              onAcceptWithDetails: (details) {
                final item = details.data;
                setState(() {
                  item.tier = tier;
                  _saveCustomItems();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnrankedItemsRow() {
    return DragTarget<RankItem>(
      builder: (context, candidateData, rejectedData) {
        return Container(
          height: itemSize + 16,
          color: candidateData.isNotEmpty ? Colors.grey[700] : Colors.grey[900],
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.where((item) => item.tier == null).length,
            itemBuilder: (context, index) {
              return _buildDraggableItem(
                  items.where((item) => item.tier == null).toList()[index]);
            },
          ),
        );
      },
      onAcceptWithDetails: (details) {
        final item = details.data;
        setState(() {
          item.tier = null;
          _saveCustomItems();
        });
      },
    );
  }

  Widget _buildDraggableItem(RankItem item) {
    return GestureDetector(
      onDoubleTap: () {
        if (mounted) {
          _showItemOptions(context, item);
        }
      },
      child: LongPressDraggable<RankItem>(
        data: item,
        delay: const Duration(milliseconds: 300),
        feedback: Material(
          elevation: 4.0,
          child: SizedBox(
            width: itemSize,
            height: itemSize,
            child: item.buildWidget(itemSize),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.5,
          child: item.buildWidget(itemSize),
        ),
        child: item.buildWidget(itemSize),
      ),
    );
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'S':
        return Colors.red;
      case 'A':
        return Colors.orange;
      case 'B':
        return Colors.amber;
      case 'C':
        return Colors.green;
      case 'D':
        return Colors.blue;
      case 'E':
        return Colors.indigo;
      case 'F':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<bool> _requestPermission(Permission permission) async {
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

  void _showTextInputDialog(BuildContext context) {
    String inputText = '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tier list item'),
          content: TextField(
            onChanged: (value) {
              inputText = value;
            },
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () {
                if (inputText.isNotEmpty) {
                  _addCustomTextBox(inputText);
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _addCustomTextBox(String text) {
    setState(() {
      items.add(RankItem(content: text));
      _saveCustomItems();
    });
  }

  void _showItemOptions(BuildContext context, RankItem item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(item.content),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(context, item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Set Image'),
                onTap: () {
                  Navigator.pop(context);
                  _showImageSourceDialog(context, item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteItem(item);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showImageSourceDialog(BuildContext context, RankItem item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Device'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery, item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Open Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera, item);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source, RankItem item) async {
    try {
      bool hasPermission = true;
      if (!kIsWeb) {
        if (source == ImageSource.gallery) {
          hasPermission = await _requestPermission(Permission.photos);
        } else {
          hasPermission = await _requestPermission(Permission.camera);
        }
      }

      if (hasPermission) {
        await item.pickAndSetImage(source);
        if (mounted) {
          setState(() {
            _saveCustomItems();
          });
        }
      } else {
        print('Permission not granted');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Permission denied. Please grant access in app settings.')),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Error setting image: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error setting image: $e')),
        );
      }
    }
  }

  void _showRenameDialog(BuildContext context, RankItem item) {
    String newName = item.content;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rename Item'),
          content: TextField(
            onChanged: (value) {
              newName = value;
            },
            textCapitalization: TextCapitalization.sentences,
            controller: TextEditingController(text: item.content),
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
                _renameItem(item, newName);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _renameItem(RankItem item, String newName) {
    setState(() {
      item.content = newName;
      _saveCustomItems();
    });
  }

  void _deleteItem(RankItem item) {
    item.deleteAssociatedFiles();
    setState(() {
      items.remove(item);
      _saveCustomItems();
    });
  }

  Future<void> deleteAllContent() async {
    for (var item in items) {
      await item.deleteAssociatedFiles();
    }
    setState(() {
      items.clear();
    });
    await _saveCustomItems();
  }
}
