// lib/features/item/presentation/pages/stock_history_screen.dart
// Stock movement history for a single item.
// Reuses the same card list styling as item_screen.dart (Dbackgroun_color,
// Dborder_color, app_fonts) — no new design tokens.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../database/app_database.dart';
import '../../model/item_model.dart';

class StockHistoryScreen extends StatefulWidget {
  final ItemModel item;

  const StockHistoryScreen({super.key, required this.item});

  @override
  State<StockHistoryScreen> createState() => _StockHistoryScreenState();
}

class _StockHistoryScreenState extends State<StockHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = AppDatabase.instance.getStockHistory(widget.item.id!);
  }

  void _refresh() {
    setState(() {
      _historyFuture = AppDatabase.instance.getStockHistory(widget.item.id!);
    });
  }

  // change_type -> label, color, icon
  Map<String, dynamic> _styleFor(String type) {
    switch (type) {
      case 'stock_in':
        return {'label': 'Stock In', 'color': app_colors.GreenColor, 'bg': app_colors.LightGreen, 'icon': Icons.arrow_downward_rounded};
      case 'stock_out':
        return {'label': 'Stock Out', 'color': app_colors.c_danger, 'bg': app_colors.RedColor, 'icon': Icons.arrow_upward_rounded};
      case 'adjustment':
        return {'label': 'Adjustment', 'color': app_colors.OrangeColor, 'bg': app_colors.LightOrange, 'icon': Icons.tune};
      case 'sale':
        return {'label': 'Sale', 'color': app_colors.c_danger, 'bg': app_colors.RedColor, 'icon': Icons.point_of_sale};
      case 'sale_cancel':
        return {'label': 'Sale Cancelled', 'color': app_colors.GreenColor, 'bg': app_colors.LightGreen, 'icon': Icons.undo};
      case 'purchase':
        return {'label': 'Purchase', 'color': app_colors.GreenColor, 'bg': app_colors.LightGreen, 'icon': Icons.shopping_cart};
      case 'purchase_cancel':
        return {'label': 'Purchase Cancelled', 'color': app_colors.c_danger, 'bg': app_colors.RedColor, 'icon': Icons.undo};
      default:
        return {'label': type, 'color': app_colors.black, 'bg': app_colors.table_header_bg, 'icon': Icons.history};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: app_colors.Dbackgroun_color,
        elevation: 0,
        iconTheme: IconThemeData(color: app_colors.black),
        title: Text(
          "Stock History",
          style: TextStyle(color: app_colors.black, fontSize: 16.sp, fontFamily: app_fonts.Medium),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 18, left: 12, right: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: app_colors.Dbackgroun_color,
                border: Border.all(color: app_colors.Dborder_color),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38.w, height: 38.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(Icons.inventory, size: 20, color: app_colors.black),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.item.name,
                            style: TextStyle(fontSize: 15.sp, fontFamily: app_fonts.Medium, color: app_colors.black)),
                        SizedBox(height: 4.h),
                        Text("Current Stock: ${widget.item.qty ?? 0}",
                            style: TextStyle(fontSize: 11.sp, fontFamily: app_fonts.Regular, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final history = snapshot.data ?? [];
                if (history.isEmpty) {
                  return Center(
                    child: Text("Koi stock movement history nahi hai",
                        style: TextStyle(fontSize: 14.sp, color: Colors.grey)),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.only(bottom: 24.h),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final h = history[index];
                    final type = (h['change_type'] as String?) ?? '';
                    final style = _styleFor(type);
                    final qtyChange = (h['qty_change'] as int?) ?? 0;
                    final sign = qtyChange > 0 ? "+" : "";

                    return Padding(
                      padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: app_colors.Dbackgroun_color,
                          border: Border.all(color: app_colors.Dborder_color),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 36.w, height: 36.h,
                              decoration: BoxDecoration(
                                color: style['bg'] as Color,
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Icon(style['icon'] as IconData, size: 18, color: style['color'] as Color),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(style['label'] as String,
                                      style: TextStyle(fontSize: 13.sp, fontFamily: app_fonts.Medium, color: app_colors.black)),
                                  SizedBox(height: 2.h),
                                  Text(
                                    "${h['qty_before']} -> ${h['qty_after']}"
                                        "${(h['reason'] != null && (h['reason'] as String).isNotEmpty) ? '  •  ${h['reason']}' : ''}"
                                        "${(h['reference_no'] != null) ? '  •  ${h['reference_no']}' : ''}",
                                    style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade700, fontFamily: app_fonts.Regular),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    (h['created_at'] as String?)?.split('T').first ?? '',
                                    style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              "$sign$qtyChange",
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: style['color'] as Color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
