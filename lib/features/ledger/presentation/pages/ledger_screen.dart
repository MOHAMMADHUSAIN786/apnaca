import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../database/app_database.dart';
import '../../../customer/model/customer_model.dart';
import '../../../supplier/model/supplier_model.dart';
import 'party_detail_screen.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<CustomerModel> _customers = [];
  List<SupplierModel> _suppliers = [];
  Map<int, double> _customerBalances = {};
  Map<int, double> _supplierBalances = {};
  bool _isLoading = true;
  String _searchQuery = '';

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
    final customers = await AppDatabase.instance.getAllCustomers();
    final suppliers = await AppDatabase.instance.getAllSuppliers();

    final cBalances = <int, double>{};
    for (final c in customers) {
      cBalances[c.id!] =
          await AppDatabase.instance.getPartyBalance('customer', c.id!);
    }
    final sBalances = <int, double>{};
    for (final s in suppliers) {
      sBalances[s.id!] =
          await AppDatabase.instance.getPartyBalance('supplier', s.id!);
    }

    setState(() {
      _customers        = customers;
      _suppliers        = suppliers;
      _customerBalances = cBalances;
      _supplierBalances = sBalances;
      _isLoading        = false;
    });
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
          'Party Ledger / Khata Book',
          style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 16.sp, color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(88.h),
          child: Column(
            children: [
              _buildSearchBar(),
              TabBar(
                controller: _tabController,
                labelColor: app_colors.c_primary,
                unselectedLabelColor: Colors.black54,
                indicatorColor: app_colors.c_primary,
                labelStyle: TextStyle(fontFamily: app_fonts.Medium, fontSize: 13.sp),
                tabs: const [Tab(text: 'Customers'), Tab(text: 'Suppliers')],
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPartyList(
                  parties: _customers
                      .where((c) => c.name.toLowerCase().contains(_searchQuery))
                      .toList(),
                  balances: _customerBalances,
                  partyType: 'customer',
                  getName: (p) => (p as CustomerModel).name,
                  getPhone: (p) => (p as CustomerModel).phone,
                  getId: (p) => (p as CustomerModel).id!,
                ),
                _buildPartyList(
                  parties: _suppliers
                      .where((s) => s.name.toLowerCase().contains(_searchQuery))
                      .toList(),
                  balances: _supplierBalances,
                  partyType: 'supplier',
                  getName: (p) => (p as SupplierModel).name,
                  getPhone: (p) => (p as SupplierModel).phone,
                  getId: (p) => (p as SupplierModel).id!,
                ),
              ],
            ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        style: TextStyle(fontFamily: app_fonts.Regular, fontSize: 13.sp),
        decoration: InputDecoration(
          hintText: 'Search party...',
          prefixIcon: const Icon(Icons.search, size: 18),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildPartyList({
    required List<dynamic> parties,
    required Map<int, double> balances,
    required String partyType,
    required String Function(dynamic) getName,
    required String? Function(dynamic) getPhone,
    required int Function(dynamic) getId,
  }) {
    if (parties.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 60, color: Colors.grey.shade300),
            SizedBox(height: 12.h),
            Text('No parties found',
                style: TextStyle(
                  fontFamily: app_fonts.Regular,
                  fontSize: 14.sp,
                  color: Colors.grey,
                )),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      itemCount: parties.length,
      itemBuilder: (ctx, i) {
        final party   = parties[i];
        final id      = getId(party);
        final balance = balances[id] ?? 0.0;
        final name    = getName(party);
        final phone   = getPhone(party);
        final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PartyDetailScreen(
                  partyId:   id,
                  partyType: partyType,
                  partyName: name,
                ),
              ),
            );
            _loadData();
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 8.h),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
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
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: app_colors.c_primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontFamily: app_fonts.Bold,
                        fontSize: 16.sp,
                        color: app_colors.c_primary,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                // Name + phone
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontFamily: app_fonts.Medium,
                          fontSize: 14.sp,
                          color: Colors.black87,
                        ),
                      ),
                      if (phone != null && phone.isNotEmpty)
                        Text(
                          phone,
                          style: TextStyle(
                            fontFamily: app_fonts.Regular,
                            fontSize: 11.sp,
                            color: Colors.black45,
                          ),
                        ),
                    ],
                  ),
                ),
                // Balance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${balance.abs().toStringAsFixed(0)}',
                      style: TextStyle(
                        fontFamily: app_fonts.Bold,
                        fontSize: 14.sp,
                        color: balance >= 0
                            ? app_colors.GreenColor
                            : app_colors.c_danger,
                      ),
                    ),
                    Text(
                      balance == 0
                          ? 'Settled'
                          : balance > 0
                              ? 'Will Receive'
                              : 'Will Pay',
                      style: TextStyle(
                        fontFamily: app_fonts.Regular,
                        fontSize: 10.sp,
                        color: balance >= 0
                            ? app_colors.GreenColor
                            : app_colors.c_danger,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 6.w),
                Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }
}
