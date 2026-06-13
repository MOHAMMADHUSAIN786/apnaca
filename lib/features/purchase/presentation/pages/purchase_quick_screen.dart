import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../database/app_database.dart';
import '../../../item/model/item_model.dart';

class PurchaseQuickScreen extends StatefulWidget {
  const PurchaseQuickScreen({super.key});

  @override
  State<PurchaseQuickScreen> createState() => _PurchaseQuickScreenState();
}

class _PurchaseQuickScreenState extends State<PurchaseQuickScreen> {
  final _itemController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  int? _warehouseId;

  @override
  void initState() {
    super.initState();
    _loadWarehouse();
  }

  Future<void> _loadWarehouse() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _warehouseId = prefs.getInt('current_warehouse_id');
    });
  }

  Future<void> _saveQuickPurchase() async {
    final itemName = _itemController.text.trim();
    final qty = int.tryParse(_qtyController.text) ?? 1;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    if (itemName.isEmpty) return;

    // find or create item
    var item = await AppDatabase.instance.getItemByName(itemName);
    if (item == null) {
      final id = await AppDatabase.instance.insertItem(
          ItemModel(name: itemName, qty: 0, price: price));
      item = await AppDatabase.instance.getItemById(id);
    }
    final billNumber = await AppDatabase.instance.generatePurchaseBillNumber();
    final billId = await AppDatabase.instance.insertPurchaseBill({
      'bill_number': billNumber,
      'supplier_id': null,
      if (_warehouseId != null) 'warehouse_id': _warehouseId,
      'bill_date': DateTime.now().toIso8601String().split('T')[0],
      'subtotal': (price * qty),
      'tax_amount': 0,
      'total_amount': (price * qty),
      'payment_mode': 'cash',
      'payment_status': 'paid',
    });

    await AppDatabase.instance.insertPurchaseBillItem({
      'bill_id': billId,
      'item_id': item!.id,
      'item_name': item.name,
      'qty': qty,
      'unit_price': price,
      'tax_rate': 0,
      'tax_amount': 0,
      'line_total': price * qty,
    });

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Purchase')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _itemController, decoration: const InputDecoration(labelText: 'Item name')),
            TextField(controller: _qtyController, decoration: const InputDecoration(labelText: 'Qty'), keyboardType: TextInputType.number),
            TextField(controller: _priceController, decoration: const InputDecoration(labelText: 'Unit Price'), keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _saveQuickPurchase, child: const Text('Save Purchase'))
          ],
        ),
      ),
    );
  }
}
