import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_status_bar.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_fonts.dart';
import '../../core/constants/app_images.dart';

import '../../core/widgets/common_widgets/app_appbar.dart';

import '../ai_chat/presentation/chat_screen.dart';
import '../home/presentation/pages/home_screen.dart';
import '../item/presentation/item_screen.dart';
import '../purchase/presentation/purchase_screen.dart';
import '../sale/presentation/sale_screen.dart';

class NavBar extends StatefulWidget {
  const NavBar({super.key});

  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),

    const SaleScreen(),

    const PurchaseScreen(),

    ItemScreen(),
  ];

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return "Dashboard";

      case 1:
        return "Sale";

      case 2:
        return "Purchase";

      case 3:
        return "Items";

      default:
        return "";
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppStatusBarUtils(
      color: app_colors.table_header_bg,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.white,

          key: scaffoldKey,

          /// drawer: const AppSideBar(),
          appBar: AppAppBar(
            title: _getAppBarTitle(_selectedIndex),

            showSidebarIcon: true,

            onSidebarTap: () {
              scaffoldKey.currentState?.openDrawer();
            },

            onChatTap: () {
              /// NAVIGATION
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) =>  ChatScreen()),
              );
            },
          ),

          body: IndexedStack(index: _selectedIndex, children: _screens),

          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,

          bottomNavigationBar: SafeArea(
            bottom: true,

            child: BottomAppBar(
              shape: const CircularNotchedRectangle(),

              notchMargin: 8,

              padding: EdgeInsets.zero,

              child: BottomNavigationBar(
                backgroundColor: app_colors.table_header_bg,

                elevation: 20,

                currentIndex: _selectedIndex,

                onTap: _onItemTapped,

                type: BottomNavigationBarType.fixed,

                enableFeedback: false,

                selectedItemColor: Colors.black,

                unselectedItemColor: Colors.black,

                showUnselectedLabels: true,

                selectedFontSize: 12.sp,

                unselectedFontSize: 12.sp,

                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,

                  fontFamily: app_fonts.Regular,
                ),

                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,

                  fontFamily: app_fonts.Regular,
                ),

                items: [
                  BottomNavigationBarItem(
                    icon: Image.asset(app_images.ic_home, height: 24.h),

                    activeIcon: Image.asset(
                      app_images.ic_active_home,
                      height: 24.h,
                    ),

                    label: "Home",
                  ),

                  BottomNavigationBarItem(
                    icon: Image.asset(app_images.ic_sale, height: 24.h),

                    activeIcon: Image.asset(
                      app_images.ic_active_sale,
                      height: 24.h,
                    ),

                    label: "Sale",
                  ),

                  BottomNavigationBarItem(
                    icon: Image.asset(app_images.ic_purchase, height: 24.h),

                    activeIcon: Image.asset(
                      app_images.ic_active_purchase,
                      height: 24.h,
                    ),

                    label: "Purchase",
                  ),

                  BottomNavigationBarItem(
                    icon: Image.asset(app_images.ic_item, height: 24.h),

                    activeIcon: Image.asset(
                      app_images.ic_active_item,
                      height: 24.h,
                    ),

                    label: "Items",
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


