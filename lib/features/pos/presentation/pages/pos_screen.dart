import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:convert';
import '../../../../core/services/hardware_service.dart';
import '../../../../core/services/printer_service.dart';
import '../../../../database/app_database.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _cart = [];
  bool _loading = true;
  int? _warehouseId;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadWarehouse();
  }

  Future<void> _openPrinterSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('printer_ip') ?? '';
    final port = prefs.getInt('printer_port') ?? 9100;
    final ipCtrl = TextEditingController(text: ip);
    final portCtrl = TextEditingController(text: port.toString());
    
    List<BluetoothDevice> devices = [];
    try {
      devices = await BlueThermalPrinter.instance.getBondedDevices();
    } catch (_) {}

    final ok = await showDialog<bool>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Printer settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Network Printer', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: ipCtrl, decoration: const InputDecoration(labelText: 'Printer IP')),
              TextField(controller: portCtrl, decoration: const InputDecoration(labelText: 'Port'), keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              const Text('Bluetooth Printers (Paired)', style: TextStyle(fontWeight: FontWeight.bold)),
              ...devices.map((d) => ListTile(
                title: Text(d.name ?? 'Unknown'),
                subtitle: Text(d.address ?? ''),
                onTap: () async {
                  try {
                    await BlueThermalPrinter.instance.connect(d);
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Connected to ${d.name}')));
                  } catch (e) {
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Failed: $e')));
                  }
                },
              )).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save Network'))
        ],
      );
    });
    if (ok == true) {
      try {
        final p = int.parse(portCtrl.text.trim());
        await prefs.setString('printer_ip', ipCtrl.text.trim());
        await prefs.setInt('printer_port', p);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network Printer saved')));
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid port')));
      }
    }
  }

  Future<void> _loadWarehouse() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _warehouseId = prefs.getInt('current_warehouse_id');
    });
  }

  Future<void> _loadItems() async {
    final items = await AppDatabase.instance.getAllItems();
    setState(() {
      _items = items.map((i) => i.toMap()).toList();
      _loading = false;
    });
  }

  void _filterItems(String q) {
    setState(() {
      _search = q.trim().toLowerCase();
    });
  }

  void _addToCart(Map<String, dynamic> item) {
    final idx = _cart.indexWhere((c) => c['item_id'] == item['id']);
    if (idx >= 0) {
      _cart[idx]['qty'] = (_cart[idx]['qty'] as int) + 1;
    } else {
      _cart.add({
        'item_id': item['id'],
        'item_name': item['name'],
        'qty': 1,
        'unit_price': (item['price'] as num?)?.toDouble() ?? 0.0,
        'tax_rate': 0,
        'tax_amount': 0,
        'line_total': (item['price'] as num?)?.toDouble() ?? 0.0,
      });
    }
    setState(() {});
  }

  double _cartTotal() {
    return _cart.fold<double>(0, (s, c) => s + (c['unit_price'] as double) * (c['qty'] as int));
  }

  Future<void> _checkout([String paymentMode = 'cash']) async {
    if (_cart.isEmpty) return;
    final db = AppDatabase.instance;
    final billNumber = await db.generateBillNumber();
    final subtotal = _cartTotal();
    final gstAmount = 0.0;
    final total = subtotal + gstAmount;

    final billId = await db.insertSaleBill({
      'bill_number': billNumber,
      'customer_id': null,
      if (_warehouseId != null) 'warehouse_id': _warehouseId,
      'bill_date': DateTime.now().toIso8601String().split('T')[0],
      'tax_type': 'exclusive',
      'discount_type': 'none',
      'discount_value': 0,
      'discount_amount': 0,
      'subtotal': subtotal,
      'gst_amount': gstAmount,
      'total_amount': total,
      'payment_mode': paymentMode,
      'payment_status': 'paid',
    });

    for (final line in _cart) {
      await db.insertSaleBillItem({
        'bill_id': billId,
        'item_id': line['item_id'],
        'item_name': line['item_name'],
        'qty': line['qty'],
        'unit_price': line['unit_price'],
        'tax_rate': 0,
        'tax_amount': 0,
        'line_total': (line['unit_price'] as double) * (line['qty'] as int),
      });
    }

    // enqueue outbox for offline sync
    try {
      await AppDatabase.instance.addOutbox('sale_bill', 'create', jsonEncode({'bill_id': billId, 'bill_number': billNumber}));
    } catch (_) {}

    // show receipt preview and print if user confirms
    try {
      final nowStr = DateTime.now().toIso8601String();
      final receiptText = PrinterService.instance.formatReceipt(
        shopName: 'My Shop',
        billNumber: billNumber,
        date: nowStr,
        items: _cart,
        subtotal: subtotal,
        taxAmount: gstAmount,
        total: total,
      );
      final bytes = PrinterService.instance.formatReceiptBytes(
        shopName: 'My Shop',
        billNumber: billNumber,
        date: nowStr,
        items: _cart,
        subtotal: subtotal,
        taxAmount: gstAmount,
        total: total,
      );

      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Receipt Preview'),
          content: SingleChildScrollView(child: Text(receiptText, style: const TextStyle(fontFamily: 'monospace'))),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Close')),
            ElevatedButton(
              onPressed: () async {
                var printed = false;
                
                // Try bluetooth first
                final btConnected = await BlueThermalPrinter.instance.isConnected;
                if (btConnected == true) {
                  printed = await PrinterService.instance.printBytesToBluetooth(bytes);
                }

                // Fallback to network
                if (!printed) {
                  final prefs = await SharedPreferences.getInstance();
                  final ip = prefs.getString('printer_ip') ?? '';
                  final port = prefs.getInt('printer_port') ?? 9100;
                  if (ip.isNotEmpty) {
                    printed = await PrinterService.instance.printBytesToNetworkPrinter(ip, port, bytes);
                  }
                }

                if (!printed) await HardwareService.instance.printReceipt(receiptText);
                if (paymentMode == 'cash') await HardwareService.instance.openCashDrawer();
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              },
              child: const Text('Print'),
            ),
          ],
        ),
      );
    } catch (_) {}

    setState(() {
      _cart.clear();
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('POS'), actions: [
        IconButton(
          tooltip: 'Printer settings',
          icon: const Icon(Icons.print),
          onPressed: _openPrinterSettings,
        ),
        IconButton(
          tooltip: 'Scan barcode',
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: () async {
            final code = await HardwareService.instance.scanBarcode(context: context);
            if (code != null && code.isNotEmpty) {
              final match = _items.firstWhere(
                (i) {
                  final name = (i['name'] as String?)?.toLowerCase() ?? '';
                  final barcode = (i['barcode'] as String?) ?? '';
                  return barcode == code || name.contains(code.toLowerCase());
                },
                orElse: () => {},
              );
              if (match.isNotEmpty) _addToCart(match);
            }
          },
        )
      ]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : Row(
        children: [
          // left: items
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search items'),
                    onChanged: _filterItems,
                  ),
                ),
                Expanded(
                  child: GridView.count(
              crossAxisCount: 3,
                  children: _items
                      .where((i) => _search.isEmpty ? true : ((i['name'] as String?)?.toLowerCase() ?? '').contains(_search))
                      .map((i) => Card(
                child: InkWell(
                  onTap: () => _addToCart(i),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(i['name'] ?? ''),
                        const SizedBox(height: 8),
                        Text('₹${(i['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}')
                      ],
                    ),
                  ),
                ),
                  )).toList(),
            ),
                ),
              ],
            ),
          ),
          // right: cart
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (context, i) {
                      final c = _cart[i];
                      return ListTile(
                        title: Text(c['item_name']),
                        subtitle: Text('Qty: ${c['qty']}  •  ₹${(c['unit_price'] as double).toStringAsFixed(2)}'),
                        trailing: Text('₹${((c['unit_price'] as double) * (c['qty'] as int)).toStringAsFixed(2)}'),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [Text('Total'), Text('₹${_cartTotal().toStringAsFixed(2)}')],
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final selected = await showModalBottomSheet<String>(
                            context: context,
                            builder: (ctx) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(title: const Text('Cash'), onTap: () => Navigator.of(ctx).pop('cash')),
                                ListTile(title: const Text('Card'), onTap: () => Navigator.of(ctx).pop('card')),
                                ListTile(title: const Text('UPI'), onTap: () => Navigator.of(ctx).pop('upi')),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ElevatedButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
                                )
                              ],
                            ),
                          );
                          if (selected != null) await _checkout(selected);
                        },
                        child: const Text('Pay & Save'))
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
