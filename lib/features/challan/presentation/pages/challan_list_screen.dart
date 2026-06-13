import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../database/app_database.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import 'create_challan_screen.dart';

class ChallanListScreen extends StatefulWidget {
  const ChallanListScreen({super.key});

  @override
  State<ChallanListScreen> createState() => _ChallanListScreenState();
}

class _ChallanListScreenState extends State<ChallanListScreen> {
  List<Map<String, dynamic>> _challans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await AppDatabase.instance.getAllChallans();
    setState(() {
      _challans = list;
      _loading = false;
    });
  }

  Future<void> _updateStatus(int challanId, String currentStatus) async {
    final statusCtrl = TextEditingController(text: currentStatus);
    
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Text('Update Status', style: TextStyle(fontFamily: app_fonts.Bold, color: app_colors.title, fontSize: 18.sp)),
      content: DropdownButtonFormField<String>(
        value: statusCtrl.text,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        ),
        items: [
          DropdownMenuItem(value: 'pending', child: Text('Pending', style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp))),
          DropdownMenuItem(value: 'in_transit', child: Text('In Transit', style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp))),
          DropdownMenuItem(value: 'delivered', child: Text('Delivered', style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp))),
        ],
        onChanged: (val) => statusCtrl.text = val ?? 'pending',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: app_fonts.Medium))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: app_colors.button_bg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r))),
          onPressed: () => Navigator.pop(ctx, true), 
          child: Text('Update', style: TextStyle(color: app_colors.white, fontFamily: app_fonts.Bold))
        ),
      ],
    ));

    if (ok == true) {
      await AppDatabase.instance.updateChallanStatus(challanId, statusCtrl.text);
      _load();
    }
  }

  Future<void> _convertToBill(int challanId) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Text('Convert to Sale Bill?', style: TextStyle(fontFamily: app_fonts.Bold, color: app_colors.title, fontSize: 18.sp)),
      content: Text('This will convert the challan into a Sale Bill and deduct the inventory items permanently. Proceed?', style: TextStyle(fontFamily: app_fonts.Regular, fontSize: 14.sp)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: app_fonts.Medium))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: app_colors.button_bg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r))),
          onPressed: () => Navigator.pop(ctx, true), 
          child: Text('Convert', style: TextStyle(color: app_colors.white, fontFamily: app_fonts.Bold))
        ),
      ],
    ));

    if (ok == true) {
      setState(() => _loading = true);
      await AppDatabase.instance.convertChallanToSaleBill(challanId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Challan converted to Sale Bill!', style: TextStyle(fontFamily: app_fonts.Medium)), backgroundColor: app_colors.success));
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
          'Delivery Challans',
          style: TextStyle(
            color: app_colors.title,
            fontFamily: app_fonts.Bold,
            fontSize: 18.sp,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: app_colors.c_primary))
          : _challans.isEmpty
              ? Center(child: Text('No delivery challans.', style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 16.sp, color: Colors.grey)))
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  itemCount: _challans.length,
                  itemBuilder: (context, i) {
                    final c = _challans[i];
                    final isConverted = c['status'] == 'converted';
                    
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
                          '${c['challan_number']} - ${c['customer_name'] ?? 'Walk-in'}',
                          style: TextStyle(fontFamily: app_fonts.Bold, fontSize: 15.sp, color: app_colors.title),
                        ),
                        subtitle: Padding(
                          padding: EdgeInsets.only(top: 4.h),
                          child: Text(
                            'Date: ${c['challan_date']} | Driver: ${c['driver_name']?.isEmpty == true ? '-' : c['driver_name']}\nStatus: ${(c['status'] as String).toUpperCase()}',
                            style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 12.sp, color: Colors.grey.shade600),
                          ),
                        ),
                        trailing: isConverted
                            ? Icon(Icons.receipt_long, color: app_colors.c_primary, size: 28.sp)
                            : PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert, color: app_colors.black, size: 24.sp),
                                onSelected: (val) {
                                  if (val == 'status') _updateStatus(c['id'], c['status']);
                                  if (val == 'convert') _convertToBill(c['id']);
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(value: 'status', child: Text('Update Status', style: TextStyle(fontFamily: app_fonts.Medium))),
                                  PopupMenuItem(value: 'convert', child: Text('Convert to Bill', style: TextStyle(fontFamily: app_fonts.Medium))),
                                ],
                              ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: app_colors.button_bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
        onPressed: () async {
          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateChallanScreen()));
          if (res == true) _load();
        },
        label: Text('Create Challan', style: TextStyle(color: app_colors.white, fontFamily: app_fonts.Bold, fontSize: 14.sp)),
        icon: Icon(Icons.add, color: app_colors.white, size: 24.sp),
      ),
    );
  }
}
