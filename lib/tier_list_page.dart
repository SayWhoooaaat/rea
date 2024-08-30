import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class TierListPage extends StatefulWidget {
  final String name;
  final int index;
  const TierListPage({Key? key, required this.name, required this.index})
      : super(key: key);

  @override
  State<TierListPage> createState() => TierListPageState();
}

class TierListPageState extends State<TierListPage> {
  final List<String> tiers = ['S', 'A', 'B', 'C', 'D', 'E', 'F'];
  List<Map<String, dynamic>> customItems = [];
  Map<String, List<Map<String, dynamic>>> rankedItems = {};

  late Future<void> _loadItemsFuture;

  // Add this constant at the top of the class
  static const double itemSize = 70.0;

  @override
  void initState() {
    super.initState();
    _loadItemsFuture = _loadCustomItems();
    for (var tier in tiers) {
      rankedItems[tier] = [];
    }
  }

  String get _storageKey => 'customItems_${widget.index}';

  Future<void> _loadCustomItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String? itemsJson = prefs.getString(_storageKey);
    final String? rankedItemsJson = prefs.getString('${_storageKey}_ranked');

    setState(() {
      if (itemsJson != null) {
        customItems = List<Map<String, dynamic>>.from(json.decode(itemsJson));
      } else {
        customItems = [];
      }

      if (rankedItemsJson != null) {
        final Map<String, dynamic> decodedRankedItems =
            json.decode(rankedItemsJson);
        rankedItems = Map.fromEntries(decodedRankedItems.entries.map(
            (e) => MapEntry(e.key, List<Map<String, dynamic>>.from(e.value))));
      } else {
        rankedItems = {for (var tier in tiers) tier: []};
      }
    });
  }

  Future<void> _saveCustomItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String itemsJson = json.encode(customItems);
    final String rankedItemsJson = json.encode(rankedItems);
    await prefs.setString(_storageKey, itemsJson);
    await prefs.setString('${_storageKey}_ranked', rankedItemsJson);
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
            child: DragTarget<Map<String, dynamic>>(
              builder: (context, candidateData, rejectedData) {
                return Container(
                  color: Colors.grey[800],
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: rankedItems[tier]!.length,
                    itemBuilder: (context, index) {
                      return _buildDraggableItem(
                          rankedItems[tier]![index], tier, index);
                    },
                  ),
                );
              },
              onAcceptWithDetails: (details) {
                final data = details.data;
                setState(() {
                  if (customItems.remove(data)) {
                    rankedItems[tier]!.add(data);
                  } else {
                    for (var t in tiers) {
                      if (rankedItems[t]!.remove(data)) {
                        rankedItems[tier]!.add(data);
                        break;
                      }
                    }
                  }
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
    return DragTarget<Map<String, dynamic>>(
      builder: (context, candidateData, rejectedData) {
        return Container(
          height: itemSize + 16,
          color: candidateData.isNotEmpty ? Colors.grey[700] : Colors.grey[900],
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: customItems.length,
            itemBuilder: (context, index) {
              return _buildDraggableItem(customItems[index], null, index);
            },
          ),
        );
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        setState(() {
          for (var tier in tiers) {
            rankedItems[tier]!.remove(data);
          }
          if (!customItems.contains(data)) {
            customItems.add(data);
          }
          _saveCustomItems();
        });
      },
    );
  }

  Widget _buildDraggableItem(
      Map<String, dynamic> item, String? tier, int index) {
    return GestureDetector(
      onDoubleTap: () async {
        if (mounted) {
          _showItemOptions(context, item, tier, index);
        }
      },
      child: LongPressDraggable<Map<String, dynamic>>(
        data: item,
        delay: const Duration(milliseconds: 300), // Adjust this value as needed
        feedback: Material(
          elevation: 4.0,
          child: SizedBox(
            width: itemSize,
            height: itemSize,
            child: _buildCustomItem(item),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.5,
          child: _buildCustomItem(item),
        ),
        child: DragTarget<Map<String, dynamic>>(
          builder: (context, candidateData, rejectedData) {
            return _buildCustomItem(item);
          },
          onAcceptWithDetails: (details) {
            _handleItemAccept(details.data, tier, index);
          },
        ),
      ),
    );
  }

  void _handleItemAccept(Map<String, dynamic> data, String? tier, int index) {
    setState(() {
      if (tier != null) {
        // Remove the item from its original position
        for (var t in tiers) {
          rankedItems[t]!.remove(data);
        }
        customItems.remove(data);

        // Insert the item at the new position
        rankedItems[tier]!.insert(index, data);
      } else {
        // Remove the item from its original position
        for (var t in tiers) {
          rankedItems[t]!.remove(data);
        }
        customItems.remove(data);

        // Insert the item at the new position in customItems
        customItems.insert(index, data);
      }
      _saveCustomItems();
    });
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
      customItems.add({'type': 'text', 'content': text});
      _saveCustomItems();
    });
  }

  void _showItemOptions(BuildContext context, Map<String, dynamic> item,
      String? tier, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Item Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(context, item, tier, index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteItem(item, tier, index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, Map<String, dynamic> item,
      String? tier, int index) {
    String newName = item['content'];
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
            controller: TextEditingController(text: item['content']),
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
                _renameItem(item, newName, tier, index);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _renameItem(
      Map<String, dynamic> item, String newName, String? tier, int index) {
    setState(() {
      item['content'] = newName;
      _saveCustomItems();
    });
  }

  void _deleteItem(Map<String, dynamic> item, String? tier, int index) {
    setState(() {
      if (tier != null) {
        rankedItems[tier]!.removeAt(index);
      } else {
        customItems.removeAt(index);
      }
      _saveCustomItems();
    });
  }

  Future<void> deleteAllContent() async {
    setState(() {
      customItems.clear();
      for (var tier in tiers) {
        rankedItems[tier]!.clear();
      }
    });
    await _saveCustomItems();
  }
}
