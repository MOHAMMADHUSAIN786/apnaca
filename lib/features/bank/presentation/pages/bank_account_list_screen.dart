import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../database/app_database.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/app_status_bar.dart';
import 'bank_transaction_screen.dart';

class BankAccountListScreen extends StatefulWidget {
  const BankAccountListScreen({super.key});

  @override
  State<BankAccountListScreen> createState() => _BankAccountListScreenState();
}

class _BankAccountListScreenState extends State<BankAccountListScreen> {
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await AppDatabase.instance.getAllBankAccounts();
    List<Map<String, dynamic>> enriched = [];
    for (var acc in list) {
      final balance = await AppDatabase.instance.getBankAccountBalance(acc['id'] as int);
      enriched.add({...acc, 'current_balance': balance});
    }

    setState(() {
      _accounts = enriched;
      _loading = false;
    });
  }

  Future<void> _addAccount() async {
    final bankNameCtrl = TextEditingController();
    final accNameCtrl = TextEditingController();
    final accNumCtrl = TextEditingController();
    final ifscCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0');

    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Text('Add Bank Account', style: TextStyle(fontFamily: app_fonts.Bold, color: app_colors.title, fontSize: 18.sp)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField(bankNameCtrl, 'Bank Name (e.g. HDFC / Cash Drawer)'),
            SizedBox(height: 12.h),
            _buildDialogField(accNameCtrl, 'Account Holder Name'),
            SizedBox(height: 12.h),
            _buildDialogField(accNumCtrl, 'Account Number (optional)'),
            SizedBox(height: 12.h),
            _buildDialogField(ifscCtrl, 'IFSC Code (optional)'),
            SizedBox(height: 12.h),
            _buildDialogField(balanceCtrl, 'Opening Balance', keyboardType: TextInputType.number),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: app_fonts.Medium))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: app_colors.button_bg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r))),
          onPressed: () => Navigator.pop(ctx, true), 
          child: Text('Save', style: TextStyle(color: app_colors.white, fontFamily: app_fonts.Bold))
        ),
      ],
    ));

    if (ok == true && bankNameCtrl.text.trim().isNotEmpty && accNameCtrl.text.trim().isNotEmpty) {
      await AppDatabase.instance.insertBankAccount({
        'bank_name': bankNameCtrl.text.trim(),
        'account_name': accNameCtrl.text.trim(),
        'account_number': accNumCtrl.text.trim(),
        'ifsc_code': ifscCtrl.text.trim(),
        'opening_balance': double.tryParse(balanceCtrl.text.trim()) ?? 0,
      });
      _load();
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
            : _accounts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.account_balance_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'No accounts added.',
                          style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 16.sp, color: Colors.grey),
                        ),
                        SizedBox(height: 24.h),
                        ElevatedButton.icon(
                          onPressed: _addAccount,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Account'),
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
                            itemCount: _accounts.length,
                            itemBuilder: (context, i) {
                              final a = _accounts[i];
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
                                    backgroundColor: app_colors.LightBlue,
                                    child: Icon(Icons.account_balance, color: app_colors.c_primary, size: 24.sp),
                                  ),
                                  title: Text(
                                    a['bank_name'],
                                    style: TextStyle(fontFamily: app_fonts.Bold, fontSize: 16.sp, color: app_colors.title),
                                  ),
                                  subtitle: Padding(
                                    padding: EdgeInsets.only(top: 4.h),
                                    child: Text(
                                      '${a['account_name']} ${a['account_number']?.isNotEmpty == true ? '- ${a['account_number']}' : ''}',
                                      style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 12.sp, color: Colors.grey.shade600),
                                    ),
                                  ),
                                  trailing: Text(
                                    '₹${(a['current_balance'] as double).toStringAsFixed(2)}',
                                    style: TextStyle(fontFamily: app_fonts.Bold, fontSize: 18.sp, color: app_colors.c_primary),
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BankTransactionScreen(
                                          bankAccountId: a['id'] as int,
                                          bankName: a['bank_name'],
                                        ),
                                      ),
                                    ).then((_) => _load());
                                  },
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
          onPressed: _addAccount,
          label: Text('Add Account', style: TextStyle(color: app_colors.white, fontFamily: app_fonts.Bold, fontSize: 14.sp)),
          icon: Icon(Icons.add, color: app_colors.white, size: 24.sp),
        ),
      ),
    );
  }
}
