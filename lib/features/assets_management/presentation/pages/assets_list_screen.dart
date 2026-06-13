import 'package:flutter/material.dart';
import '../../../../database/app_database.dart';
import 'add_asset_screen.dart';

class AssetsListScreen extends StatefulWidget {
  const AssetsListScreen({super.key});

  @override
  State<AssetsListScreen> createState() => _AssetsListScreenState();
}

class _AssetsListScreenState extends State<AssetsListScreen> {
  List<Map<String, dynamic>> _assets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    setState(() => _isLoading = true);
    final assets = await AppDatabase.instance.getAllAssets();
    setState(() {
      _assets = assets;
      _isLoading = false;
    });
  }

  Future<void> _deleteAsset(int id) async {
    await AppDatabase.instance.deleteAsset(id);
    _loadAssets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Assets'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assets.isEmpty
              ? const Center(child: Text('No assets found. Click + to add one.'))
              : ListView.builder(
                  itemCount: _assets.length,
                  itemBuilder: (ctx, i) {
                    final asset = _assets[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          child: const Icon(Icons.inventory_2, color: Colors.blue),
                        ),
                        title: Text('${asset['name']} (${asset['category']})'),
                        subtitle: Text('Value: ₹${(asset['current_value'] as num?)?.toStringAsFixed(2)}\nDepreciation: ${asset['depreciation_pct']}%/yr'),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteAsset(asset['id']),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddAssetScreen()),
          );
          _loadAssets();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
