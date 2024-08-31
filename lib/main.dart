import 'package:flutter/material.dart';
import 'tier_list_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rank Everything Always',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.dark(
          primary: Colors.grey[700]!, // buttons n shit
          inversePrimary: Colors.grey[800]!, // appbar
        ),
        scaffoldBackgroundColor: Colors.grey[900]!, // background?
      ),
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

  @override
  void initState() {
    super.initState();
    _loadTierLists();
  }

  Future<void> _loadTierLists() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _tierLists = List<Map<String, dynamic>>.from(
          json.decode(_prefs.getString('tierLists') ?? '[]'));
      for (var tierList in _tierLists) {
        _tierListPages[tierList['index']] = TierListPage(
          name: tierList['name'],
          index: tierList['index'],
          hidden: tierList['hidden'] ?? false,
          password: tierList['password'] ?? tierList['name'],
        );
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
        _tierLists.add({
          'name': newTierListName,
          'index': newIndex,
          'hidden': false,
          'password': newTierListName,
        });
        _tierListPages[newIndex] = TierListPage(
          name: newTierListName,
          index: newIndex,
          hidden: false,
          password: newTierListName,
        );
      });
      await _saveTierLists();
    }
  }

  void _showOptionsDialog(int index) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (BuildContext context) {
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
        _tierListPages[_tierLists[index]['index']] = TierListPage(
          name: newName,
          index: _tierLists[index]['index'],
        );
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
      return _tierLists.where((tierList) => !tierList['hidden']).toList();
    }
    return _tierLists.where((tierList) {
      if (!tierList['hidden']) {
        return tierList['name']
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());
      } else {
        return tierList['password'].toLowerCase() == _searchQuery.toLowerCase();
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Center(child: Text(widget.title)),
      ),
      body: Column(
        children: [
          if (_tierLists.length >= 2)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search tier lists...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            _tierListPages[tierList['index']]!,
                      ),
                    );
                  },
                  onLongPress: () => _showOptionsDialog(_tierLists.indexWhere(
                      (item) => item['index'] == tierList['index'])),
                  child: Container(
                    color: Colors.grey[800],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.view_list,
                          size: 50,
                          color: Colors.brown,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tierList['name'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewTierList,
        tooltip: 'Add new Tier List',
        child: const Icon(Icons.add),
      ),
    );
  }
}
