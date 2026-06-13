import 'package:flutter/material.dart';
import '../../../../database/app_database.dart';

class TransferScreen extends StatefulWidget {
  final int? fromWarehouseId;

  const TransferScreen({super.key, this.fromWarehouseId});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  int? _fromId;
  int? _toId;
  int? _itemId;
  final _qtyCtrl = TextEditingController();
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fromId = widget.fromWarehouseId;
    _loadData();
  }

  Future<void> _loadData() async {
    final wh = await AppDatabase.instance.getAllWarehouses();
    final items = (await AppDatabase.instance.getAllItems()).map((e) => e.toMap()).toList();
    setState(() {
      _warehouses = wh;
      _items = items;
      _loading = false;
    });
  }

  Future<void> _doTransfer() async {
    if (_fromId == null || _toId == null || _itemId == null) return;
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid qty')));
      return;
    }
    if (_fromId == _toId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose different warehouses')));
      return;
    }
    final ok = await AppDatabase.instance.transferStock(_fromId!, _toId!, _itemId!, qty);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer completed')));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient stock')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Transfer')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(children: [
                DropdownButtonFormField<int>(
                  value: _fromId,
                  hint: const Text('From warehouse'),
                  items: _warehouses.map((w) => DropdownMenuItem(value: w['id'] as int, child: Text(w['name'] ?? ''))).toList(),
                  onChanged: (v) => setState(() => _fromId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _toId,
                  hint: const Text('To warehouse'),
                  items: _warehouses.map((w) => DropdownMenuItem(value: w['id'] as int, child: Text(w['name'] ?? ''))).toList(),
                  onChanged: (v) => setState(() => _toId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _itemId,
                  hint: const Text('Item'),
                  items: _items.map((i) => DropdownMenuItem(value: i['id'] as int, child: Text(i['name'] ?? ''))).toList(),
                  onChanged: (v) => setState(() => _itemId = v),
                ),
                const SizedBox(height: 12),
                TextField(controller: _qtyCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity')),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: _doTransfer, child: const Text('Transfer'))
              ]),
            ),
    );
  }
}
