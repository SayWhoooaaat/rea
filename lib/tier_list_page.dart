import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models/rank_item.dart';
import 'web_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/services.dart';
import 'models/tier_meta.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/scheduler.dart';

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

  final GlobalKey _repaintKey = GlobalKey();
  final ScreenshotController _shot = ScreenshotController();

  List<TierMeta> tiers = [];

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCustomSize(); // Ensures async operation is called after build.
    });
  }

  Future<void> _loadCustomSize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tierLists');
    if (raw != null) {
      final all = json.decode(raw) as List<dynamic>;
      final idx = all.indexWhere((e) => e['index'] == widget.index);
      if (idx != -1 && all[idx]['itemSize'] != null) {
        final rawSize = (all[idx]['itemSize'] as num).toDouble();
        final rounded = (rawSize / 4).round() * 4.0;
        setState(() => itemSize = rounded);
        // write the rounded value back so you don’t repeat this
        all[idx]['itemSize'] = rounded;
        await prefs.setString('tierLists', json.encode(all));
        print("read zoom = ${itemSize.toInt()}");

        return;
      }
    }
    // if no size detected
    final availableHeight = MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        kToolbarHeight;
    final baseSize =
        (availableHeight / (tiers.length + 1.5)).clamp(70.0, double.infinity);
    itemSize = (baseSize / 4).round() * 4;

    final all = raw != null ? json.decode(raw) as List<dynamic> : <dynamic>[];
    final idx = all.indexWhere((e) => e['index'] == widget.index);
    if (idx != -1) {
      final entry = Map<String, dynamic>.from(all[idx]);
      entry['itemSize'] = itemSize;
      all[idx] = entry;
      await prefs.setString('tierLists', json.encode(all));
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  String get _storageKey => 'customItems_${widget.index}';

  Future<void> _loadTierData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('tierLists');

    if (raw == null) {
      _setDefaultTiers();
      return;
    }

    final List<dynamic> allLists = json.decode(raw);
    final tierList = allLists.firstWhere((e) => e['index'] == widget.index,
        orElse: () => null);

    if (tierList == null || tierList['ranks'] == null) {
      _setDefaultTiers();
      return;
    }

    final ranks = List<Map<String, dynamic>>.from(tierList['ranks']);

    setState(() {
      tiers = [
        for (var i = 0; i < ranks.length; i++)
          TierMeta(
            id: (ranks[i]['id'] ?? i + 1) as int, // ← migrate old data
            label: ranks[i]['label'] as String,
            color: _hexToColor(ranks[i]['color'] as String),
          )
      ];
    });
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  void _setDefaultTiers() {
    setState(() {
      tiers = [
        TierMeta(id: 1, label: 'S', color: Colors.red),
        TierMeta(id: 2, label: 'A', color: Colors.orange),
        TierMeta(id: 3, label: 'B', color: Colors.amber),
        TierMeta(id: 4, label: 'C', color: Colors.green),
        TierMeta(id: 5, label: 'D', color: Colors.blue),
        TierMeta(id: 6, label: 'E', color: Colors.indigo),
        TierMeta(id: 7, label: 'F', color: Colors.deepPurple),
      ];
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
    int tierOrder(int? tierId) {
      if (tierId == null) return tiers.length; // “unranked” last
      final idx = tiers.indexWhere((t) => t.id == tierId);
      return idx >= 0 ? idx : tiers.length; // unknown → last
    }

    /* ---- 1. stable sort: by tier row first, then by inter‑row position ---- */
    items.sort((a, b) {
      final aRow = tierOrder(a.tierId);
      final bRow = tierOrder(b.tierId);
      if (aRow != bRow) return aRow.compareTo(bRow);

      return (a.intertier ?? double.maxFinite)
          .compareTo(b.intertier ?? double.maxFinite);
    });

    /* ---- 2. renumber intertier for every tier separately ------------------ */
    int? currentRow;
    int counter = 1;
    for (final it in items) {
      final row = tierOrder(it.tierId);
      if (row != currentRow) {
        currentRow = row;
        counter = 1;
      }
      it.intertier = counter++;
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
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.name),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'zoom') {
                _showSizeDialog();
              } else if (value == 'export') {
                _exportImage();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'zoom',
                child: Text('Adjust zoom'),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Text('Export image'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  // make it scrollable so on‐screen you can still scroll…
                  child: SingleChildScrollView(
                    child: RepaintBoundary(
                      key: _repaintKey, // <<— your GlobalKey
                      child: Column(
                        children: tiers
                            .map((tier) => _buildTierRow(tier))
                            .toList(), // <<— every tier‐row
                      ),
                    ),
                  ),
                ),
                _buildUnrankedItemsRow(),
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

  Widget _buildTierRow(TierMeta tierMeta) {
    final bg = tierMeta.color;
    final fg = bg.computeLuminance() > 0.05 ? Colors.black : Colors.grey;
    return Container(
      height: itemSize,
      margin: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        children: [
          GestureDetector(
            onLongPress: () {
              HapticFeedback.mediumImpact();
              _showTierOptionsDialog(tierMeta);
            },
            child: Container(
              width: itemSize,
              height: itemSize,
              color: bg,
              alignment: Alignment.center,
              child: AutoSizeText(
                tierMeta.label,
                minFontSize: 14,
                wrapWords: false,
                overflow: TextOverflow.clip,
                stepGranularity: 1,
                style: TextStyle(
                  fontSize: itemSize * 0.32,
                  fontWeight: FontWeight.bold,
                  color: fg,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            child: DragTarget<RankItem>(
              builder: (context, _, __) => Container(
                color: Theme.of(context).colorScheme.surfaceBright,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount:
                      items.where((it) => it.tierId == tierMeta.id).length,
                  itemBuilder: (ctx, i) => _buildDraggableItem(items
                      .where((it) => it.tierId == tierMeta.id)
                      .toList()[i]),
                ),
              ),
              onAcceptWithDetails: (details) {
                final item = details.data;
                setState(() {
                  item
                    ..tierId = tierMeta.id
                    ..tier = tierMeta.label; // keep legacy text, optional
                  updateItemIntertier(item, details.offset, tierMeta.id);
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
              builder: (c, _, __) => Container(
                color: Theme.of(context).colorScheme.surfaceBright,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.where((it) => it.tierId == null).length,
                  itemBuilder: (ctx, i) => _buildDraggableItem(
                      items.where((it) => it.tierId == null).toList()[i]),
                ),
              ),
              onAcceptWithDetails: (details) {
                final item = details.data;
                setState(() {
                  item
                    ..tierId = null
                    ..tier = null;
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

  void updateItemIntertier(RankItem item, Offset dropPosition, int? tierId) {
    items.remove(item);

    final relevant = items.where((i) => i.tierId == tierId).toList()
      ..sort((a, b) => (a.intertier ?? 0).compareTo(b.intertier ?? 0));

    int dropIndex = 0;
    for (var i = 0; i < relevant.length; i++) {
      final ctx = relevant[i].key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;
      if (dropPosition.dx > box.localToGlobal(Offset.zero).dx) {
        dropIndex = i + 1;
      } else {
        break;
      }
    }

    relevant.insert(dropIndex, item);

    item.tierId = tierId;

    for (var i = 0; i < relevant.length; i++) {
      relevant[i].intertier = i + 1;
    }

    items.removeWhere((i) => i.tierId == tierId);
    items.addAll(relevant);

    _saveAndNotifyItemUpdate(); // persist + rebuild
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

  Future<void> _exportImage() async {
    /* 2.  precache images ----------------------------- */
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final targetPx = (itemSize * dpr).round();
    print('Size: ${targetPx.toInt()}');
    final precacheFutures = <Future<void>>[
      for (final it in items)
        if (it.imagePath != null && it.imagePath!.isNotEmpty)
          precacheImage(
              ResizeImage(FileImage(File(it.imagePath!)),
                  width: targetPx.toInt(), height: targetPx.toInt()),
              context),
    ];
    await Future.wait(precacheFutures);

    /* 3.  wait one visual frame so all textures are uploaded ------------- */
    await SchedulerBinding.instance.endOfFrame;

    /* ---------- how wide & how high --------------------------------------- */
    final int maxPerRow = tiers
        .map((t) => items.where((it) => it.tierId == t.id).length)
        .fold<int>(0, math.max);

    final double outWidth = itemSize * (1 + maxPerRow);
    final textStyle = Theme.of(context).appBarTheme.titleTextStyle ??
        Theme.of(context).textTheme.titleLarge!;
    final double headerHeight =
        (textStyle.fontSize! * (textStyle.height ?? 1.2) + 8).ceilToDouble();
    final double outHeight =
        headerHeight + (itemSize + 2) * tiers.length; // header + rows

    const double maxPixels = 8000000; // 8 MP
    double pixRat = math.sqrt(maxPixels / (outWidth * outHeight));
    pixRat = clampDouble(pixRat, 0.1, 2.0);

    /* ---------- off-screen render ----------------------------------------- */
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final media = MediaQueryData.fromView(view);
    final Uint8List? pngBytes = await _shot.captureFromWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: media,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                for (final t in tiers) _buildTierRowExport(context, t),
              ],
            ),
          ),
        ),
      ),
      targetSize: Size(outWidth, outHeight),
      pixelRatio: pixRat,
      delay: const Duration(milliseconds: 200),
    );
    if (pngBytes == null) return;

    /* ---------- save to gallery ------------------------------------------- */
    final result = await ImageGallerySaver.saveImage(
      pngBytes,
      quality: 100,
      name: 'tier_${widget.name}_${DateTime.now().millisecondsSinceEpoch}',
    );

    final msg = result['isSuccess'] == true
        ? 'Saved to gallery!'
        : 'Save failed: ${result['errorMessage']}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildHeader(BuildContext ctx) {
    final textStyle = Theme.of(ctx).appBarTheme.titleTextStyle ??
        Theme.of(ctx).textTheme.titleLarge!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: Theme.of(ctx).colorScheme.surfaceBright,
      alignment: Alignment.center,
      child: Text(
        widget.name,
        style: textStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTierRowExport(BuildContext ctx, TierMeta tier) {
    Color rowBg = Theme.of(context).colorScheme.surfaceBright;
    final bg = tier.color;
    final fg = bg.computeLuminance() > 0.05 ? Colors.black : Colors.grey;

    return Container(
      height: itemSize,
      margin: const EdgeInsets.symmetric(vertical: 1),
      color: rowBg, // ← identical to in-app look
      child: Row(
        children: [
          Container(
            width: itemSize,
            height: itemSize,
            color: bg,
            alignment: Alignment.center,
            child: AutoSizeText(
              tier.label,
              minFontSize: 14,
              wrapWords: false,
              overflow: TextOverflow.clip,
              stepGranularity: 1,
              style: TextStyle(
                fontSize: itemSize * 0.32,
                fontWeight: FontWeight.bold,
                color: fg,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          for (final it in items.where((it) => it.tierId == tier.id))
            SizedBox(
                width: itemSize,
                height: itemSize,
                child: it.buildWidget(itemSize)),
        ],
      ),
    );
  }

  Future<void> _showSizeDialog() async {
    final double prevSize = itemSize;

    // showDialog<bool> returns true if “OK” was tapped,
    // false if “Cancel” was tapped, and null if dismissed by back/outside.
    final bool? shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Center(child: Text('Adjust zoom')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 48,
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      setStateDialog(() => itemSize =
                          (itemSize - 4).clamp(0.0, double.infinity));
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    iconSize: 48,
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      setStateDialog(() => itemSize = itemSize + 4);
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                  ElevatedButton(
                    child: const Text('OK'),
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldSave == false) {
      // user hit “Cancel”
      setState(() => itemSize = prevSize);
    } else {
      // OK, back‑button, or outside‐tap: persist new size
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('tierLists');
      final all = raw != null ? json.decode(raw) as List<dynamic> : <dynamic>[];
      final idx = all.indexWhere((e) => e['index'] == widget.index);
      if (idx != -1) {
        final entry = Map<String, dynamic>.from(all[idx]);
        entry['itemSize'] = itemSize;
        all[idx] = entry;
        await prefs.setString('tierLists', json.encode(all));
        print("stored zoom = ${itemSize.toInt()}");

        widget.onForceRebuild();
        if (mounted) setState(() {});
        _saveAndNotifyItemUpdate();
      }
    }
  }

  void _showTierOptionsDialog(TierMeta tierMeta) {
    String tier = tierMeta.label;
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
                _showRenameTierDialog(tierMeta);
              },
            ),
            ListTile(
              leading: const Icon(Icons.color_lens),
              title: const Text('Change color'),
              onTap: () {
                Navigator.pop(ctx);
                _showChangeTierColorDialog(tierMeta);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Insert new tier'),
              onTap: () {
                Navigator.pop(ctx);
                _showInsertTierDialog(tierMeta);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: const Text('Move up'),
              onTap: () {
                Navigator.pop(ctx);
                _moveTier(tierMeta, up: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward),
              title: const Text('Move down'),
              onTap: () {
                Navigator.pop(ctx);
                _moveTier(tierMeta, up: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Remove tier'),
              onTap: () {
                Navigator.pop(ctx);
                _removeTier(tierMeta);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameTierDialog(TierMeta tierMeta) {
    String newLabel = tierMeta.label;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename tier'),
        content: TextField(
          controller: TextEditingController(text: tierMeta.label),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'New name'),
          onChanged: (v) => newLabel = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (newLabel.trim().isEmpty) return;

              setState(() {
                final i = tiers.indexWhere((t) => t.id == tierMeta.id);
                tiers[i] = TierMeta(
                  id: tierMeta.id,
                  label: newLabel,
                  color: tierMeta.color, // keep colour unchanged
                );

                // keep legacy 'tier' label inside existing items in sync
                for (final it
                    in items.where((it) => it.tierId == tierMeta.id)) {
                  it.tier = newLabel;
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

  void _showChangeTierColorDialog(TierMeta tierMeta) {
    Color selected = tierMeta.color;
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
              setState(() => tierMeta.color = selected);
              Navigator.pop(ctx);
              _saveTierData();
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  void _showInsertTierDialog(TierMeta afterTier) {
    String label = '';
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
                decoration: const InputDecoration(labelText: 'Tier name'),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (v) => label = v,
              ),
              const SizedBox(height: 16),
              const Text('Select color'),
              BlockPicker(
                pickerColor: pick,
                onColorChanged: (c) => pick = c,
                availableColors: const [
                  Colors.white,
                  ...Colors.primaries,
                  Colors.black,
                  Colors.grey,
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (label.trim().isEmpty) return;

              setState(() {
                final pos = tiers.indexWhere((t) => t.id == afterTier.id);
                tiers.insert(
                  pos + 1,
                  TierMeta(
                    id: 0, // placeholder – _saveTierData() will
                    label: label, // renumber IDs top‑to‑bottom
                    color: pick,
                  ),
                );
              });

              Navigator.pop(ctx);
              _saveTierData(); // recalculates ids and persists
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );
  }

  void _moveTier(TierMeta tier, {required bool up}) {
    final i = tiers.indexWhere((t) => t.id == tier.id);
    final j = up ? i - 1 : i + 1;
    if (i < 0 || j < 0 || j >= tiers.length) return;

    setState(() {
      final moved = tiers.removeAt(i);
      tiers.insert(j, moved);
    });

    _saveTierData(); // renumbers ids (top = 1 …) and persists
  }

  void _removeTier(TierMeta tier) {
    setState(() {
      tiers.removeWhere((t) => t.id == tier.id);

      // Un‑assign every item that belonged to that tier
      for (final it in items.where((it) => it.tierId == tier.id)) {
        it.tierId = null;
        it.tier = null; // keep legacy label in sync
      }
    });

    _saveTierData(); // persists new tier list & ids
  }

  Future<void> _saveTierData() async {
    /* ---- build map: old‑id → new‑id ----------------------------------- */
    final Map<int, int> idMap = {};
    for (var i = 0; i < tiers.length; i++) {
      final oldId = tiers[i].id;
      final newId = i + 1;
      idMap[oldId] = newId;
      tiers[i] = TierMeta(
        // keep label & colour
        id: newId,
        label: tiers[i].label,
        color: tiers[i].color,
      );
    }

    /* ---- bump every item's tierId + tier label ------------------------ */
    for (final it in items) {
      if (it.tierId != null && idMap.containsKey(it.tierId)) {
        it.tierId = idMap[it.tierId]!;
        it.tier = tiers.firstWhere((t) => t.id == it.tierId).label; // text, too
      }
    }

    /* ---- persist ranks (same as before) ------------------------------- */
    final newRanks = tiers.map((t) => t.toJson()).toList();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tierLists');
    final List<dynamic> all =
        raw != null ? json.decode(raw) as List<dynamic> : <dynamic>[];

    final idx = all.indexWhere((e) => e['index'] == widget.index);
    if (idx != -1) {
      final entry = Map<String, dynamic>.from(all[idx]);
      entry['ranks'] = newRanks;
      all[idx] = entry;
    } else {
      all.add({'index': widget.index, 'ranks': newRanks});
    }
    await prefs.setString('tierLists', json.encode(all));

    widget.onForceRebuild();
    if (mounted) setState(() {});
    _saveAndNotifyItemUpdate(); // items now carry fresh ids & labels
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
