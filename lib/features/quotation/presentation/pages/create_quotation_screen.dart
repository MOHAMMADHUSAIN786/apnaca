import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../database/app_database.dart';
import '../../../customer/model/customer_model.dart';
import '../../../item/model/item_model.dart';

class _CartItem {
  ItemModel item;
  double qty;
  double unitPrice;
  double taxRate;
  double discountAmount;

  _CartItem({
    required this.item,
    this.qty = 1,
    required this.unitPrice,
    this.taxRate = 0,
    this.discountAmount = 0,
  });

  double get taxAmount => (unitPrice * qty - discountAmount) * taxRate / 100;
  double get lineTotal  => unitPrice * qty - discountAmount + taxAmount;
}

class CreateQuotationScreen extends StatefulWidget {
  const CreateQuotationScreen({super.key});

  @override
  State<CreateQuotationScreen> createState() => _CreateQuotationScreenState();
}

class _CreateQuotationScreenState extends State<CreateQuotationScreen> {
  CustomerModel? _selectedCustomer;
  List<CustomerModel> _customers = [];
  List<ItemModel>     _items     = [];
  final List<_CartItem> _cart    = [];

  DateTime _quotationDate = DateTime.now();
  DateTime? _expiryDate;
  final _notesCtrl = TextEditingController();
  bool _isSaving   = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final customers = await AppDatabase.instance.getAllCustomers();
    final items     = await AppDatabase.instance.getAllItems();
    setState(() {
      _customers = customers;
      _items     = items;
    });
  }

  double get _subtotal => _cart.fold(0, (s, c) => s + c.unitPrice * c.qty - c.discountAmount);
  double get _gstTotal => _cart.fold(0, (s, c) => s + c.taxAmount);
  double get _total    => _subtotal + _gstTotal;

  void _addItem() {
    String? selectedItemId;
    final searchCtrl = TextEditingController();
    List<ItemModel> filtered = _items;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          height: MediaQuery.of(ctx).size.height * 0.6,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            children: [
              SizedBox(height: 12.h),
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.w),
                child: TextField(
                  controller: searchCtrl,
                  onChanged: (v) {
                    setBS(() {
                      filtered = _items
                          .where((i) => i.name.toLowerCase().contains(v.toLowerCase()))
                          .toList();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search item...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: const BorderSide(color: app_colors.c_primary),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final item = filtered[i];
                    return ListTile(
                      title: Text(item.name,
                          style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 13.sp)),
                      subtitle: Text('₹${item.price?.toStringAsFixed(0) ?? "0"} · Stock: ${item.qty ?? 0}',
                          style: TextStyle(fontFamily: app_fonts.Regular, fontSize: 11.sp, color: Colors.black45)),
                      trailing: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            final existing = _cart.indexWhere((c) => c.item.id == item.id);
                            if (existing >= 0) {
                              _cart[existing].qty++;
                            } else {
                              _cart.add(_CartItem(
                                item:      item,
                                unitPrice: item.price ?? 0,
                              ));
                            }
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: app_colors.c_primary,
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                        ),
                        child: Text('Add',
                            style: TextStyle(color: Colors.white, fontSize: 12.sp)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final quotNum = await AppDatabase.instance.generateQuotationNumber();
      final quotId  = await AppDatabase.instance.insertQuotation({
        'quotation_number': quotNum,
        'customer_id':      _selectedCustomer?.id,
        'customer_name':    _selectedCustomer?.name,
        'quotation_date':   _quotationDate.toIso8601String().split('T')[0],
        'expiry_date':      _expiryDate?.toIso8601String().split('T')[0],
        'tax_type':         'exclusive',
        'discount_type':    'none',
        'discount_value':   0,
        'discount_amount':  0,
        'subtotal':         _subtotal,
        'gst_amount':       _gstTotal,
        'total_amount':     _total,
        'status':           'draft',
        'notes':            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'created_at':       DateTime.now().toIso8601String(),
      });
      for (final c in _cart) {
        await AppDatabase.instance.insertQuotationItem({
          'quotation_id':    quotId,
          'item_id':         c.item.id,
          'item_name':       c.item.name,
          'qty':             c.qty,
          'unit_price':      c.unitPrice,
          'discount_amount': c.discountAmount,
          'tax_rate':        c.taxRate,
          'tax_amount':      c.taxAmount,
          'line_total':      c.lineTotal,
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Quotation $quotNum created!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isSaving = false);
  }

  String _formatDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: app_colors.table_header_bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Quotation',
          style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 16.sp, color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(
              'Save',
              style: TextStyle(
                fontFamily: app_fonts.Bold,
                fontSize: 14.sp,
                color: _isSaving ? Colors.grey : app_colors.c_primary,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(14.w),
        children: [
          _buildCustomerSection(),
          SizedBox(height: 12.h),
          _buildDateSection(),
          SizedBox(height: 12.h),
          _buildCartSection(),
          SizedBox(height: 12.h),
          _buildTotalSection(),
          SizedBox(height: 12.h),
          _buildNotesSection(),
          SizedBox(height: 80.h),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                fontFamily: app_fonts.Medium,
                fontSize: 12.sp,
                color: Colors.black54,
              )),
          SizedBox(height: 10.h),
          child,
        ],
      ),
    );
  }

  Widget _buildCustomerSection() {
    return _sectionCard(
      title: 'CUSTOMER (OPTIONAL)',
      child: DropdownButtonFormField<CustomerModel>(
        value: _selectedCustomer,
        decoration: InputDecoration(
          hintText: 'Select customer...',
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: const BorderSide(color: app_colors.c_primary),
          ),
        ),
        items: [
          const DropdownMenuItem<CustomerModel>(value: null, child: Text('Walk-in Customer')),
          ..._customers.map((c) => DropdownMenuItem(value: c, child: Text(c.name))),
        ],
        onChanged: (v) => setState(() => _selectedCustomer = v),
      ),
    );
  }

  Widget _buildDateSection() {
    return _sectionCard(
      title: 'DATES',
      child: Row(
        children: [
          Expanded(
            child: _dateTile(
              label: 'Quote Date',
              date: _quotationDate,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _quotationDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => _quotationDate = picked);
              },
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _dateTile(
              label: 'Expiry Date',
              date: _expiryDate,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => _expiryDate = picked);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateTile({required String label, required DateTime? date, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontFamily: app_fonts.Regular, fontSize: 10.sp, color: Colors.black45)),
            SizedBox(height: 4.h),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 12, color: app_colors.c_primary),
                SizedBox(width: 4.w),
                Text(
                  date != null ? _formatDate(date) : 'Select',
                  style: TextStyle(
                    fontFamily: app_fonts.Medium,
                    fontSize: 12.sp,
                    color: date != null ? Colors.black87 : Colors.black38,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSection() {
    return _sectionCard(
      title: 'ITEMS',
      child: Column(
        children: [
          ..._cart.asMap().entries.map((e) {
            final i    = e.key;
            final item = e.value;
            return Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FF),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.item.name,
                            style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 13.sp)),
                        Text('₹${item.unitPrice.toStringAsFixed(0)} × ${item.qty.toStringAsFixed(0)}',
                            style: TextStyle(fontFamily: app_fonts.Regular, fontSize: 11.sp, color: Colors.black45)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() {
                          if (item.qty > 1) item.qty--;
                          else _cart.removeAt(i);
                        }),
                        child: Container(
                          width: 26.w, height: 26.w,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.remove, size: 14),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(item.qty.toStringAsFixed(0),
                          style: TextStyle(fontFamily: app_fonts.Bold, fontSize: 14.sp)),
                      SizedBox(width: 8.w),
                      GestureDetector(
                        onTap: () => setState(() => item.qty++),
                        child: Container(
                          width: 26.w, height: 26.w,
                          decoration: BoxDecoration(
                            color: app_colors.c_primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, size: 14, color: Colors.white),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        '₹${item.lineTotal.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontFamily: app_fonts.Bold,
                          fontSize: 13.sp,
                          color: app_colors.c_primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: 8.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add, size: 16),
              label: Text('Add Item',
                  style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 13.sp)),
              style: OutlinedButton.styleFrom(
                foregroundColor: app_colors.c_primary,
                side: const BorderSide(color: app_colors.c_primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                padding: EdgeInsets.symmetric(vertical: 10.h),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2490EF), Color(0xFF1A6BB5)],
        ),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          _totalRow('Subtotal', '₹${_subtotal.toStringAsFixed(2)}', bold: false),
          SizedBox(height: 6.h),
          _totalRow('GST', '₹${_gstTotal.toStringAsFixed(2)}', bold: false),
          SizedBox(height: 8.h),
          const Divider(color: Colors.white30),
          SizedBox(height: 8.h),
          _totalRow('Total Amount', '₹${_total.toStringAsFixed(2)}', bold: true),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {required bool bold}) {
    final style = TextStyle(
      fontFamily: bold ? app_fonts.Bold : app_fonts.Regular,
      fontSize: bold ? 16.sp : 13.sp,
      color: Colors.white,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }

  Widget _buildNotesSection() {
    return _sectionCard(
      title: 'NOTES (OPTIONAL)',
      child: TextFormField(
        controller: _notesCtrl,
        maxLines: 3,
        style: TextStyle(fontFamily: app_fonts.Regular, fontSize: 13.sp),
        decoration: InputDecoration(
          hintText: 'Terms & conditions, notes...',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: const BorderSide(color: app_colors.c_primary),
          ),
        ),
      ),
    );
  }
}
