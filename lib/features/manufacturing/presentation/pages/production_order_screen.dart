import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../database/app_database.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';

class ProductionOrderScreen extends StatefulWidget {
  const ProductionOrderScreen({super.key});

  @override
  State<ProductionOrderScreen> createState() => _ProductionOrderScreenState();
}

class _ProductionOrderScreenState extends State<ProductionOrderScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await AppDatabase.instance.getAllProductionOrders();
    setState(() {
      _orders = list;
      _loading = false;
    });
  }

  Future<void> _completeOrder(int orderId) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Text('Complete Order?', style: TextStyle(fontFamily: app_fonts.Bold, color: app_colors.title, fontSize: 18.sp)),
      content: Text('This will deduct raw materials from inventory and add the finished goods. Proceed?', style: TextStyle(fontFamily: app_fonts.Regular, fontSize: 14.sp)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: app_fonts.Medium, fontSize: 14.sp))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: app_colors.button_bg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r))),
          onPressed: () => Navigator.pop(ctx, true), 
          child: Text('Complete', style: TextStyle(color: app_colors.white, fontFamily: app_fonts.Bold, fontSize: 14.sp))
        ),
      ],
    ));

    if (ok == true) {
      setState(() => _loading = true);
      await AppDatabase.instance.completeProductionOrder(orderId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order completed! Stock updated.', style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp)), backgroundColor: app_colors.success));
      await _load();
    }
  }

  Future<void> _createOrder() async {
    final boms = await AppDatabase.instance.getAllBoms();
    if (boms.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please create a BOM first.', style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp)), backgroundColor: app_colors.c_danger));
      return;
    }

    int? selectedBomId;
    final qtyCtrl = TextEditingController(text: '1');
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('New Production Order', style: TextStyle(fontFamily: app_fonts.Bold, color: app_colors.title, fontSize: 18.sp)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: 'Select BOM',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              ),
              items: boms.map((e) => DropdownMenuItem<int>(
                value: e['id'] as int,
                child: Text(e['name'] ?? '', style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp)),
              )).toList(),
              onChanged: (val) => setDialogState(() => selectedBomId = val),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: qtyCtrl,
              decoration: InputDecoration(
                labelText: 'Quantity to Produce',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: notesCtrl,
              decoration: InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: app_fonts.Medium))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: app_colors.button_bg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r))),
            onPressed: () => Navigator.pop(ctx, true), 
            child: Text('Create', style: TextStyle(color: app_colors.white, fontFamily: app_fonts.Bold))
          ),
        ],
      ),
    ));

    if (ok == true && selectedBomId != null) {
      final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
      await AppDatabase.instance.insertProductionOrder({
        'order_number': 'PROD-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
        'bom_id': selectedBomId,
        'qty_to_produce': qty,
        'order_date': DateTime.now().toIso8601String().split('T')[0],
        'notes': notesCtrl.text.trim(),
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: app_colors.backgroun_color,
      appBar: AppBar(
        backgroundColor: app_colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: app_colors.black),
        title: Text(
          'Production Orders',
          style: TextStyle(
            color: app_colors.title,
            fontFamily: app_fonts.Bold,
            fontSize: 18.sp,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: app_colors.c_primary))
          : _orders.isEmpty
              ? Center(child: Text('No production orders.', style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 16.sp, color: Colors.grey)))
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  itemCount: _orders.length,
                  itemBuilder: (context, i) {
                    final o = _orders[i];
                    final isCompleted = o['status'] == 'completed';
                    return Container(
                      margin: EdgeInsets.only(bottom: 12.h),
                      decoration: BoxDecoration(
                        color: app_colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: app_colors.border_color),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))
                        ],
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        title: Text(
                          '${o['order_number']} - ${o['bom_name']}',
                          style: TextStyle(fontFamily: app_fonts.Bold, fontSize: 15.sp, color: app_colors.title),
                        ),
                        subtitle: Padding(
                          padding: EdgeInsets.only(top: 4.h),
                          child: Text(
                            'Qty: ${o['qty_to_produce']} | Status: ${(o['status'] as String).toUpperCase()}',
                            style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 12.sp, color: isCompleted ? app_colors.success : app_colors.OrangeColor),
                          ),
                        ),
                        trailing: isCompleted
                            ? Icon(Icons.check_circle, color: app_colors.success, size: 28.sp)
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: app_colors.c_primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                ),
                                onPressed: () => _completeOrder(o['id'] as int),
                                child: Text('Complete', style: TextStyle(color: app_colors.white, fontFamily: app_fonts.Bold, fontSize: 12.sp)),
                              ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: app_colors.button_bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
        onPressed: _createOrder,
        label: Text('New Order', style: TextStyle(color: app_colors.white, fontFamily: app_fonts.Bold, fontSize: 14.sp)),
        icon: Icon(Icons.add, color: app_colors.white, size: 24.sp),
      ),
    );
  }
}
