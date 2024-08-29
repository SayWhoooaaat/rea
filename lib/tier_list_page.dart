import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TierListPage extends StatefulWidget {
  final String title;
  const TierListPage({super.key, required this.title});

  @override
  State<TierListPage> createState() => TierListPageState();
}

class TierListPageState extends State<TierListPage> {
  final List<String> tiers = ['S', 'A', 'B', 'C', 'D', 'E', 'F'];
  List<Map<String, dynamic>> customItems = [];

  late Future<void> _loadItemsFuture;

  // Add this constant at the top of the class
  static const double itemSize = 80.0;

  @override
  void initState() {
    super.initState();
    _loadItemsFuture = _loadCustomItems();
  }

  String get _storageKey => 'customItems_${widget.title}';

  Future<void> _loadCustomItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String? itemsJson = prefs.getString(_storageKey);
    print('Loading items for ${widget.title}: $itemsJson'); // Debug print
    if (itemsJson != null) {
      setState(() {
        customItems = List<Map<String, dynamic>>.from(json.decode(itemsJson));
      });
    }
    print('Loaded items for ${widget.title}: $customItems'); // Debug print
  }

  Future<void> _saveCustomItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String itemsJson = json.encode(customItems);
    await prefs.setString(_storageKey, itemsJson);
    print('Saved items for ${widget.title}: $itemsJson'); // Debug print
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
              title: Text(widget.title),
            ),
            body: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: tiers.length,
                    itemBuilder: (context, index) {
                      return Container(
                        height: itemSize, // Use the constant here
                        margin: const EdgeInsets.symmetric(vertical: 1.0),
                        child: Row(
                          children: [
                            // Here is one tier (eg. S)
                            Container(
                              width: itemSize, // Use the constant here
                              height: itemSize, // Use the constant here
                              color: _getTierColor(tiers[index]),
                              alignment: Alignment.center,
                              child: Text(
                                tiers[index],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  height: itemSize + 16, // itemSize plus some padding
                  color: Colors.grey[900],
                  child: customItems.isEmpty
                      ? const Center(
                          child: Text(
                              'Import images or add text to start ranking'))
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: customItems.length,
                          itemBuilder: (context, index) {
                            return Draggable<Map<String, dynamic>>(
                              data: customItems[index],
                              feedback: _buildCustomItem(customItems[index]),
                              childWhenDragging: Opacity(
                                opacity: 0.5,
                                child: _buildCustomItem(customItems[index]),
                              ),
                              child: _buildCustomItem(customItems[index]),
                            );
                          },
                        ),
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

  Widget _buildImageThumbnail(String imagePath) {
    return Container(
      width: itemSize,
      height: itemSize,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(imagePath),
          fit: BoxFit.contain, // Change this from cover to contain
        ),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildTextBox(String text) {
    return Container(
      width: itemSize, // Use the constant here
      height: itemSize, // Use the constant here
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
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

  Widget _buildCustomItem(Map<String, dynamic> item) {
    return item['type'] == 'image'
        ? _buildImageThumbnail(item['content'])
        : _buildTextBox(item['content']);
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
    print('Adding text box: $text'); // Debug print
    setState(() {
      customItems.add({'type': 'text', 'content': text});
      _saveCustomItems();
    });
  }

  void _addImportedImage(String imagePath) {
    setState(() {
      customItems.add({'type': 'image', 'content': imagePath});
      _saveCustomItems(); // Add this line
    });
  }

  void _updateItemPosition(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = customItems.removeAt(oldIndex);
      customItems.insert(newIndex, item);
      _saveCustomItems(); // Add this line
    });
  }
}
