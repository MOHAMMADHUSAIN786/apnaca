import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/app_status_bar.dart';
import '../../../../database/app_database.dart';
import '../../model/expense_model.dart';
import 'add_expense_screen.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _categoryData = [];
  bool _isLoading = true;
  double _totalThisMonth = 0;
  double _totalAllTime = 0;
  late TabController _tabController;

  final List<Color> _catColors = const [
    Color(0xFF6C63FF), Color(0xFF00BCD4), Color(0xFFFF7043),
    Color(0xFF66BB6A), Color(0xFFFFCA28), Color(0xFFEC407A),
    Color(0xFF42A5F5), Color(0xFF26A69A), Color(0xFFAB47BC),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final expenses    = await AppDatabase.instance.getAllExpenses();
      final catData     = await AppDatabase.instance.getExpenseByCategory();
      final thisMonth   = await AppDatabase.instance.getTotalExpenseThisMonth();
      final allTime     = await AppDatabase.instance.getTotalExpenseAllTime();
      setState(() {
        _expenses       = expenses;
        _categoryData   = catData;
        _totalThisMonth = thisMonth;
        _totalAllTime   = allTime;
        _isLoading      = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(2)}L';
    if (amount >= 1000)   return '₹${(amount / 1000).toStringAsFixed(1)}K';
    return '₹${amount.toStringAsFixed(0)}';
  }

  String _formatDate(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AppStatusBarUtils(
      color: app_colors.table_header_bg,
      child: Scaffold(
        backgroundColor: app_colors.white,
        appBar: AppBar(
          backgroundColor: app_colors.table_header_bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Expense Management',
            style: TextStyle(
              fontFamily: app_fonts.Medium,
              fontSize: 16.sp,
              color: Colors.black,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black),
              onPressed: _loadData,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: app_colors.c_primary,
            unselectedLabelColor: Colors.black54,
            indicatorColor: app_colors.c_primary,
            labelStyle: TextStyle(fontFamily: app_fonts.Medium, fontSize: 13.sp),
            tabs: const [Tab(text: 'All Expenses'), Tab(text: 'By Category')],
          ),
        ),
        body: _buildBody(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
            );
            _loadData();
          },
          backgroundColor: app_colors.c_primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text('Add Expense',
              style: TextStyle(
                fontFamily: app_fonts.Medium,
                color: Colors.white,
                fontSize: 13.sp,
              )),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _buildSummaryCards(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildExpenseList(),
              _buildCategoryView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      color: app_colors.table_header_bg,
      child: Row(
        children: [
          Expanded(
            child: _summaryCard(
              label: 'This Month',
              amount: _totalThisMonth,
              color: const Color(0xFFFF7043),
              icon: Icons.calendar_month,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _summaryCard(
              label: 'All Time',
              amount: _totalAllTime,
              color: const Color(0xFF6C63FF),
              icon: Icons.account_balance_wallet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      fontFamily: app_fonts.Regular,
                      fontSize: 10.sp,
                      color: Colors.black54,
                    )),
                Text(
                  _formatAmount(amount),
                  style: TextStyle(
                    fontFamily: app_fonts.Bold,
                    fontSize: 14.sp,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseList() {
    if (_expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
            SizedBox(height: 12.h),
            Text('No expenses yet',
                style: TextStyle(
                  fontFamily: app_fonts.Regular,
                  fontSize: 14.sp,
                  color: Colors.grey,
                )),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        itemCount: _expenses.length,
        itemBuilder: (ctx, i) {
          final e = _expenses[i];
          final category = e['category'] as String? ?? '';
          final colorIdx = ExpenseModel.categories.indexOf(category);
          final color = colorIdx >= 0
              ? _catColors[colorIdx % _catColors.length]
              : _catColors[i % _catColors.length];
          return _expenseTile(e, color);
        },
      ),
    );
  }

  Widget _expenseTile(Map<String, dynamic> e, Color color) {
    final amount   = (e['amount'] as num?)?.toDouble() ?? 0;
    final category = e['category'] as String? ?? '';
    final date     = _formatDate(e['date'] as String? ?? '');
    final notes    = e['notes'] as String?;
    final id       = e['id'] as int;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
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
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
        leading: Container(
          width: 40.w,
          height: 40.w,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(Icons.receipt_outlined, color: color, size: 20),
        ),
        title: Text(
          category,
          style: TextStyle(
            fontFamily: app_fonts.Medium,
            fontSize: 13.sp,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          notes != null && notes.isNotEmpty ? '$date • $notes' : date,
          style: TextStyle(
            fontFamily: app_fonts.Regular,
            fontSize: 11.sp,
            color: Colors.black45,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '₹${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontFamily: app_fonts.Bold,
                fontSize: 14.sp,
                color: const Color(0xFFFF7043),
              ),
            ),
            SizedBox(width: 4.w),
            GestureDetector(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Expense'),
                    content: Text('Delete "$category" ₹${amount.toStringAsFixed(0)}?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await AppDatabase.instance.deleteExpense(id);
                  _loadData();
                }
              },
              child: Icon(Icons.delete_outline, color: Colors.red.shade300, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryView() {
    if (_categoryData.isEmpty) {
      return Center(
        child: Text('No data',
            style: TextStyle(
              fontFamily: app_fonts.Regular,
              color: Colors.grey,
              fontSize: 14.sp,
            )),
      );
    }

    final total = _categoryData.fold<double>(
        0, (sum, e) => sum + ((e['total'] as num?)?.toDouble() ?? 0));

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      itemCount: _categoryData.length,
      itemBuilder: (ctx, i) {
        final cat    = _categoryData[i];
        final name   = cat['category'] as String? ?? '';
        final amt    = (cat['total'] as num?)?.toDouble() ?? 0;
        final count  = cat['count'] as int? ?? 0;
        final pct    = total > 0 ? amt / total : 0.0;
        final color  = _catColors[i % _catColors.length];

        return Container(
          margin: EdgeInsets.only(bottom: 10.h),
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
              Row(
                children: [
                  Container(
                    width: 10.w,
                    height: 10.w,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontFamily: app_fonts.Medium,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                  Text(
                    '₹${amt.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontFamily: app_fonts.Bold,
                      fontSize: 14.sp,
                      color: color,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              LinearProgressIndicator(
                value: pct.toDouble(),
                backgroundColor: color.withOpacity(0.1),
                color: color,
                minHeight: 4,
                borderRadius: BorderRadius.circular(4.r),
              ),
              SizedBox(height: 4.h),
              Text(
                '$count entries · ${(pct * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontFamily: app_fonts.Regular,
                  fontSize: 10.sp,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
