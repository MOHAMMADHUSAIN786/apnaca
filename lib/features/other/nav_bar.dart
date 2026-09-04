// lib/features/other/nav_bar.dart
// UPDATED: refreshAllScreens() — company switch ke baad call karo
//          In-App Review integrated — bills create hone par auto trigger

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/widgets/common_widgets/app_status_bar.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_fonts.dart';
import '../../core/constants/app_images.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/in_app_review_service.dart';
import '../../core/widgets/common_widgets/app_appbar.dart';
import '../../core/widgets/common_widgets/app_sidebar.dart';
import '../ai_chat/presentation/pages/chat_screen.dart';
import '../home/presentation/pages/home_screen.dart';
import '../item/presentation/pages/item_screen.dart';
import '../purchase/presentation/pages/purchase_screen.dart';
import '../sale/presentation/pages/sale_screen.dart';



class NavBar extends StatefulWidget {
  const NavBar({super.key});

  @override
  State<NavBar> createState() => NavBarState();
}

// ── State class PUBLIC so CompanyScreen can call refreshAllScreens ──
class NavBarState extends State<NavBar> {

  final GlobalKey<ScaffoldState>       scaffoldKey       = GlobalKey<ScaffoldState>();
  final GlobalKey<HomeScreenState>     homeScreenKey     = GlobalKey<HomeScreenState>();
  final GlobalKey<SaleScreenState>     saleScreenKey     = GlobalKey<SaleScreenState>();
  final GlobalKey<ItemScreenState>     itemScreenKey     = GlobalKey<ItemScreenState>();
  final GlobalKey<PurchaseScreenState> purchaseScreenKey = GlobalKey<PurchaseScreenState>();

  int _selectedIndex = 0;

  // ── AI Assistant open karo (HomeScreen ke card se call hota hai) ─
  Future<void> _openChat() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
    if (result == true) refreshAllScreens();
  }

  late final List<Widget> _screens = [
    HomeScreen(key: homeScreenKey, onAiAssistantTap: _openChat),
    SaleScreen(key: saleScreenKey),
    PurchaseScreen(key: purchaseScreenKey),
    ItemScreen(key: itemScreenKey),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      saleScreenKey.currentState?.onRefreshParent     = _refreshDashboard;
      purchaseScreenKey.currentState?.onRefreshParent = _refreshDashboard;

      // ── App open count track karo ────────────────────────────────
      InAppReviewService.incrementAppOpen();

      // ── Update check: 1.5s delay ke baad ────────────────────────
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          AppUpdateService.checkForUpdate(context, forceUpdate: false);
        }
      });

      // ── In-App Review: 3s delay ke baad check karo ──────────────
      // (Update dialog ke baad, dono ek saath na dikhein)
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (mounted) {
          InAppReviewService.tryRequestReview(context);
        }
      });
    });
  }

  // ── Sirf dashboard refresh ────────────────────────────────────
  void _refreshDashboard() {
    homeScreenKey.currentState?.refreshHome();
  }

  // ── ALL screens refresh — company switch ke baad call hota hai ─
  void refreshAllScreens() {
    homeScreenKey.currentState?.refreshHome();
    saleScreenKey.currentState?.refreshSales();
    purchaseScreenKey.currentState?.refreshPurchaseBills();
    itemScreenKey.currentState?.refreshItems();
  }

  // ── Bill create hone ke baad call karo (Sale/Purchase screen se) ─
  /// Example: NavBar ke parent se ya sale_screen ke callback mein:
  ///   InAppReviewService.onBillCreated(context);
  void onBillCreated() {
    InAppReviewService.onBillCreated(context);
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0: return "Dashboard";
      case 1: return "Sale";
      case 2: return "Purchase";
      case 3: return "Items";
      default: return "";
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    if (index == 3) itemScreenKey.currentState?.refreshItems();
  }

  @override
  Widget build(BuildContext context) {
    return AppStatusBarUtils(
      color: app_colors.table_header_bg,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.white,
          key: scaffoldKey,
          drawer: const AppSideBar(),
          appBar: AppAppBar(
            title: _getAppBarTitle(_selectedIndex),
            showSidebarIcon: true,
            onSidebarTap: () => scaffoldKey.currentState?.openDrawer(),
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
                    activeIcon: Image.asset(app_images.ic_active_home, height: 24.h),
                    label: "Home",
                  ),
                  BottomNavigationBarItem(
                    icon: Image.asset(app_images.ic_sale, height: 24.h),
                    activeIcon: Image.asset(app_images.ic_active_sale, height: 24.h),
                    label: "Sale",
                  ),
                  BottomNavigationBarItem(
                    icon: Image.asset(app_images.ic_purchase, height: 24.h),
                    activeIcon: Image.asset(app_images.ic_active_purchase, height: 24.h),
                    label: "Purchase",
                  ),
                  BottomNavigationBarItem(
                    icon: Image.asset(app_images.ic_item, height: 24.h),
                    activeIcon: Image.asset(app_images.ic_active_item, height: 24.h),
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