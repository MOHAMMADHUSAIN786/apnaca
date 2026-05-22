import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';

class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showSidebarIcon;
  final VoidCallback? onSidebarTap;
  final bool backbutton;
  final VoidCallback? onChatTap;

  const AppAppBar({
    Key? key,
    required this.title,
    this.showSidebarIcon = false,
    this.onSidebarTap,
    this.backbutton = false,
    this.onChatTap, // 👈 add this
  }) : super(key: key);

  @override
  Size get preferredSize => Size.fromHeight(56.h); // Standard height

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: app_colors.table_header_bg,
      elevation: 0,
      automaticallyImplyLeading: false,
      scrolledUnderElevation: 0,
      title: Text(
        title,
        style: TextStyle(
          color: Colors.black,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          fontFamily: app_fonts.Medium,
        ),
      ),
      leading: showSidebarIcon
          ? IconButton(
        icon: Icon(Icons.menu, color: Colors.black),
        onPressed: onSidebarTap ?? () {},
      )
          : backbutton
          ? IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Get.back(),
      )
          : null,
      actions: [
        if (onChatTap != null)
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.black),
            onPressed: onChatTap,
          ),
      ],
      centerTitle: false,
    );
  }

}
