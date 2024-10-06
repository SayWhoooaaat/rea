import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models/rank_item.dart';
import 'web_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

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

  Future<void> deleteAllContent() async {
    if (key is GlobalKey<TierListPageState>) {
      await (key as GlobalKey<TierListPageState>)
          .currentState
          ?.deleteAllContent();
    }
  }

  @override
  State<TierListPage> createState() => TierListPageState();
}

class TierListPageState extends State<TierListPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final List<String> tiers = ['S', 'A', 'B', 'C', 'D', 'E', 'F'];
  List<RankItem> items = [];

  late Future<void> _loadItemsFuture;
  bool _isLoading = true;

  final Map<RankItem, VoidCallback> itemListeners = {};
  final Map<RankItem, VoidCallback> imagePathListeners = {};

  // Add this constant at the top of the class
  static const double itemSize = 70.0;

  @override
  void initState() {
    super.initState();
    _loadCustomItems().then((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    for (var item in items) {
      if (itemListeners.containsKey(item)) {
        item.removeListener(itemListeners[item]!);
      }
      if (imagePathListeners.containsKey(item)) {
        item.imagePathNotifier.removeListener(imagePathListeners[item]!);
      }
    }
    super.dispose();
  }

  String get _storageKey => 'customItems_${widget.index}';

  Future<void> _loadCustomItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String? itemsJson = prefs.getString(_storageKey);

    if (itemsJson != null) {
      final List<dynamic> decodedItems = json.decode(itemsJson);
      items = decodedItems
          .map((item) => RankItem.fromJson(item, onUpdate: _saveCustomItems))
          .toList();
      for (var item in items) {
        VoidCallback itemListener = () => _onItemChanged(item);
        VoidCallback imagePathListener = () => _onItemChanged(item);

        item.addListener(itemListener);
        item.imagePathNotifier.addListener(imagePathListener);

        itemListeners[item] = itemListener;
        imagePathListeners[item] = imagePathListener;
      }
    } else {
      items = [];
    }
    setState(() {});
  }

  void _addItem(RankItem item) {
    VoidCallback itemListener = () => _onItemChanged(item);
    VoidCallback imagePathListener = () => _onItemChanged(item);

    item.addListener(itemListener);
    item.imagePathNotifier.addListener(imagePathListener);

    itemListeners[item] = itemListener;
    imagePathListeners[item] = imagePathListener;
    items.add(item);

    if (mounted) {
      setState(() {});
    }
    _saveAndNotifyItemUpdate();
  }

  void _onItemChanged(RankItem item) {
    print('Item changed: ${item.content}, Image: ${item.imagePath}');
    _saveCustomItems();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveCustomItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String itemsJson =
        json.encode(items.map((item) => item.toJson()).toList());
    await prefs.setString(_storageKey, itemsJson);
    print('Items saved: $itemsJson');
  }

  void sortRankItemsByIntertier(List<RankItem> items) {
    items.sort((a, b) {
      int aTierIndex = a.tier != null ? tiers.indexOf(a.tier!) : tiers.length;
      int bTierIndex = b.tier != null ? tiers.indexOf(b.tier!) : tiers.length;

      // First, sort by tier
      if (aTierIndex != bTierIndex) {
        return aTierIndex.compareTo(bTierIndex);
      }

      // If in the same tier (including unranked), sort by intertier
      return (a.intertier ?? double.maxFinite)
          .compareTo(b.intertier ?? double.maxFinite);
    });

    // Update intertier values
    String? currentTier;
    int intertierCount = 1;
    for (var item in items) {
      if (item.tier != currentTier) {
        currentTier = item.tier;
        intertierCount = 1;
      }
      item.intertier = intertierCount++;
    }
  }

  void _onWebTap() async {
    final newItem = RankItem(content: '', onUpdate: _saveCustomItems);
    final scaffoldMessenger =
        ScaffoldMessenger.of(context); // Use the current context
    try {
      print('Before WebPicker, mounted: $mounted');
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => WebViewScreenshotPage()),
      );
      print('After WebPicker, mounted: $mounted');
      if (result != null && result is Uint8List) {
        await newItem.saveWebImage(result);
        print('After savewebimage, mounted: $mounted');
        _addItem(newItem);
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.name),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
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
            onTap: () async {
              final newItem = RankItem(content: '', onUpdate: _saveCustomItems);
              try {
                await newItem.pickAndSetImage(ImageSource.gallery);
                _addItem(newItem);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.camera_alt),
            label: 'Open camera',
            onTap: () async {
              final newItem = RankItem(content: '', onUpdate: _saveCustomItems);
              try {
                await newItem.pickAndSetImage(ImageSource.camera);
                _addItem(newItem);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.search),
            label: 'Web image search',
            onTap: _onWebTap, // doesnt need context i think(????)
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
                  updateItemIntertier(item, details.offset, item.tier);
                  sortRankItemsByIntertier(items);
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
          updateItemIntertier(item, details.offset, null);
          sortRankItemsByIntertier(items);
          _saveCustomItems();
        });
      },
    );
  }

  void updateItemIntertier(RankItem item, Offset dropPosition, String? tier) {
    // Remove the item from its current position
    items.remove(item);

    List<RankItem> relevantItems = items.where((i) => i.tier == tier).toList();
    relevantItems
        .sort((a, b) => (a.intertier ?? 0).compareTo(b.intertier ?? 0));

    int dropIndex = 0;
    for (int i = 0; i < relevantItems.length; i++) {
      RenderBox box =
          relevantItems[i].key.currentContext!.findRenderObject() as RenderBox;
      Offset itemPosition = box.localToGlobal(Offset.zero);
      if (dropPosition.dx > itemPosition.dx) {
        dropIndex = i + 1;
      } else {
        break;
      }
    }

    // Insert the item at the correct position
    relevantItems.insert(dropIndex, item);

    // Update the tier of the item
    item.tier = tier;

    // Renumber all items from 1 to n
    for (int i = 0; i < relevantItems.length; i++) {
      relevantItems[i].intertier = i + 1;
    }

    // Update the main items list
    items.removeWhere((i) => i.tier == tier);
    items.addAll(relevantItems);

    // Add this line at the end of the method
    _saveAndNotifyItemUpdate();
  }

  Widget _buildDraggableItem(RankItem item) {
    return ListenableBuilder(
      listenable: Listenable.merge([item, item.imagePathNotifier]),
      builder: (context, child) {
        return GestureDetector(
          key: item.key,
          onTap: () {
            if (mounted) {
              item.showItemOptions(
                context,
                () {
                  _onItemChanged(item);
                  _saveCustomItems(); // Add this line
                },
                () {
                  setState(() {
                    items.remove(item);
                  });
                  _saveCustomItems();
                },
              );
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
      },
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
    final newItem = RankItem(content: text, onUpdate: _saveCustomItems);
    _addItem(newItem);
  }

  // Remove the _deleteItem method as it's no longer needed

  Future<void> deleteAllContent() async {
    for (var item in items) {
      await item.deleteAssociatedFiles();
    }
    setState(() {
      items.clear();
    });
    await _saveCustomItems();
  }

  // Add this method to save items whenever they are updated
  void _saveAndNotifyItemUpdate() {
    _saveCustomItems();
    setState(() {}); // Trigger a rebuild to reflect changes
  }
}
