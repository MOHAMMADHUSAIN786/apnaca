// lib/features/sale/presentation/pages/create_sale_bill_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../database/app_database.dart';
import '../../../../features/ai_chat/service/bill_pdf_service.dart';
import '../../../customer/model/customer_model.dart';
import '../../../item/model/item_model.dart';

class CreateSaleBillScreen extends StatefulWidget {
  final VoidCallback? onBillCreated;
  const CreateSaleBillScreen({super.key, this.onBillCreated});

  @override
  State<CreateSaleBillScreen> createState() => _CreateSaleBillScreenState();
}

class _CreateSaleBillScreenState extends State<CreateSaleBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = AppDatabase.instance;

  // ── Controllers ──────────────────────────────────────────────────
  final _customerController = TextEditingController();
  final _notesController = TextEditingController();
  final _discountValueController = TextEditingController(text: '0');

  // ── State ─────────────────────────────────────────────────────────
  List<CustomerModel> _allCustomers = [];
  List<CustomerModel> _filteredCustomers = [];
  CustomerModel? _selectedCustomer;
  bool _showCustomerDropdown = false;

  List<ItemModel> _allItems = [];
  List<_BillItemRow> _itemRows = [];

  String _taxType = 'exclusive'; // exclusive / inclusive / none
  double _taxRate = 0.0;
  String _discountType = 'none'; // none / percent / amount
  String _paymentMode = 'cash';
  String _paymentStatus = 'paid';

  DateTime _billDate = DateTime.now();
  bool _isSaving = false;

  // ── Computed ──────────────────────────────────────────────────────
  double get _subtotal => _itemRows.fold(0, (s, r) => s + r.lineTotal);

  double get _discountAmount {
    final val = double.tryParse(_discountValueController.text) ?? 0;
    if (_discountType == 'percent') return _subtotal * val / 100;
    if (_discountType == 'amount') return val;
    return 0;
  }

  double get _taxableAmount => _subtotal - _discountAmount;

  double get _gstAmount {
    if (_taxType == 'none' || _taxRate == 0) return 0;
    if (_taxType == 'exclusive') return _taxableAmount * _taxRate / 100;
    // inclusive → tax already inside
    return _taxableAmount - (_taxableAmount * 100 / (100 + _taxRate));
  }

  double get _total {
    if (_taxType == 'inclusive') return _taxableAmount;
    return _taxableAmount + _gstAmount;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _customerController.addListener(_onCustomerTyped);
  }

  Future<void> _loadData() async {
    final customers = await _db.getAllCustomers();
    final items = await _db.getAllItems();
    setState(() {
      _allCustomers = customers;
      _allItems = items;
      _itemRows = [_BillItemRow(allItems: _allItems)];
    });
  }

  void _onCustomerTyped() {
    final q = _customerController.text.toLowerCase();
    setState(() {
      _selectedCustomer = null;
      _showCustomerDropdown = q.isNotEmpty;
      _filteredCustomers = q.isEmpty
          ? []
          : _allCustomers.where((c) => c.name.toLowerCase().contains(q)).toList();
    });
  }

  void _selectCustomer(CustomerModel c) {
    _customerController.text = c.name;
    setState(() {
      _selectedCustomer = c;
      _showCustomerDropdown = false;
      _filteredCustomers = [];
    });
  }

  void _addItemRow() {
    setState(() => _itemRows.add(_BillItemRow(allItems: _allItems)));
  }

  void _removeItemRow(int index) {
    if (_itemRows.length > 1) setState(() => _itemRows.removeAt(index));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: app_colors.c_primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _billDate = picked);
  }

  Future<void> _saveBill() async {
    if (!_formKey.currentState!.validate()) return;
    final validItems = _itemRows.where((r) => r.selectedItem != null && r.qty > 0).toList();
    if (validItems.isEmpty) {
      _showSnack('Kam se kam ek item add karein', isError: true);
      return;
    }
    if (_customerController.text.trim().isEmpty) {
      _showSnack('Customer naam enter karein', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      // ── Customer resolve ──────────────────────────────────────────
      int? customerId = _selectedCustomer?.id;
      String customerName = _customerController.text.trim();
      if (customerId == null && customerName.isNotEmpty) {
        // Create walk-in customer if not found
        var existing = await _db.getCustomerByName(customerName);
        if (existing == null) {
          final id = await _db.insertCustomer(CustomerModel(name: customerName));
          customerId = id;
        } else {
          customerId = existing.id;
        }
      }

      // ── Bill number ───────────────────────────────────────────────
      final billNumber = await _db.generateBillNumber();
      final dateStr = _billDate.toIso8601String().split('T')[0];

      // ── Insert bill ───────────────────────────────────────────────
      final discountVal = double.tryParse(_discountValueController.text) ?? 0;
      final billId = await _db.insertSaleBill({
        'bill_number': billNumber,
        'customer_id': customerId,
        'bill_date': dateStr,
        'tax_type': _taxType == 'none' ? 'exclusive' : _taxType,
        'discount_type': _discountType,
        'discount_value': discountVal,
        'discount_amount': _discountAmount,
        'subtotal': _subtotal,
        'gst_amount': _gstAmount,
        'total_amount': _total,
        'payment_mode': _paymentMode,
        'payment_status': _paymentStatus,
        'notes': _notesController.text.trim(),
      });

      // ── Insert items + deduct stock ───────────────────────────────
      for (final row in validItems) {
        final item = row.selectedItem!;
        await _db.insertSaleBillItem({
          'bill_id': billId,
          'item_id': item.id,
          'item_name': item.name,
          'qty': row.qty,
          'unit_price': row.price,
          'discount_amount': 0,
          'tax_rate': _taxRate,
          'tax_amount': row.lineTotal * _taxRate / 100,
          'line_total': row.lineTotal,
        });
        if (item.id != null) {
          await _db.deductItemStock(item.id!, row.qty);
        }
      }

      if (!mounted) return;
      _showSnack('✅ Bill $billNumber bana diya!');
      widget.onBillCreated?.call();

      // ── Ask PDF share ─────────────────────────────────────────────
      _askPdfShare(billId: billId, billNumber: billNumber,
          customerName: customerName, dateStr: dateStr, validItems: validItems);

    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _askPdfShare({
    required int billId,
    required String billNumber,
    required String customerName,
    required String dateStr,
    required List<_BillItemRow> validItems,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: app_colors.Dbackgroun_color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Bill Ready!',
            style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 16.sp)),
        content: Text('$billNumber PDF download karein?',
            style: TextStyle(fontSize: 13.sp, fontFamily: app_fonts.Regular)),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            child: Text('Skip', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: app_colors.table_header_bg,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _sharePdf(billNumber: billNumber, customerName: customerName,
                  dateStr: dateStr, validItems: validItems);
              if (mounted) Navigator.pop(context);
            },
            child: Text('Download PDF',
                style: TextStyle(color: app_colors.black, fontFamily: app_fonts.Medium)),
          ),
        ],
      ),
    );
  }

  Future<void> _sharePdf({
    required String billNumber,
    required String customerName,
    required String dateStr,
    required List<_BillItemRow> validItems,
  }) async {
    final billDetail = {
      'Bill No': billNumber,
      'Customer': customerName,
      'Date': dateStr,
      'Payment': _paymentMode,
      'Status': _paymentStatus,
      'Subtotal': '₹${_subtotal.toStringAsFixed(2)}',
      'GST': '₹${_gstAmount.toStringAsFixed(2)}',
      'Total': '₹${_total.toStringAsFixed(2)}',
      'Notes': _notesController.text.trim(),
    };
    final lineItems = validItems.map((r) => {
      'item': r.selectedItem!.name,
      'qty': r.qty,
      'price': '₹${r.price.toStringAsFixed(2)}',
      'tax': '₹0.00',
      'total': '₹${r.lineTotal.toStringAsFixed(2)}',
    }).toList();
    await BillPdfService.generateAndShare(billDetail: billDetail, lineItems: lineItems);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? app_colors.c_danger : app_colors.GreenColor,
    ));
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: app_colors.table_header_bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('New Sale Bill',
            style: TextStyle(fontSize: 18.sp, fontFamily: app_fonts.Medium, color: Colors.black)),
        actions: [
          if (_isSaving)
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: const Center(child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))),
            )
          else
            TextButton.icon(
              onPressed: _saveBill,
              icon: const Icon(Icons.check, color: Colors.black, size: 18),
              label: Text('Save',
                  style: TextStyle(color: Colors.black, fontFamily: app_fonts.Medium, fontSize: 14.sp)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            _sectionCard(
              title: 'Bill Details',
              icon: Icons.receipt_long,
              iconBg: app_colors.LightBlue,
              children: [
                _buildCustomerField(),
                SizedBox(height: 14.h),
                _buildDatePicker(),
                SizedBox(height: 14.h),
                _buildTextField(
                  controller: _notesController,
                  label: 'Notes (optional)',
                  icon: Icons.notes,
                  maxLines: 2,
                ),
              ],
            ),

            SizedBox(height: 14.h),

            _sectionCard(
              title: 'Items',
              icon: Icons.inventory_2_outlined,
              iconBg: Colors.orange.shade50,
              trailing: TextButton.icon(
                onPressed: _addItemRow,
                icon: Icon(Icons.add, size: 16, color: app_colors.c_primary),
                label: Text('Add Item',
                    style: TextStyle(color: app_colors.c_primary, fontSize: 12.sp,
                        fontFamily: app_fonts.Medium)),
              ),
              children: [
                ..._itemRows.asMap().entries.map((e) => _buildItemRow(e.key, e.value)),
              ],
            ),

            SizedBox(height: 14.h),

            _sectionCard(
              title: 'Tax & Discount',
              icon: Icons.percent,
              iconBg: app_colors.LightGreen,
              children: [
                _buildTaxSection(),
                SizedBox(height: 14.h),
                _buildDiscountSection(),
              ],
            ),

            SizedBox(height: 14.h),

            _sectionCard(
              title: 'Payment',
              icon: Icons.payment,
              iconBg: app_colors.LightOrange,
              children: [
                _buildPaymentSection(),
              ],
            ),

            SizedBox(height: 14.h),

            // ── Bill Summary ───────────────────────────────────────
            _buildSummaryCard(),

            SizedBox(height: 80.h),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: app_colors.Dborder_color)),
        ),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveBill,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: app_colors.table_header_bg,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
          ),
          child: _isSaving
              ? const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.black),
              SizedBox(width: 8.w),
              Text('Create Sale Bill',
                  style: TextStyle(fontSize: 16.sp, fontFamily: app_fonts.Medium,
                      color: Colors.black)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Customer search field ─────────────────────────────────────────
  Widget _buildCustomerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _customerController,
          validator: (v) => v == null || v.trim().isEmpty ? 'Customer naam required' : null,
          decoration: _inputDeco(label: 'Customer Name', icon: Icons.person_outline),
          style: TextStyle(fontSize: 14.sp),
        ),
        if (_showCustomerDropdown && _filteredCustomers.isNotEmpty)
          Container(
            margin: EdgeInsets.only(top: 2.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: app_colors.Dborder_color),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
            ),
            constraints: BoxConstraints(maxHeight: 160.h),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _filteredCustomers.length,
              itemBuilder: (ctx, i) {
                final c = _filteredCustomers[i];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14.r,
                    backgroundColor: app_colors.table_header_bg,
                    child: Text(c.name[0].toUpperCase(),
                        style: TextStyle(fontSize: 12.sp, fontFamily: app_fonts.Bold)),
                  ),
                  title: Text(c.name, style: TextStyle(fontSize: 13.sp, fontFamily: app_fonts.Medium)),
                  subtitle: c.phone != null
                      ? Text(c.phone!, style: TextStyle(fontSize: 11.sp)) : null,
                  onTap: () => _selectCustomer(c),
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Date picker ───────────────────────────────────────────────────
  Widget _buildDatePicker() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: app_colors.Dborder_color),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 20, color: Colors.grey.shade600),
            SizedBox(width: 12.w),
            Text('Bill Date', style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade500)),
            const Spacer(),
            Text(
              '${_billDate.day.toString().padLeft(2, '0')} '
                  '${_monthName(_billDate.month)} ${_billDate.year}',
              style: TextStyle(fontSize: 14.sp, fontFamily: app_fonts.Medium),
            ),
            SizedBox(width: 6.w),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // ── Item row ──────────────────────────────────────────────────────
  Widget _buildItemRow(int index, _BillItemRow row) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: app_colors.Dbackgroun_color,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: app_colors.Dborder_color),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('Item ${index + 1}',
                  style: TextStyle(fontSize: 12.sp, fontFamily: app_fonts.Medium,
                      color: Colors.grey.shade600)),
              const Spacer(),
              if (_itemRows.length > 1)
                GestureDetector(
                  onTap: () => _removeItemRow(index),
                  child: Icon(Icons.remove_circle_outline, color: app_colors.c_danger, size: 20),
                ),
            ],
          ),
          SizedBox(height: 8.h),

          // Item name autocomplete
          _ItemSearchField(
            allItems: _allItems,
            initialValue: row.selectedItem?.name ?? '',
            onItemSelected: (item) {
              setState(() {
                row.selectedItem = item;
                if (item.price != null && item.price! > 0) row.price = item.price!;
                row.availableQty = item.qty ?? 0;
              });
            },
          ),
          SizedBox(height: 10.h),

          Row(
            children: [
              // Qty
              Expanded(
                child: _SmallField(
                  label: 'Qty',
                  icon: Icons.numbers,
                  keyboardType: TextInputType.number,
                  initialValue: row.qty > 0 ? row.qty.toString() : '',
                  suffix: row.availableQty > 0
                      ? Text('/${row.availableQty}',
                      style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade500))
                      : null,
                  onChanged: (v) => setState(() => row.qty = int.tryParse(v) ?? 0),
                ),
              ),
              SizedBox(width: 10.w),
              // Price
              Expanded(
                child: _SmallField(
                  label: 'Price ₹',
                  icon: Icons.currency_rupee,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  initialValue: row.price > 0 ? row.price.toStringAsFixed(2) : '',
                  onChanged: (v) => setState(() => row.price = double.tryParse(v) ?? 0),
                ),
              ),
            ],
          ),

          if (row.selectedItem != null && row.qty > 0)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Line Total: ',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
                  Text('₹${row.lineTotal.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 13.sp, fontFamily: app_fonts.Medium,
                          color: app_colors.c_primary)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Tax section ───────────────────────────────────────────────────
  Widget _buildTaxSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tax Type', style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600,
            fontFamily: app_fonts.Medium)),
        SizedBox(height: 8.h),
        Row(
          children: [
            _chipOption(label: 'None', selected: _taxType == 'none',
                onTap: () => setState(() { _taxType = 'none'; _taxRate = 0; })),
            SizedBox(width: 8.w),
            _chipOption(label: 'Exclusive', selected: _taxType == 'exclusive',
                onTap: () => setState(() => _taxType = 'exclusive')),
            SizedBox(width: 8.w),
            _chipOption(label: 'Inclusive', selected: _taxType == 'inclusive',
                onTap: () => setState(() => _taxType = 'inclusive')),
          ],
        ),
        if (_taxType != 'none') ...[
          SizedBox(height: 12.h),
          Row(
            children: [
              _rateChip('0%', 0), SizedBox(width: 6.w),
              _rateChip('5%', 5), SizedBox(width: 6.w),
              _rateChip('12%', 12), SizedBox(width: 6.w),
              _rateChip('18%', 18), SizedBox(width: 6.w),
              _rateChip('28%', 28),
            ],
          ),
        ],
      ],
    );
  }

  Widget _rateChip(String label, double rate) {
    final sel = _taxRate == rate;
    return GestureDetector(
      onTap: () => setState(() => _taxRate = rate),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: sel ? app_colors.c_primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: sel ? app_colors.c_primary : app_colors.Dborder_color),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12.sp, color: sel ? Colors.white : Colors.black87,
                fontFamily: app_fonts.Medium)),
      ),
    );
  }

  // ── Discount section ──────────────────────────────────────────────
  Widget _buildDiscountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Discount', style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600,
            fontFamily: app_fonts.Medium)),
        SizedBox(height: 8.h),
        Row(
          children: [
            _chipOption(label: 'None', selected: _discountType == 'none',
                onTap: () => setState(() { _discountType = 'none'; _discountValueController.text = '0'; })),
            SizedBox(width: 8.w),
            _chipOption(label: '% Percent', selected: _discountType == 'percent',
                onTap: () => setState(() => _discountType = 'percent')),
            SizedBox(width: 8.w),
            _chipOption(label: '₹ Amount', selected: _discountType == 'amount',
                onTap: () => setState(() => _discountType = 'amount')),
          ],
        ),
        if (_discountType != 'none') ...[
          SizedBox(height: 12.h),
          TextFormField(
            controller: _discountValueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: _inputDeco(
              label: _discountType == 'percent' ? 'Discount %' : 'Discount Amount ₹',
              icon: Icons.discount_outlined,
            ),
          ),
        ],
      ],
    );
  }

  // ── Payment section ───────────────────────────────────────────────
  Widget _buildPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment Mode', style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600,
            fontFamily: app_fonts.Medium)),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w, runSpacing: 8.h,
          children: ['cash', 'upi', 'card', 'bank', 'credit', 'udhaar'].map((mode) =>
              _chipOption(
                label: mode.toUpperCase(),
                selected: _paymentMode == mode,
                onTap: () => setState(() {
                  _paymentMode = mode;
                  _paymentStatus = (mode == 'credit' || mode == 'udhaar') ? 'unpaid' : 'paid';
                }),
              )).toList(),
        ),
        SizedBox(height: 14.h),
        Text('Payment Status', style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600,
            fontFamily: app_fonts.Medium)),
        SizedBox(height: 8.h),
        Row(
          children: [
            _chipOption(label: '✅ Paid', selected: _paymentStatus == 'paid',
                onTap: () => setState(() => _paymentStatus = 'paid')),
            SizedBox(width: 8.w),
            _chipOption(label: '❌ Unpaid', selected: _paymentStatus == 'unpaid',
                color: _paymentStatus == 'unpaid' ? app_colors.RedColor : null,
                selectedBorder: app_colors.c_danger,
                onTap: () => setState(() => _paymentStatus = 'unpaid')),
            SizedBox(width: 8.w),
            _chipOption(label: '🕐 Partial', selected: _paymentStatus == 'partial',
                color: _paymentStatus == 'partial' ? app_colors.LightOrange : null,
                selectedBorder: app_colors.OrangeColor,
                onTap: () => setState(() => _paymentStatus = 'partial')),
          ],
        ),
      ],
    );
  }

  // ── Summary card ──────────────────────────────────────────────────
  Widget _buildSummaryCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: app_colors.Dbackgroun_color,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: app_colors.Dborder_color),
      ),
      child: Column(
        children: [
          _summaryRow('Subtotal', '₹${_subtotal.toStringAsFixed(2)}'),
          if (_discountAmount > 0)
            _summaryRow('Discount', '- ₹${_discountAmount.toStringAsFixed(2)}',
                color: app_colors.c_danger),
          if (_gstAmount > 0)
            _summaryRow('GST (${_taxRate.toStringAsFixed(0)}%)', '₹${_gstAmount.toStringAsFixed(2)}'),
          Divider(height: 20.h, color: app_colors.Dborder_color),
          _summaryRow('Total', '₹${_total.toStringAsFixed(2)}',
              isBold: true, color: app_colors.c_primary),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Text(label, style: TextStyle(
              fontSize: isBold ? 15.sp : 13.sp,
              fontFamily: isBold ? app_fonts.Bold : app_fonts.Regular,
              color: Colors.black87)),
          const Spacer(),
          Text(value, style: TextStyle(
              fontSize: isBold ? 16.sp : 13.sp,
              fontFamily: isBold ? app_fonts.Bold : app_fonts.Medium,
              color: color ?? Colors.black87)),
        ],
      ),
    );
  }

  // ── Section card wrapper ──────────────────────────────────────────
  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Color iconBg,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: app_colors.Dbackgroun_color,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: app_colors.Dborder_color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10.r)),
                child: Icon(icon, size: 18, color: Colors.black87),
              ),
              SizedBox(width: 10.w),
              Text(title, style: TextStyle(fontSize: 15.sp, fontFamily: app_fonts.Medium)),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          SizedBox(height: 14.h),
          ...children,
        ],
      ),
    );
  }

  Widget _chipOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? color,
    Color? selectedBorder,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? (color ?? app_colors.table_header_bg) : Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: selected ? (selectedBorder ?? app_colors.c_primary) : app_colors.Dborder_color,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.sp,
                fontFamily: selected ? app_fonts.Medium : app_fonts.Regular,
                color: Colors.black87)),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(fontSize: 14.sp),
      decoration: _inputDeco(label: label, icon: icon),
    );
  }

  InputDecoration _inputDeco({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
      prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade600),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: app_colors.Dborder_color),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: app_colors.table_header_bg, width: 1.6),
      ),
    );
  }

  String _monthName(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ][m];

  @override
  void dispose() {
    _customerController.dispose();
    _notesController.dispose();
    _discountValueController.dispose();
    super.dispose();
  }
}

// ════════════════════════════════════════════════════════════════════
//  Item row data model
// ════════════════════════════════════════════════════════════════════
class _BillItemRow {
  final List<ItemModel> allItems;
  ItemModel? selectedItem;
  int qty;
  double price;
  int availableQty;

  _BillItemRow({required this.allItems, this.qty = 1, this.price = 0, this.availableQty = 0});

  double get lineTotal => qty * price;
}

// ════════════════════════════════════════════════════════════════════
//  Item search autocomplete widget
// ════════════════════════════════════════════════════════════════════
class _ItemSearchField extends StatefulWidget {
  final List<ItemModel> allItems;
  final String initialValue;
  final ValueChanged<ItemModel> onItemSelected;
  const _ItemSearchField({required this.allItems, required this.initialValue,
    required this.onItemSelected});

  @override
  State<_ItemSearchField> createState() => _ItemSearchFieldState();
}

class _ItemSearchFieldState extends State<_ItemSearchField> {
  final _ctrl = TextEditingController();
  List<ItemModel> _filtered = [];
  bool _showDrop = false;

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.initialValue;
    _ctrl.addListener(_onType);
  }

  void _onType() {
    final q = _ctrl.text.toLowerCase();
    setState(() {
      _showDrop = q.isNotEmpty;
      _filtered = widget.allItems.where((i) => i.name.toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: _ctrl,
          style: TextStyle(fontSize: 14.sp),
          decoration: InputDecoration(
            labelText: 'Item Name',
            labelStyle: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
            prefixIcon: Icon(Icons.inventory_2_outlined, size: 20, color: Colors.grey.shade600),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: app_colors.Dborder_color),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: app_colors.table_header_bg, width: 1.6),
            ),
          ),
        ),
        if (_showDrop && _filtered.isNotEmpty)
          Container(
            margin: EdgeInsets.only(top: 2.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: app_colors.Dborder_color),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, 2))],
            ),
            constraints: BoxConstraints(maxHeight: 150.h),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) {
                final item = _filtered[i];
                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 32.w, height: 32.h,
                    decoration: BoxDecoration(
                      color: app_colors.table_header_bg,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Center(child: Icon(Icons.inventory_2_outlined, size: 16, color: Colors.black87)),
                  ),
                  title: Text(item.name, style: TextStyle(fontSize: 13.sp, fontFamily: app_fonts.Medium)),
                  subtitle: Text(
                    '₹${item.price?.toStringAsFixed(2) ?? '0'} | Stock: ${item.qty ?? 0}',
                    style: TextStyle(fontSize: 11.sp),
                  ),
                  trailing: item.qty != null && item.qty! <= 5
                      ? Text('Low', style: TextStyle(fontSize: 10.sp, color: app_colors.c_danger,
                      fontFamily: app_fonts.Bold))
                      : null,
                  onTap: () {
                    _ctrl.text = item.name;
                    setState(() { _showDrop = false; _filtered = []; });
                    widget.onItemSelected(item);
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
}

// ════════════════════════════════════════════════════════════════════
//  Small inline text field for qty/price
// ════════════════════════════════════════════════════════════════════
class _SmallField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final Widget? suffix;

  const _SmallField({
    required this.label, required this.icon, this.keyboardType,
    required this.initialValue, required this.onChanged, this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(fontSize: 13.sp),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
        prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade600),
        suffixIcon: suffix != null ? Padding(
            padding: EdgeInsets.only(right: 8.w), child: suffix!) : null,
        suffixIconConstraints: const BoxConstraints(),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: app_colors.Dborder_color),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: app_colors.table_header_bg, width: 1.4),
        ),
      ),
    );
  }
}