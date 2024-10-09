import 'package:flutter/material.dart';
import 'tier_list_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'debug_page.dart';
import 'themes/material_theme.dart';

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
  late SharedPreferences _prefs;
  String _searchQuery = '';
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  void _openDebugPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DebugPage()),
    );
  }

  void _forceRebuild(int index) {
    // Find the tier list data
    final tierListData = _tierLists.firstWhere((tl) => tl['index'] == index);
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _buildTierListPage(tierListData),
        settings: RouteSettings(arguments: index),
      ),
    );

    // Rebuild the page in the _tierListPages map
    //setState(() {
    //  _tierListPages[index] = _buildTierListPage(tierListData);
    //});
  }

  TierListPage _buildTierListPage(Map<String, dynamic> tierListData) {
    return TierListPage(
      key: ValueKey(tierListData['index']),
      name: tierListData['name'],
      index: tierListData['index'],
      hidden: tierListData['hidden'] ?? false,
      password: tierListData['password'] ?? tierListData['name'],
      onForceRebuild: () => _forceRebuild(tierListData['index']),
    );
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
    setState(() {
      _tierLists = List<Map<String, dynamic>>.from(
          json.decode(_prefs.getString('tierLists') ?? '[]'));
      for (var tierList in _tierLists) {
        _tierListPages[tierList['index']] = _buildTierListPage(tierList);
      }
    });
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
          title: Text('Options for ${_tierLists[index]['name']}'),
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
      await _tierListPages[deletedIndex]?.deleteAllContent();
      // Clear SharedPreferences data for the deleted tier list
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('customItems_$deletedIndex');
      await prefs.remove('customItems_${deletedIndex}_ranked');

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
          //backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Center(child: Text(widget.title)),
          actions: [
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: _openDebugPage,
              tooltip: 'Open Debug Page',
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              if (showSearchBar)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
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
                      //fillColor: Theme.of(context).colorScheme.inversePrimary,
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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  padding: const EdgeInsets.all(10),
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.view_list,
                              size: 50,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tierList['name'],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer),
                            ),
                          ],
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
}
