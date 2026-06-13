import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../database/app_database.dart';
import '../../model/expense_model.dart';

class AddExpenseScreen extends StatefulWidget {
  final Map<String, dynamic>? existingExpense;
  const AddExpenseScreen({super.key, this.existingExpense});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _amountCtrl    = TextEditingController();
  final _notesCtrl     = TextEditingController();

  String _selectedCategory = ExpenseModel.categories.first;
  DateTime _selectedDate   = DateTime.now();
  bool _isSaving           = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existingExpense;
    if (e != null) {
      _selectedCategory = e['category'] as String? ?? _selectedCategory;
      _amountCtrl.text  = (e['amount'] as num?)?.toString() ?? '';
      _notesCtrl.text   = e['notes'] as String? ?? '';
      _selectedDate     = DateTime.tryParse(e['date'] as String? ?? '') ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: app_colors.c_primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final data = {
      'category':   _selectedCategory,
      'amount':     double.tryParse(_amountCtrl.text.trim()) ?? 0,
      'date':       _selectedDate.toIso8601String().split('T')[0],
      'notes':      _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final existing = widget.existingExpense;
      if (existing != null) {
        await AppDatabase.instance.updateExpense(data, existing['id'] as int);
      } else {
        await AppDatabase.instance.insertExpense(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Expense saved!'),
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
          widget.existingExpense != null ? 'Edit Expense' : 'Add Expense',
          style: TextStyle(
            fontFamily: app_fonts.Medium,
            fontSize: 16.sp,
            color: Colors.black,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            _sectionLabel('Category'),
            SizedBox(height: 8.h),
            _buildCategoryPicker(),
            SizedBox(height: 16.h),
            _sectionLabel('Amount (₹)'),
            SizedBox(height: 8.h),
            _buildAmountField(),
            SizedBox(height: 16.h),
            _sectionLabel('Date'),
            SizedBox(height: 8.h),
            _buildDatePicker(),
            SizedBox(height: 16.h),
            _sectionLabel('Notes (Optional)'),
            SizedBox(height: 8.h),
            _buildNotesField(),
            SizedBox(height: 32.h),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          fontFamily: app_fonts.Medium,
          fontSize: 12.sp,
          color: Colors.black54,
          letterSpacing: 0.5,
        ),
      );

  Widget _buildCategoryPicker() {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: ExpenseModel.categories.map((cat) {
        final isSelected = cat == _selectedCategory;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: isSelected ? app_colors.c_primary : Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: isSelected ? app_colors.c_primary : Colors.grey.shade200,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: app_colors.c_primary.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : [],
            ),
            child: Text(
              cat,
              style: TextStyle(
                fontFamily: app_fonts.Regular,
                fontSize: 12.sp,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      validator: (v) {
        if (v == null || v.isEmpty) return 'Amount required';
        if (double.tryParse(v) == null) return 'Invalid amount';
        if (double.parse(v) <= 0) return 'Amount must be > 0';
        return null;
      },
      style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 15.sp),
      decoration: InputDecoration(
        prefixText: '₹ ',
        prefixStyle: TextStyle(
          fontFamily: app_fonts.Bold,
          fontSize: 15.sp,
          color: app_colors.c_primary,
        ),
        hintText: '0.00',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: app_colors.c_primary),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: app_colors.c_primary, size: 18),
            SizedBox(width: 10.w),
            Text(
              _formatDate(_selectedDate),
              style: TextStyle(
                fontFamily: app_fonts.Medium,
                fontSize: 14.sp,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesCtrl,
      maxLines: 3,
      style: TextStyle(fontFamily: app_fonts.Regular, fontSize: 13.sp),
      decoration: InputDecoration(
        hintText: 'Add notes here...',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: app_colors.c_primary),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 48.h,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: app_colors.c_primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          elevation: 2,
        ),
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(
                'Save Expense',
                style: TextStyle(
                  fontFamily: app_fonts.Medium,
                  fontSize: 15.sp,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
