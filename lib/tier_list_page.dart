import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models/rank_item.dart';
import 'web_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/services.dart';

class TierListPage extends StatefulWidget {
  final String name;
  final int index;
  final bool hidden;
  final String password;
  final VoidCallback onForceRebuild;

  const TierListPage({
    required GlobalKey<TierListPageState> key,
    required this.name,
    required this.index,
    this.hidden = false,
    this.password = '',
    required this.onForceRebuild,
  }) : super(key: key);

  static Future<void> deleteAllContentStatic(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final String? itemsJson = prefs.getString('customItems_$index');

    if (itemsJson != null) {
      final List<dynamic> decodedItems = json.decode(itemsJson);
      final items = decodedItems
          .map((item) => RankItem.fromJson(item,
              onUpdate: ({bool forceRebuild = false}) => {}))
          .toList();

      for (var item in items) {
        await item.deleteAssociatedFiles();
      }
    }
    await prefs.remove('customItems_$index');
  }

  @override
  State<TierListPage> createState() => TierListPageState();
}

class TierListPageState extends State<TierListPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<String> tiers = [];
  Map<String, Color> tierColors = {};

  List<RankItem> items = [];

  bool _isLoading = true;

  late double itemSize;

  @override
  void initState() {
    super.initState();
    _loadTierData().then((_) {
      _loadCustomItems().then((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  String get _storageKey => 'customItems_${widget.index}';

  Future<void> _loadTierData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tierListsJson = prefs.getString('tierLists');

    if (tierListsJson != null) {
      final List<dynamic> allTierLists = json.decode(tierListsJson);
      // Find the correct tier list for this index
      final tierList = allTierLists.firstWhere(
          (list) => list['index'] == widget.index,
          orElse: () => null);

      if (tierList != null && tierList.containsKey('ranks')) {
        List<dynamic> ranks = tierList['ranks'];
        setState(() {
          // Extract the label from each rank item
          tiers = ranks.map<String>((rank) => rank['label'] as String).toList();

          // Build the colors map
          tierColors = {};
          for (var rank in ranks) {
            // Convert hex color string to Color
            String hexColor = rank['color'];
            if (hexColor.startsWith('#')) {
              hexColor = hexColor.substring(1);
            }
            tierColors[rank['label']] =
                Color(int.parse('FF$hexColor', radix: 16));
          }
        });
      } else {
        _setDefaultTiers();
      }
    } else {
      _setDefaultTiers();
    }
  }

  void _setDefaultTiers() {
    setState(() {
      tiers = ['S', 'A', 'B', 'C', 'D', 'E', 'F'];
      tierColors = {
        'S': Colors.red,
        'A': Colors.orange,
        'B': Colors.amber,
        'C': Colors.green,
        'D': Colors.blue,
        'E': Colors.indigo,
        'F': Colors.purple,
      };
    });
  }

  Future<void> _loadCustomItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String? itemsJson = prefs.getString(_storageKey);

    if (itemsJson != null) {
      final List<dynamic> decodedItems = json.decode(itemsJson);
      items = decodedItems
          .map((item) => RankItem.fromJson(item,
              onUpdate: ({bool forceRebuild = false}) =>
                  _saveCustomItems(forceRebuild: forceRebuild)))
          .toList();
    } else {
      items = [];
    }
    setState(() {});
  }

  void _addItem(RankItem item) {
    items.add(item);
    print('Done with everything. want to update. mounted: $mounted');
    if (mounted) {
      setState(() {});
    }
    _saveAndNotifyItemUpdate();
  }

  Future<void> _saveCustomItems({bool forceRebuild = false}) async {
    print('Onupdate/_saveCustomItems , mounted: $mounted');
    final prefs = await SharedPreferences.getInstance();
    final String itemsJson =
        json.encode(items.map((item) => item.toJson()).toList());
    await prefs.setString(_storageKey, itemsJson);
    print('Items saved: $itemsJson');
    if (forceRebuild) {
      widget.onForceRebuild(); // Only call this when forceRebuild is true
    }
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
    final scaffoldMessenger =
        ScaffoldMessenger.of(this.context); // Use this.context
    try {
      print('Before WebPicker, mounted: $mounted');
      final result = await Navigator.of(this.context, rootNavigator: true).push(
        MaterialPageRoute(builder: (context) => WebViewScreenshotPage()),
      );
      print('After WebPicker, mounted: $mounted');
      if (result != null && result is Uint8List) {
        final newItem = RankItem(
            content: '',
            onUpdate: ({bool forceRebuild = false}) =>
                _saveCustomItems(forceRebuild: forceRebuild));

        final bool success = await newItem.saveWebImage(result);
        print('After saveWebImage, mounted: $mounted');
        if (success) {
          _addItem(newItem);
        }
        print('Before rebuild, mounted: $mounted');
        widget.onForceRebuild();
        print('After rebuild, mounted: $mounted');
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
    // Calculate itemSize based on available height
    final double availableHeight = MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        kToolbarHeight;
    itemSize =
        (availableHeight / (tiers.length + 1.5)).clamp(70.0, double.infinity);
    print('At Build, mounted: $mounted');
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
            child: const Icon(Icons.camera_alt),
            label: 'Open camera',
            onTap: () async {
              final newItem = RankItem(
                  content: '',
                  onUpdate: ({bool forceRebuild = false}) =>
                      _saveCustomItems(forceRebuild: forceRebuild));
              try {
                final bool success =
                    await newItem.pickAndSetImage(ImageSource.camera);
                if (success) {
                  _addItem(newItem);
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.photo_library),
            label: 'Pick from device',
            onTap: () async {
              final newItem = RankItem(
                  content: '',
                  onUpdate: ({bool forceRebuild = false}) =>
                      _saveCustomItems(forceRebuild: forceRebuild));
              try {
                final bool success =
                    await newItem.pickAndSetImage(ImageSource.gallery);
                if (success) {
                  _addItem(newItem);
                }
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
          GestureDetector(
            onLongPress: () {
              HapticFeedback.mediumImpact();
              _showTierOptionsDialog(tier);
            },
            child: Container(
              width: itemSize,
              height: itemSize,
              color: tierColors[tier] ?? Colors.grey,
              alignment: Alignment.center,
              child: Text(
                tier,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: itemSize * 0.32,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          Expanded(
            child: DragTarget<RankItem>(
              builder: (context, candidateData, rejectedData) {
                return Container(
                  color: Theme.of(context).colorScheme.surfaceBright,
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
    return Container(
      height: itemSize,
      margin: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        children: [
          Expanded(
            child: DragTarget<RankItem>(
              builder: (context, candidateData, rejectedData) {
                return Container(
                  color: Theme.of(context).colorScheme.surfaceBright,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.where((item) => item.tier == null).length,
                    itemBuilder: (context, index) {
                      return _buildDraggableItem(items
                          .where((item) => item.tier == null)
                          .toList()[index]);
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
            ),
          ),
        ],
      ),
    );
  }

  void updateItemIntertier(RankItem item, Offset dropPosition, String? tier) {
    // Remove the item from its current position
    items.remove(item);

    List<RankItem> relevantItems = items.where((i) => i.tier == tier).toList();
    relevantItems
        .sort((a, b) => (a.intertier ?? 0).compareTo(b.intertier ?? 0));

    int dropIndex = 0;
    print('floating ${dropPosition.dx}');
    for (int i = 0; i < relevantItems.length; i++) {
      final currentContext = relevantItems[i].key.currentContext;
      // Skip if the item is not currently rendered (outside viewport)
      if (currentContext == null) {
        continue;
      }
      final RenderBox? box = currentContext.findRenderObject() as RenderBox?;
      if (box == null) {
        continue;
      }
      Offset itemPosition = box.localToGlobal(Offset.zero);
      print('floating ${itemPosition.dx}');
      if (dropPosition.dx > itemPosition.dx) {
        dropIndex = i + 1;
      } else {
        break;
      }
    }
    print('floating ${dropIndex}');

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
                  _saveCustomItems(); // Add this line
                  if (mounted) {
                    setState(() {});
                  }
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
              color: Colors.transparent,
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
    final newItem = RankItem(
        content: text,
        onUpdate: ({bool forceRebuild = false}) =>
            _saveCustomItems(forceRebuild: forceRebuild));
    _addItem(newItem);
  }

  void _showTierOptionsDialog(String tier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text('Edit tier $tier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename tier'),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameTierDialog(tier);
              },
            ),
            ListTile(
              leading: const Icon(Icons.color_lens),
              title: const Text('Change color'),
              onTap: () {
                Navigator.pop(ctx);
                _showChangeTierColorDialog(tier);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Insert new tier'),
              onTap: () {
                Navigator.pop(ctx);
                _showInsertTierDialog(tier);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: const Text('Move up'),
              onTap: () {
                Navigator.pop(ctx);
                _moveTier(tier, up: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward),
              title: const Text('Move down'),
              onTap: () {
                Navigator.pop(ctx);
                _moveTier(tier, up: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Remove tier'),
              onTap: () {
                Navigator.pop(ctx);
                _removeTier(tier);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameTierDialog(String oldTier) {
    String newTierName = oldTier;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename tier'),
        content: TextField(
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'New name'),
          onChanged: (value) => newTierName = value,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (newTierName.trim().isEmpty) return;
              final i = tiers.indexOf(oldTier);
              setState(() {
                tiers[i] = newTierName;
                final c = tierColors.remove(oldTier);
                if (c != null) tierColors[newTierName] = c;
                for (var it in items.where((it) => it.tier == oldTier)) {
                  it.tier = newTierName;
                }
              });
              Navigator.pop(ctx);
              _saveTierData();
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showChangeTierColorDialog(String tier) {
    Color selected = tierColors[tier] ?? Colors.grey;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Select color'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: selected,
            onColorChanged: (c) => selected = c,
            availableColors: const [
              Colors.white, // ← explicitly add white
              ...Colors.primaries, // ← all Material primaries
              Colors.black,
              Colors.grey,
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() => tierColors[tier] = selected);
              Navigator.pop(ctx);
              _saveTierData();
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  void _showInsertTierDialog(String afterTier) {
    String name = '';
    Color pick = Colors.grey;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insert new tier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Tier name'),
                onChanged: (v) => name = v,
              ),
              const SizedBox(height: 16),
              const Text('Select color'),
              BlockPicker(
                pickerColor: pick,
                onColorChanged: (c) => pick = c,
                availableColors: const [
                  Colors.white, // ← explicitly add white
                  ...Colors.primaries, // ← all Material primaries
                  Colors.black,
                  Colors.grey,
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (name.trim().isEmpty) return;
              final i = tiers.indexOf(afterTier);
              setState(() {
                tiers.insert(i + 1, name);
                tierColors[name] = pick;
              });
              Navigator.pop(ctx);
              _saveTierData();
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );
  }

  void _moveTier(String tier, {required bool up}) {
    final i = tiers.indexOf(tier);
    final j = up ? i - 1 : i + 1;
    if (i < 0 || j < 0 || j >= tiers.length) return;
    setState(() {
      tiers.removeAt(i);
      tiers.insert(j, tier);
    });
    _saveTierData();
  }

  void _removeTier(String tier) {
    setState(() {
      tiers.remove(tier);
      tierColors.remove(tier);
      // un‐assign any items in that tier:
      for (var it in items.where((it) => it.tier == tier)) {
        it.tier = null;
      }
    });
    _saveTierData();
  }

  Future<void> _saveTierData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tierLists');
    final List<dynamic> all =
        raw != null ? json.decode(raw) as List<dynamic> : <dynamic>[];

    // build fresh ranks list
    final newRanks = tiers.map((label) {
      final c = tierColors[label]!;
      final hex = c.value.toRadixString(16).padLeft(8, '0').substring(2);
      return {
        'label': label,
        'color': '#${hex.toUpperCase()}',
      };
    }).toList();

    // find existing entry
    final idx = all.indexWhere((e) => e['index'] == widget.index);
    if (idx != -1) {
      // clone & update only ranks
      final entry = Map<String, dynamic>.from(all[idx]);
      entry['ranks'] = newRanks;
      all[idx] = entry;
    } else {
      // no entry yet— add minimal one
      all.add({
        'index': widget.index,
        'ranks': newRanks,
      });
    }
    await prefs.setString('tierLists', json.encode(all));
    widget.onForceRebuild(); // tell main page to refresh its list
    if (mounted) setState(() {}); // refresh UI if needed
    _saveAndNotifyItemUpdate();
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

  // Add this method to save items whenever they are updated
  void _saveAndNotifyItemUpdate() {
    _saveCustomItems();
    if (mounted) setState(() {}); // Trigger a rebuild to reflect changes
  }

  void _showDeleteAllConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete All Content'),
          content: const Text(
              'Are you sure you want to delete all content? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () async {
                Navigator.of(context).pop();
                await deleteAllContent();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('All content has been deleted')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
