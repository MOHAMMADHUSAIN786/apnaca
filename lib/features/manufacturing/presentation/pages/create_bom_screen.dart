import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../database/app_database.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';

class CreateBomScreen extends StatefulWidget {
  const CreateBomScreen({super.key});

  @override
  State<CreateBomScreen> createState() => _CreateBomScreenState();
}

class _CreateBomScreenState extends State<CreateBomScreen> {
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  
  List<Map<String, dynamic>> _allItems = [];
  int? _finishedItemId;
  
  final List<Map<String, dynamic>> _rawItems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await AppDatabase.instance.getAllItems();
    setState(() {
      _allItems = items.map((e) => e.toMap()).toList();
      _loading = false;
    });
  }

  void _addRawItem() {
    setState(() {
      _rawItems.add({'item_id': null, 'qty': 1.0});
    });
  }

  void _save() async {
    if (_nameCtrl.text.isEmpty || _finishedItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and Finished Item are required.')));
      return;
    }
    if (_rawItems.isEmpty || _rawItems.any((e) => e['item_id'] == null || e['qty'] <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add valid raw materials.')));
      return;
    }

    final bomId = await AppDatabase.instance.insertBom({
      'name': _nameCtrl.text.trim(),
      'finished_item_id': _finishedItemId,
      'notes': _notesCtrl.text.trim(),
    });

    for (var r in _rawItems) {
      await AppDatabase.instance.insertBomItem({
        'bom_id': bomId,
        'raw_item_id': r['item_id'],
        'qty': r['qty'],
      });
    }

    if (mounted) Navigator.pop(context, true);
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
          'Create BOM',
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
                _buildLabel('BOM Name'),
                _buildTextField(_nameCtrl, 'e.g. Standard Chair'),
                SizedBox(height: 16.h),
                _buildLabel('Finished Item'),
                SizedBox(height: 8.h),
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: const BorderSide(color: app_colors.border_color)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: const BorderSide(color: app_colors.border_color)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: const BorderSide(color: app_colors.c_primary)),
                  ),
                  items: _allItems.map((e) => DropdownMenuItem<int>(
                    value: e['id'] as int,
                    child: Text(e['name'] ?? '', style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp)),
                  )).toList(),
                  onChanged: (val) => setState(() => _finishedItemId = val),
                ),
                SizedBox(height: 16.h),
                _buildLabel('Notes'),
                _buildTextField(_notesCtrl, 'Any production remarks...'),
              ],
            ),
          ),
          
          SizedBox(height: 24.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Raw Materials', style: TextStyle(fontSize: 16.sp, fontFamily: app_fonts.Bold, color: app_colors.title)),
              TextButton.icon(
                onPressed: _addRawItem, 
                icon: Icon(Icons.add, color: app_colors.c_primary, size: 20.sp), 
                label: Text('Add Item', style: TextStyle(color: app_colors.c_primary, fontFamily: app_fonts.Medium, fontSize: 14.sp))
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ..._rawItems.asMap().entries.map((entry) {
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
                      hint: Text('Select Raw Material', style: TextStyle(fontSize: 12.sp, fontFamily: app_fonts.Regular)),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.r)),
                      ),
                      items: _allItems.where((i) => i['id'] != _finishedItemId).map((e) => DropdownMenuItem<int>(
                        value: e['id'] as int,
                        child: Text(e['name'] ?? '', style: TextStyle(fontSize: 12.sp)),
                      )).toList(),
                      onChanged: (val) => setState(() => _rawItems[idx]['item_id'] = val),
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
                      style: TextStyle(fontSize: 12.sp),
                      onChanged: (val) => setState(() => _rawItems[idx]['qty'] = double.tryParse(val) ?? 1.0),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: app_colors.c_danger, size: 20.sp),
                    onPressed: () => setState(() => _rawItems.removeAt(idx)),
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
            child: Text('Save BOM', style: TextStyle(fontSize: 16.sp, fontFamily: app_fonts.Bold, color: app_colors.white)),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(text, style: TextStyle(fontSize: 14.sp, fontFamily: app_fonts.Medium, color: app_colors.black)),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14.sp, fontFamily: app_fonts.Regular),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: const BorderSide(color: app_colors.border_color)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: const BorderSide(color: app_colors.border_color)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: const BorderSide(color: app_colors.c_primary)),
      ),
      style: TextStyle(fontSize: 14.sp, fontFamily: app_fonts.Medium),
    );
  }
}
