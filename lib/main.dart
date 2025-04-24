import 'package:flutter/material.dart';
import 'tier_list_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'themes/material_theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rank Everything Always',
      theme: MaterialTheme.dark(),
      home: const MyHomePage(title: 'Rank Everything Always'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Map<String, dynamic>> _tierLists = [];
  final Map<int, TierListPage> _tierListPages = {};
  final Map<int, GlobalKey<TierListPageState>> _tierListKeys = {};
  late SharedPreferences _prefs;
  String _searchQuery = '';
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  Future<void> _forceRebuild(int index) async {
    await _loadTierLists(); // ← pull in the updated prefs
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _buildTierListPage(
            _tierLists.firstWhere((tl) => tl['index'] == index)),
        settings: RouteSettings(arguments: index),
      ),
    );
  }

  TierListPage _buildTierListPage(Map<String, dynamic> tierListData) {
    final key = GlobalKey<TierListPageState>();
    _tierListKeys[tierListData['index']] = key;
    return TierListPage(
      key: key,
      name: tierListData['name'],
      index: tierListData['index'],
      hidden: tierListData['hidden'] ?? false,
      password: tierListData['password'] ?? tierListData['name'],
      onForceRebuild: () => _forceRebuild(tierListData['index']),
    ); // Should also have imagePath?
  }

  @override
  void initState() {
    super.initState();
    _loadTierLists();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  void _unfocusSearchBar() {
    _searchFocusNode.unfocus();
  }

  Future<void> _loadTierLists() async {
    _prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> loadedTierLists =
        List<Map<String, dynamic>>.from(
            json.decode(_prefs.getString('tierLists') ?? '[]'));

    // Check and update cover photo paths
    for (var tierList in loadedTierLists) {
      if (tierList['coverPhoto'] != null) {
        final file = File(tierList['coverPhoto']);
        if (!await file.exists()) {
          tierList['coverPhoto'] = null;
        }
      }
    }

    setState(() {
      _tierLists = loadedTierLists;
      for (var tierList in _tierLists) {
        _tierListPages[tierList['index']] = _buildTierListPage(tierList);
      }
    });

    // Save the updated tier lists if any cover photos were nullified
    await _saveTierLists();
  }

  Future<void> _saveTierLists() async {
    await _prefs.setString('tierLists', json.encode(_tierLists));
  }

  void _addNewTierList() async {
    final String? newTierListName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String? itemName;
        return AlertDialog(
          title: const Text('Name Tier List'),
          content: TextField(
            onChanged: (value) {
              itemName = value;
            },
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Create'),
              onPressed: () {
                Navigator.of(context).pop(itemName);
              },
            ),
          ],
        );
      },
    );

    if (newTierListName != null && newTierListName.isNotEmpty) {
      setState(() {
        int newIndex = _tierLists.isEmpty ? 0 : _tierLists.last['index'] + 1;
        Map<String, dynamic> newTierList = {
          'name': newTierListName,
          'index': newIndex,
          'hidden': false,
          'password': newTierListName,
          'coverPhoto': null,
          'ranks': [
            {'id': 1, 'label': 'S', 'color': '#F44336'},
            {'id': 2, 'label': 'A', 'color': '#FF9800'},
            {'id': 3, 'label': 'B', 'color': '#FFC107'},
            {'id': 4, 'label': 'C', 'color': '#4CAF50'},
            {'id': 5, 'label': 'D', 'color': '#2196F3'},
            {'id': 6, 'label': 'E', 'color': '#3F51B5'},
            {'id': 7, 'label': 'F', 'color': '#673AB7'},
          ],
        };
        _tierLists.add(newTierList);
        _tierListPages[newIndex] = _buildTierListPage(newTierList);
      });
      await _saveTierLists();
    }
  }

  void _showOptionsDialog(int index) {
    _unfocusSearchBar(); // Add this line
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isHidden = _tierLists[index]['hidden'] ?? false;
        return AlertDialog(
          title: Text(_tierLists[index]['name']),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.pop(context);
                  _renameTierList(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Set Cover Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _setCoverPhoto(index);
                },
              ),
              ListTile(
                leading:
                    Icon(isHidden ? Icons.visibility : Icons.visibility_off),
                title: Text(isHidden ? 'Unhide' : 'Hide'),
                onTap: () {
                  Navigator.pop(context);
                  _toggleHiddenStatus(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteTierList(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleHiddenStatus(int index) async {
    bool currentlyHidden = _tierLists[index]['hidden'] ?? false;
    String? newPassword;

    if (!currentlyHidden) {
      // Going from unhidden to hidden, ask for a new password
      newPassword = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          String? password;
          bool obscureText = true;
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Hide List'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'To hide a list, give it a password. The list will only be visible '
                      'if you type the entire password in the search bar. ',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (value) {
                        password = value;
                      },
                      obscureText: obscureText,
                      decoration: InputDecoration(
                        hintText: 'Enter password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureText
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureText = !obscureText;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: const Text('Set'),
                    onPressed: () {
                      Navigator.of(context).pop(password);
                    },
                  ),
                ],
              );
            },
          );
        },
      );

      if (newPassword == null || newPassword.isEmpty) {
        // If no password is set, don't hide the list
        return;
      }
    }

    setState(() {
      _tierLists[index]['hidden'] = !currentlyHidden;
      int tierListIndex = _tierLists[index]['index'];

      if (currentlyHidden) {
        // Going from hidden to unhidden, set password to current name
        _tierLists[index]['password'] = _tierLists[index]['name'];
      } else {
        // Going from unhidden to hidden, set the new password
        _tierLists[index]['password'] = newPassword;
      }

      _tierListPages[tierListIndex] = _buildTierListPage(_tierLists[index]);
    });
    await _saveTierLists();
  }

  void _renameTierList(int index) async {
    final String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String? itemName = _tierLists[index]['name'];
        return AlertDialog(
          title: const Text('Rename Tier List'),
          content: TextField(
            onChanged: (value) {
              itemName = value;
            },
            textCapitalization: TextCapitalization.sentences,
            controller: TextEditingController(text: itemName),
            decoration: const InputDecoration(),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Rename'),
              onPressed: () {
                Navigator.of(context).pop(itemName);
              },
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty) {
      setState(() {
        _tierLists[index]['name'] = newName;
        _tierListPages[_tierLists[index]['index']] =
            _buildTierListPage(_tierLists[index]);
      });
      await _saveTierLists();
    }
  }

  void _deleteTierList(int index) async {
    // Show confirmation dialog
    bool confirmDelete = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Deletion'),
              content: Text(
                  'Are you sure you want to delete "${_tierLists[index]['name']}"? This action cannot be undone.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: const Text('Delete'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirmDelete) {
      int deletedIndex = _tierLists[index]['index'];
      await TierListPage.deleteAllContentStatic(deletedIndex);
      // Clear SharedPreferences data for the deleted tier list
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('customItems_$deletedIndex');

      setState(() {
        _tierLists.removeAt(index);
        _tierListPages.remove(deletedIndex);
      });
      await _saveTierLists();
    }
  }

  // This is the search logic
  List<Map<String, dynamic>> get _filteredTierLists {
    if (_searchQuery.isEmpty) {
      return _tierLists
          .where((tierList) => tierList['hidden'] != true)
          .toList();
    }
    return _tierLists.where((tierList) {
      bool isHidden = tierList['hidden'] ?? false;
      if (!isHidden) {
        return tierList['name']
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());
      } else {
        return (tierList['password'] ?? '').toLowerCase() ==
            _searchQuery.toLowerCase();
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    bool showSearchBar = _tierLists.length >= 9 ||
        _tierLists.any((list) => list['hidden'] == true);

    // Clear search query if search bar is hidden
    if (!showSearchBar && _searchQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _searchQuery = '';
        });
      });
    }

    return PopScope(
      canPop: _searchQuery.isEmpty,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          setState(() {
            _searchQuery = '';
            _searchController.clear();
          });
        }
        return;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Center(child: Text(widget.title)),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'backup':
                    _showBackupExplanation();
                    break;
                  case 'restore':
                    _showRestoreExplanation();
                    break;
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'backup',
                  child: Text('Backup My Tier Lists'),
                ),
                const PopupMenuItem<String>(
                  value: 'restore',
                  child: Text('Restore My Tier Lists'),
                ),
              ],
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              if (showSearchBar)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
                  child: TextField(
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Search tier lists...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(1),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.inversePrimary,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 14),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    controller: _searchController,
                    autofocus: false,
                  ),
                ),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 150, // Maximum width for each item
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    childAspectRatio: 0.84,
                  ),
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final tierList = _filteredTierLists[index];
                    return GestureDetector(
                      onTap: () {
                        _unfocusSearchBar();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                _tierListPages[tierList['index']]!,
                            maintainState: false,
                          ),
                        );
                      },
                      onLongPress: () => _showOptionsDialog(
                          _tierLists.indexWhere(
                              (item) => item['index'] == tierList['index'])),
                      child: Container(
                        color: Theme.of(context).colorScheme.inversePrimary,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final imageSize = constraints.maxWidth *
                                0.7; // Adjust this factor as needed
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image(
                                  image: tierList['coverPhoto'] != null
                                      ? FileImage(File(tierList['coverPhoto']))
                                      : const AssetImage(
                                              'assets/default_icon_2.png')
                                          as ImageProvider,
                                  width: imageSize,
                                  //height: imageSize,
                                  fit: BoxFit.cover,
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    tierList['name'],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                      fontSize:
                                          13, //constraints.maxWidth * 0.13,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    );
                  },
                  itemCount: _filteredTierLists.length,
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _unfocusSearchBar();
            _addNewTierList();
          },
          tooltip: 'Add new Tier List',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _setCoverPhoto(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = _tierLists[index]['index'];
    String? itemsJson = prefs.getString('customItems_$savedIndex');
    List<String> imagePaths = [];
    if (itemsJson != null) {
      List<dynamic> decodedItems = json.decode(itemsJson);
      imagePaths = decodedItems
          .where((item) =>
              item['imagePath'] != null) // Check for non-null imagePath
          .map((item) =>
              item['imagePath'] as String) // Directly extract imagePath
          .toList();
    } else {
      print("No items found");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No images here.')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Cover Image'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.list),
                  title: const Text('No Image'),
                  onTap: () async {
                    Navigator.pop(context);
                    setState(() {
                      _tierLists[index]['coverPhoto'] = null;
                    });
                    await _saveTierLists();
                  },
                ),
                const Divider(),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: imagePaths.length,
                    itemBuilder: (context, itemIndex) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _updateCoverPhoto(index, imagePaths[itemIndex]);
                        },
                        child: Image.file(
                          File(imagePaths[itemIndex]),
                          fit: BoxFit.cover,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _updateCoverPhoto(int index, String imagePath) async {
    setState(() {
      _tierLists[index]['coverPhoto'] = imagePath;
    });
    await _saveTierLists();
  }

  void _showBackupExplanation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Backup My Tier Lists'),
          content: const Text(
              'This will create a backup file of all your tier lists and images. '
              'You can use this file to restore your data on another device or if you need to reinstall the app.\n\n'
              'This has to be done manually by you since this app is free and cannot rely on servers that cost money.'),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(
                'Create Backup',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _exportData();
              },
            ),
          ],
        );
      },
    );
  }

  void _showRestoreExplanation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Restore My Tier Lists'),
          content: const Text(
              'This will restore your tier lists from a backup file. '
              'Use this when you\'re setting up the app on a new device.\n'
              'This has to be done manually by you since this app is free and cannot rely on servers that cost money.\n\n'
              'Look for a file called REA_123456.zip or something.\n\n'
              'Warning: This will replace all current tier lists with the ones from the backup.'),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(
                'Choose Backup File',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _importData();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportData() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Exporting data..."),
              ],
            ),
          );
        },
      );

      final tempDir = await getTemporaryDirectory();
      final zipFile = File(
          '${tempDir.path}/REA_${DateTime.now().millisecondsSinceEpoch}.zip');
      final archive = Archive();

      // Add tier lists data
      final tierListsJson = json.encode(_tierLists);
      archive.addFile(ArchiveFile(
          'tier_lists.json', tierListsJson.length, tierListsJson.codeUnits));

      // Set to keep track of unique image paths
      final Set<String> uniqueImagePaths = {};

      // Add custom items data for each tier list
      for (var tierList in _tierLists) {
        final index = tierList['index'];
        final customItems = await _getCustomItems(index);
        final customItemsJson = json.encode(customItems);
        archive.addFile(ArchiveFile('custom_items_$index.json',
            customItemsJson.length, customItemsJson.codeUnits));

        // Add cover photo path if exists
        if (tierList['coverPhoto'] != null) {
          uniqueImagePaths.add(tierList['coverPhoto']);
        }

        // Add image paths from custom items
        for (var item in customItems) {
          if (item['imagePath'] != null) {
            uniqueImagePaths.add(item['imagePath']);
          }
        }
      }

      // Add image files to the archive
      for (var imagePath in uniqueImagePaths) {
        final imageFile = File(imagePath);
        if (await imageFile.exists()) {
          final imageBytes = await imageFile.readAsBytes();
          final fileName = 'images/${path.basename(imagePath)}';
          archive.addFile(ArchiveFile(fileName, imageBytes.length, imageBytes));
        }
      }

      // Encode the archive to zip file
      final zipData = ZipEncoder().encode(archive);
      if (zipData != null) {
        await zipFile.writeAsBytes(zipData);

        // Close loading dialog
        Navigator.of(context).pop();

        // Share the file
        await Share.shareXFiles([XFile(zipFile.path)],
            text: 'Here is your exported tier list data');

        // Delete the temporary file after sharing
        await zipFile.delete();
      } else {
        throw Exception('Failed to encode zip file');
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export data: $e')),
      );
    }
  }

  Future<void> _importData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        // Clear existing data
        _tierLists.clear();
        _tierListPages.clear();
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        // Get app's local directory for storing images
        final appDir = await getApplicationDocumentsDirectory();
        // Delete existing images in the app directory
        final existingImages = appDir.listSync().whereType<File>().where(
            (file) =>
                file.path.toLowerCase().endsWith('.png') ||
                file.path.toLowerCase().endsWith('.jpg') ||
                file.path.toLowerCase().endsWith('.jpeg'));
        for (var file in existingImages) {
          await file.delete();
        }

        // Extract and save images
        for (final file in archive.files) {
          if (file.isFile && file.name.startsWith('images/')) {
            final newPath = '${appDir.path}/${path.basename(file.name)}';
            await File(newPath).writeAsBytes(file.content);
          }
        }

        // Import tier lists data
        final tierListsFile = archive.findFile('tier_lists.json');
        if (tierListsFile != null) {
          final tierListsJson = String.fromCharCodes(tierListsFile.content);
          _tierLists =
              List<Map<String, dynamic>>.from(json.decode(tierListsJson));

          // Update image paths in tier lists
          for (var tierList in _tierLists) {
            if (tierList['coverPhoto'] != null) {
              final oldPath = tierList['coverPhoto'];
              final newPath = '${appDir.path}/${path.basename(oldPath)}';
              tierList['coverPhoto'] = newPath;
            }
          }

          await _saveTierLists();
        }

        // Import custom items data for each tier list
        for (var tierList in _tierLists) {
          final index = tierList['index'];
          final customItemsFile = archive.findFile('custom_items_$index.json');
          if (customItemsFile != null) {
            final customItemsJson =
                String.fromCharCodes(customItemsFile.content);
            List<Map<String, dynamic>> customItems =
                List<Map<String, dynamic>>.from(json.decode(customItemsJson));

            // Update image paths in custom items
            for (var item in customItems) {
              if (item['imagePath'] != null) {
                final oldPath = item['imagePath'];
                final newPath = '${appDir.path}/${path.basename(oldPath)}';
                item['imagePath'] = newPath;
              }
            }

            await prefs.setString(
                'customItems_$index', json.encode(customItems));
          }

          _tierListPages[index] = _buildTierListPage(tierList);
        }

        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data imported successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import data: $e')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _getCustomItems(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final customItemsJson = prefs.getString('customItems_$index') ?? '[]';
    return List<Map<String, dynamic>>.from(json.decode(customItemsJson));
  }
}
