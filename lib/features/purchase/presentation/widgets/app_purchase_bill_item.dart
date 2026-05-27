import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../database/app_database.dart';

class AppPurchaseBillItem extends StatelessWidget {

  final int billId;

  final String billNumber;

  final String supplierName;

  final String billDate;

  final String totalAmount;

  final String paymentStatus;

  final VoidCallback? onBillUpdated;

  const AppPurchaseBillItem({
    super.key,
    required this.billId,
    required this.billNumber,
    required this.supplierName,
    required this.billDate,
    required this.totalAmount,
    required this.paymentStatus,
    this.onBillUpdated,
  });

  Future<void> _deleteBill(
      BuildContext context) async {

    final shouldDelete =
    await showDialog<bool>(
      context: context,

      builder: (context) => AlertDialog(
        title: const Text('Delete Bill'),

        content: Text(
          'Delete purchase bill $billNumber ?',
        ),

        actions: [

          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),

          TextButton(
            onPressed: () =>
                Navigator.pop(context, true),

            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {

      try {

        final db = AppDatabase.instance;

        final dbInstance =
        await db.database;

        await dbInstance.delete(
          'purchase_bills',
          where: 'id = ?',
          whereArgs: [billId],
        );

        if (onBillUpdated != null) {
          onBillUpdated!();
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Bill deleted successfully',
            ),
          ),
        );

      } catch (e) {

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text("$e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editBill(
      BuildContext context) async {

    final db = AppDatabase.instance;

    final bill =
    await db.getPurchaseBillByNumber(
      billNumber,
    );

    if (bill == null) return;

    final totalController =
    TextEditingController(
      text: bill['total_amount']
          .toString(),
    );

    final noteController =
    TextEditingController(
      text: bill['notes'] ?? '',
    );

    String paymentStatusValue =
        bill['payment_status'] ??
            'unpaid';

    String paymentModeValue =
        bill['payment_mode'] ??
            'cash';

    await showDialog(
      context: context,

      builder: (context) {

        return StatefulBuilder(
          builder: (context, setState) {

            return Dialog(
              backgroundColor:
              Colors.transparent,

              child: Container(
                padding: EdgeInsets.all(18.w),

                decoration: BoxDecoration(
                  color:
                  app_colors.Dbackgroun_color,

                  borderRadius:
                  BorderRadius.circular(
                      18.r),

                  border: Border.all(
                    color:
                    app_colors.Dborder_color,
                  ),
                ),

                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,

                    children: [

                      Row(
                        children: [

                          Expanded(
                            child: Text(
                              "Update Purchase Bill",

                              style: TextStyle(
                                fontSize: 18.sp,
                                fontFamily:
                                app_fonts.Medium,
                              ),
                            ),
                          ),

                          InkWell(
                            onTap: () {
                              Navigator.pop(
                                  context);
                            },
                            child: const Icon(
                                Icons.close),
                          ),
                        ],
                      ),

                      SizedBox(height: 20.h),

                      _buildField(
                        controller:
                        totalController,
                        label: "Total Amount",
                        icon:
                        Icons.currency_rupee,
                      ),

                      SizedBox(height: 14.h),

                      DropdownButtonFormField<
                          String>(
                        value:
                        paymentStatusValue,

                        decoration:
                        InputDecoration(
                          labelText:
                          "Payment Status",

                          filled: true,
                          fillColor:
                          Colors.white,

                          border:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                                12.r),
                          ),
                        ),

                        items: [
                          'paid',
                          'unpaid',
                          'partial'
                        ]
                            .map(
                              (e) =>
                              DropdownMenuItem(
                                value: e,
                                child: Text(
                                    e.toUpperCase()),
                              ),
                        )
                            .toList(),

                        onChanged: (v) {
                          setState(() {
                            paymentStatusValue =
                            v!;
                          });
                        },
                      ),

                      SizedBox(height: 14.h),

                      DropdownButtonFormField<
                          String>(
                        value:
                        paymentModeValue,

                        decoration:
                        InputDecoration(
                          labelText:
                          "Payment Mode",

                          filled: true,
                          fillColor:
                          Colors.white,

                          border:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                                12.r),
                          ),
                        ),

                        items: [
                          'cash',
                          'upi',
                          'bank',
                          'card',
                          'credit'
                        ]
                            .map(
                              (e) =>
                              DropdownMenuItem(
                                value: e,
                                child: Text(
                                    e.toUpperCase()),
                              ),
                        )
                            .toList(),

                        onChanged: (v) {
                          setState(() {
                            paymentModeValue =
                            v!;
                          });
                        },
                      ),

                      SizedBox(height: 14.h),

                      _buildField(
                        controller:
                        noteController,
                        label: "Notes",
                        icon: Icons.notes,
                        maxLines: 3,
                      ),

                      SizedBox(height: 20.h),

                      Row(
                        children: [

                          Expanded(
                            child:
                            OutlinedButton(
                              onPressed: () {
                                Navigator.pop(
                                    context);
                              },
                              child:
                              const Text(
                                  "Cancel"),
                            ),
                          ),

                          SizedBox(width: 12.w),

                          Expanded(
                            child:
                            ElevatedButton(

                              style:
                              ElevatedButton
                                  .styleFrom(
                                backgroundColor:
                                app_colors
                                    .table_header_bg,
                              ),

                              onPressed:
                                  () async {

                                try {

                                  final dbInstance =
                                  await db
                                      .database;

                                  await dbInstance
                                      .update(
                                    'purchase_bills',
                                    {
                                      'payment_status':
                                      paymentStatusValue,
                                      'payment_mode':
                                      paymentModeValue,
                                      'total_amount':
                                      double.tryParse(
                                        totalController
                                            .text,
                                      ) ??
                                          0,
                                      'notes':
                                      noteController
                                          .text
                                          .trim(),
                                    },
                                    where:
                                    'id = ?',
                                    whereArgs: [
                                      billId
                                    ],
                                  );

                                  Navigator.pop(
                                      context);

                                  if (onBillUpdated !=
                                      null) {
                                    onBillUpdated!();
                                  }

                                  ScaffoldMessenger
                                      .of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Bill updated successfully",
                                      ),
                                    ),
                                  );

                                } catch (e) {

                                  ScaffoldMessenger
                                      .of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content:
                                      Text("$e"),
                                      backgroundColor:
                                      Colors.red,
                                    ),
                                  );
                                }
                              },

                              child: const Text(
                                  "Update"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.only(
        top: 18,
        left: 12,
        right: 12,
      ),

      child: Container(
        padding: const EdgeInsets.all(8),

        width: double.infinity,
        height: 64.h,

        decoration: BoxDecoration(
          color: app_colors.Dbackgroun_color,

          border: Border.all(
            color: app_colors.Dborder_color,
          ),

          borderRadius:
          BorderRadius.circular(10.r),
        ),

        child: Row(
          children: [

            Container(
              width: 38.w,
              height: 38.h,

              decoration: BoxDecoration(
                color: Colors.white,

                border: Border.all(
                  color:
                  app_colors.Dborder_color,
                ),

                borderRadius:
                BorderRadius.circular(
                    4.r),
              ),

              child: Center(
                child: Text(
                  billNumber.length > 4
                      ? billNumber.substring(
                      0, 4)
                      : billNumber,

                  style: TextStyle(
                    fontSize: 12.sp,
                    fontFamily:
                    app_fonts.Bold,
                  ),
                ),
              ),
            ),

            SizedBox(width: 12.w),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                mainAxisAlignment:
                MainAxisAlignment.center,

                children: [

                  Text(
                    supplierName,

                    overflow:
                    TextOverflow.ellipsis,

                    style: TextStyle(
                      fontSize: 16.sp,
                      fontFamily:
                      app_fonts.Medium,
                    ),
                  ),

                  SizedBox(height: 4.h),

                  Text(
                    billDate,

                    style: TextStyle(
                      fontSize: 11.sp,
                      fontFamily:
                      app_fonts.Regular,
                    ),
                  ),
                ],
              ),
            ),

            Column(
              mainAxisAlignment:
              MainAxisAlignment.center,

              children: [

                Container(
                  width: 56.w,
                  height: 18.h,

                  decoration: BoxDecoration(
                    color:
                    paymentStatus
                        .toLowerCase() ==
                        'paid'
                        ? app_colors
                        .LightGreen
                        : app_colors
                        .c_danger
                        .withOpacity(
                        0.2),

                    borderRadius:
                    BorderRadius.circular(
                        4.r),
                  ),

                  child: Center(
                    child: Text(
                      paymentStatus,

                      style: TextStyle(
                        fontSize: 11.sp,

                        color:
                        paymentStatus
                            .toLowerCase() ==
                            'paid'
                            ? app_colors
                            .GreenColor
                            : app_colors
                            .c_danger,

                        fontFamily:
                        app_fonts.Medium,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 4.h),

                Text(
                  '${app_strings.Rs}$totalAmount',

                  style: TextStyle(
                    fontSize: 11.sp,
                    fontFamily:
                    app_fonts.Regular,
                  ),
                ),
              ],
            ),

            PopupMenuButton<String>(
              color: app_colors.white,

              onSelected: (value) {

                if (value == 'edit') {
                  _editBill(context);
                }

                else if (value ==
                    'delete') {
                  _deleteBill(context);
                }
              },

              itemBuilder:
                  (context) => [

                const PopupMenuItem(
                  value: 'edit',

                  child: Row(
                    children: [

                      Icon(Icons.edit,
                          size: 18),

                      SizedBox(width: 10),

                      Text("Edit Bill"),
                    ],
                  ),
                ),

                const PopupMenuItem(
                  value: 'delete',

                  child: Row(
                    children: [

                      Icon(
                        Icons.delete,
                        size: 18,
                        color: Colors.red,
                      ),

                      SizedBox(width: 10),

                      Text(
                        "Delete Bill",

                        style: TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              icon: Icon(
                Icons.more_vert,
                color: app_colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  TextInputType? keyboardType,
  int maxLines = 1,
}) {

  return TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,

    decoration: InputDecoration(
      labelText: label,

      prefixIcon: Icon(icon),

      filled: true,
      fillColor: Colors.white,

      border: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12.r),
      ),
    ),
  );
}