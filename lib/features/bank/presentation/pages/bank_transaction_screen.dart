import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../database/app_database.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/app_status_bar.dart';

class BankTransactionScreen extends StatefulWidget {
  final int bankAccountId;
  final String bankName;

  const BankTransactionScreen({super.key, required this.bankAccountId, required this.bankName});

  @override
  State<BankTransactionScreen> createState() => _BankTransactionScreenState();
}

class _BankTransactionScreenState extends State<BankTransactionScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await AppDatabase.instance.getBankTransactions(widget.bankAccountId);
    setState(() {
      _transactions = list;
      _loading = false;
    });
  }

  Future<void> _addTransaction(String type) async {
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final isDeposit = type == 'deposit';

    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Text(isDeposit ? 'Deposit Cash/Cheque' : 'Withdrawal/Payment', style: TextStyle(fontFamily: app_fonts.Bold, color: app_colors.title, fontSize: 18.sp)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField(amountCtrl, 'Amount', keyboardType: TextInputType.number),
            SizedBox(height: 12.h),
            _buildDialogField(refCtrl, 'Reference / UTR / Cheque No.'),
            SizedBox(height: 12.h),
            _buildDialogField(notesCtrl, 'Notes'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: app_fonts.Medium))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: isDeposit ? app_colors.GreenColor : app_colors.c_danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r))),
          onPressed: () => Navigator.pop(ctx, true), 
          child: Text('Save', style: TextStyle(color: app_colors.white, fontFamily: app_fonts.Bold))
        ),
      ],
    ));

    if (ok == true) {
      final amount = double.tryParse(amountCtrl.text.trim());
      if (amount != null && amount > 0) {
        await AppDatabase.instance.insertBankTransaction({
          'bank_account_id': widget.bankAccountId,
          'date': DateTime.now().toIso8601String().split('T')[0],
          'type': type,
          'amount': amount,
          'reference': refCtrl.text.trim(),
          'notes': notesCtrl.text.trim(),
        });
        _load();
      }
    }
  }

  Widget _buildDialogField(TextEditingController ctrl, String label, {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      ),
      style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppStatusBarUtils(
      color: app_colors.table_header_bg,
      child: Scaffold(
        backgroundColor: app_colors.white,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'No transactions yet.',
                          style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 16.sp, color: Colors.grey),
                        ),
                        SizedBox(height: 24.h),
                        ElevatedButton.icon(
                          onPressed: () => _addTransaction('deposit'),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Transaction'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 18, left: 8, right: 8, bottom: 80.h),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _transactions.length,
                            itemBuilder: (context, i) {
                              final t = _transactions[i];
                              final isDeposit = t['type'] == 'deposit';
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
                                  leading: CircleAvatar(
                                    backgroundColor: isDeposit ? app_colors.LightGreen : app_colors.RedColor,
                                    child: Icon(
                                      isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                                      color: isDeposit ? app_colors.GreenColor : app_colors.c_danger,
                                      size: 24.sp,
                                    ),
                                  ),
                                  title: Text(
                                    '₹${t['amount']}',
                                    style: TextStyle(fontFamily: app_fonts.Bold, fontSize: 18.sp, color: isDeposit ? app_colors.GreenColor : app_colors.c_danger),
                                  ),
                                  subtitle: Padding(
                                    padding: EdgeInsets.only(top: 4.h),
                                    child: Text(
                                      '${t['date']} | Ref: ${t['reference']?.isEmpty == true ? '-' : t['reference']}',
                                      style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 12.sp, color: Colors.grey.shade600),
                                    ),
                                  ),
                                  trailing: t['notes']?.isNotEmpty == true
                                      ? Text(t['notes'], style: TextStyle(fontFamily: app_fonts.Regular, fontSize: 12.sp, color: Colors.grey.shade500))
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: app_colors.button_bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
          onPressed: () => _addTransaction('deposit'),
          label: Text('Deposit In', style: TextStyle(color: app_colors.white, fontFamily: app_fonts.Bold, fontSize: 14.sp)),
          icon: Icon(Icons.add, color: app_colors.white, size: 24.sp),
        ),
      ),
    );
  }
}
