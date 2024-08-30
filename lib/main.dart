import 'package:flutter/material.dart';
import 'tier_list_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
        _tierLists.add({'name': newTierListName, 'index': newIndex});
        _tierListPages[newIndex] = TierListPage(
          name: newTierListName,
          index: newIndex,
        );
      });
      await _saveTierLists();
    }
  }

  void _showOptionsDialog(int index) {
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

  void _deleteTierList(int index) {
    setState(() {
      int deletedIndex = _tierLists[index]['index'];
      _tierLists.removeAt(index);
      _tierListPages.remove(deletedIndex);
    });
    _saveTierLists();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        padding: const EdgeInsets.all(10),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      _tierListPages[_tierLists[index]['index']]!,
                ),
              );
            },
            onLongPress: () => _showOptionsDialog(index),
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
                    _tierLists[index]['name'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          );
        },
        itemCount: _tierLists.length,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewTierList,
        tooltip: 'Add new Tier List',
        child: const Icon(Icons.add),
      ),
    );
  }
}
