import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../database/app_database.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';

class CreateChallanScreen extends StatefulWidget {
  const CreateChallanScreen({super.key});

  @override
  State<CreateChallanScreen> createState() => _CreateChallanScreenState();
}

class _CreateChallanScreenState extends State<CreateChallanScreen> {
  final _driverCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _items = [];
  int? _selectedCustomer;
  final List<Map<String, dynamic>> _cart = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final customers = await AppDatabase.instance.getAllCustomers();
    final items = await AppDatabase.instance.getAllItems();
    setState(() {
      _customers = customers.map((e) => e.toMap()).toList();
      _items = items.map((e) => e.toMap()).toList();
      _loading = false;
    });
  }

  void _addItem() {
    setState(() {
      _cart.add({'item_id': null, 'qty': 1.0});
    });
  }

  Future<void> _save() async {
    if (_cart.isEmpty || _cart.any((e) => e['item_id'] == null || e['qty'] <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please add valid items to the challan.', style: TextStyle(fontFamily: app_fonts.Medium)), backgroundColor: app_colors.c_danger));
      return;
    }

    final challanNum = 'CH-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    final challanId = await AppDatabase.instance.insertChallan({
      'challan_number': challanNum,
      'customer_id': _selectedCustomer,
      'challan_date': DateTime.now().toIso8601String().split('T')[0],
      'driver_name': _driverCtrl.text.trim(),
      'vehicle_number': _vehicleCtrl.text.trim(),
      'status': 'pending',
      'notes': _notesCtrl.text.trim(),
    });

    for (var c in _cart) {
      final itemObj = _items.firstWhere((element) => element['id'] == c['item_id']);
      await AppDatabase.instance.insertChallanItem({
        'challan_id': challanId,
        'item_id': itemObj['id'],
        'item_name': itemObj['name'],
        'qty': c['qty'],
      });
    }

    if (mounted) Navigator.pop(context, true);
  }

  Widget _buildTextField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp, fontFamily: app_fonts.Regular),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: const BorderSide(color: app_colors.border_color)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: const BorderSide(color: app_colors.border_color)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: const BorderSide(color: app_colors.c_primary)),
      ),
      style: TextStyle(fontSize: 14.sp, fontFamily: app_fonts.Medium),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: app_colors.c_primary)));

    return Scaffold(
      backgroundColor: app_colors.backgroun_color,
      appBar: AppBar(
        backgroundColor: app_colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: app_colors.black),
        title: Text(
          'Create Challan',
          style: TextStyle(
            color: app_colors.title,
            fontFamily: app_fonts.Bold,
            fontSize: 18.sp,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: app_colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: app_colors.border_color),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    labelText: 'Select Customer (Optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  ),
                  value: _selectedCustomer,
                  items: _customers.map((e) => DropdownMenuItem<int>(
                    value: e['id'] as int,
                    child: Text(e['name'] ?? '', style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp)),
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedCustomer = val),
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(child: _buildTextField(_driverCtrl, 'Driver Name')),
                    SizedBox(width: 12.w),
                    Expanded(child: _buildTextField(_vehicleCtrl, 'Vehicle Number')),
                  ],
                ),
                SizedBox(height: 16.h),
                _buildTextField(_notesCtrl, 'Notes / Remarks'),
              ],
            ),
          ),
          
          SizedBox(height: 24.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Items', style: TextStyle(fontSize: 16.sp, fontFamily: app_fonts.Bold, color: app_colors.title)),
              TextButton.icon(
                onPressed: _addItem, 
                icon: Icon(Icons.add, color: app_colors.c_primary, size: 20.sp), 
                label: Text('Add Item', style: TextStyle(color: app_colors.c_primary, fontFamily: app_fonts.Medium, fontSize: 14.sp))
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ..._cart.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Container(
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: app_colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: app_colors.border_color),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      value: item['item_id'],
                      hint: Text('Select Item', style: TextStyle(fontSize: 12.sp, fontFamily: app_fonts.Regular)),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.r)),
                      ),
                      items: _items.map((e) => DropdownMenuItem<int>(
                        value: e['id'] as int,
                        child: Text(e['name'] ?? '', style: TextStyle(fontSize: 12.sp, fontFamily: app_fonts.Medium)),
                      )).toList(),
                      onChanged: (val) => setState(() => _cart[idx]['item_id'] = val),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: TextFormField(
                      initialValue: item['qty'].toString(),
                      decoration: InputDecoration(
                        labelText: 'Qty',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.r)),
                      ),
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 12.sp, fontFamily: app_fonts.Medium),
                      onChanged: (val) => setState(() => _cart[idx]['qty'] = double.tryParse(val) ?? 1.0),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: app_colors.c_danger, size: 20.sp),
                    onPressed: () => setState(() => _cart.removeAt(idx)),
                  )
                ],
              ),
            );
          }),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: app_colors.button_bg,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            onPressed: _save,
            child: Text('Save Challan', style: TextStyle(fontSize: 16.sp, fontFamily: app_fonts.Bold, color: app_colors.white)),
          ),
        ),
      ),
    );
  }
}
