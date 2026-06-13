import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/app_status_bar.dart';
import '../../presentation/bloc/warehouse_bloc.dart';
import '../../presentation/bloc/warehouse_event.dart';
import '../../presentation/bloc/warehouse_state.dart';
import 'transfer_screen.dart';
import 'transfer_history_screen.dart';

class WarehouseListScreen extends StatelessWidget {
  const WarehouseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => WarehouseBloc()..add(LoadWarehouses()),
      child: AppStatusBarUtils(
        color: app_colors.table_header_bg,
        child: Scaffold(
          backgroundColor: app_colors.white,
          body: BlocBuilder<WarehouseBloc, WarehouseState>(
            builder: (context, state) {
              if (state is WarehouseLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is WarehouseOperationFailure) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'Error: ${state.message}',
                        style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 16.sp, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24.h),
                      ElevatedButton(
                        onPressed: () => context.read<WarehouseBloc>().add(LoadWarehouses()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (state is WarehousesLoaded) {
                final warehouses = state.warehouses;
                if (warehouses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.warehouse_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'No warehouses',
                          style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 16.sp, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 18, left: 8, right: 8, bottom: 80.h),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: warehouses.length,
                          itemBuilder: (context, i) {
                            final w = warehouses[i];
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
                                  child: Icon(Icons.warehouse, color: app_colors.c_primary, size: 24.sp),
                                ),
                                title: Text(
                                  w['name'] ?? '',
                                  style: TextStyle(fontFamily: app_fonts.Bold, fontSize: 16.sp, color: app_colors.title),
                                ),
                                subtitle: Padding(
                                  padding: EdgeInsets.only(top: 4.h),
                                  child: Text(
                                    w['location'] ?? '',
                                    style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 12.sp, color: Colors.grey.shade600),
                                  ),
                                ),
                                trailing: PopupMenuButton(
                                  onSelected: (value) {
                                    if (value == 'transfer') {
                                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => TransferScreen(fromWarehouseId: w['id'])));
                                    } else if (value == 'delete') {
                                      context.read<WarehouseBloc>().add(DeleteWarehouse(w['id']));
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => [
                                    PopupMenuItem(
                                      value: 'transfer',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.send_to_mobile, size: 20),
                                          SizedBox(width: 8.w),
                                          const Text('Transfer'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.delete, size: 20, color: Colors.red),
                                          SizedBox(width: 8.w),
                                          const Text('Delete', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: app_colors.button_bg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
            onPressed: () async {
              final nameCtrl = TextEditingController();
              final codeCtrl = TextEditingController();
              final locCtrl = TextEditingController();
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                  title: Text('Create Warehouse', style: TextStyle(fontFamily: app_fonts.Bold, color: app_colors.title, fontSize: 18.sp)),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                          ),
                          style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp),
                        ),
                        SizedBox(height: 12.h),
                        TextField(
                          controller: codeCtrl,
                          decoration: InputDecoration(
                            labelText: 'Code',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                          ),
                          style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp),
                        ),
                        SizedBox(height: 12.h),
                        TextField(
                          controller: locCtrl,
                          decoration: InputDecoration(
                            labelText: 'Location',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                          ),
                          style: TextStyle(fontFamily: app_fonts.Medium, fontSize: 14.sp),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: app_fonts.Medium))),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: app_colors.button_bg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text('Create', style: TextStyle(color: app_colors.white, fontFamily: app_fonts.Bold)),
                    ),
                  ],
                ),
              );
              if (ok == true && nameCtrl.text.trim().isNotEmpty) {
                context.read<WarehouseBloc>().add(
                  CreateWarehouse(
                    nameCtrl.text.trim(),
                    code: codeCtrl.text.trim(),
                    location: locCtrl.text.trim(),
                  ),
                );
              }
            },
            label: Text('Add Warehouse', style: TextStyle(color: app_colors.white, fontFamily: app_fonts.Bold, fontSize: 14.sp)),
            icon: Icon(Icons.add, color: app_colors.white, size: 24.sp),
          ),
        ),
      ),
    );
  }
}
