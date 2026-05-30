import 'package:apnaca/features/supplier/presentation/pages/supplier_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../features/auth/presentation/pages/auth_screen.dart';
import '../../../features/contact_us/contactus_screen.dart';
import '../../../features/customer/presentation/pages/customer_screen.dart';
import '../../../features/feedback/feedback_screen.dart';
import '../../../features/profile/presentation/pages/profile_screen.dart';
import '../../../features/setting/presentation/pages/setting_screen.dart';
import '../../../features/subscription/presentation/pages/subscription_screen.dart';
import '../../../features/warehouse/presentation/pages/warehouse_screen.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';
import '../../services/sync_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppSideBar extends StatefulWidget {
  const AppSideBar({super.key});

  @override
  State<AppSideBar> createState() => _AppSideBarState();
}

class _AppSideBarState extends State<AppSideBar> {

  Map<String, dynamic>? userData;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUser();
  }

  Future<void> _fetchUser() async {

    try {

      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final doc = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {

        userData = doc.data();

        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }

    } catch (e) {

      debugPrint(
          "SIDEBAR USER ERROR: $e");

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 260.w,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      backgroundColor: app_colors.table_header_bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Theme(
            data: Theme.of(context).copyWith(
              dividerTheme: const DividerThemeData(color: Colors.transparent),
            ),
            child: DrawerHeader(
              decoration: BoxDecoration(color: app_colors.table_header_bg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(
                    builder: (context) {

                      final firstName =
                          userData?['first_name'] ?? '';

                      final lastName =
                          userData?['last_name'] ?? '';

                      final fullName =
                      "$firstName $lastName".trim();

                      final email =
                          userData?['email'] ?? '';

                      final photoUrl =
                      userData?['photo_url'];

                      String initials = '';

                      if (firstName.isNotEmpty) {
                        initials += firstName[0]
                            .toUpperCase();
                      }

                      if (lastName.isNotEmpty) {
                        initials += lastName[0]
                            .toUpperCase();
                      }

                      return Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,

                        children: [

                          CircleAvatar(
                            radius: 25.r,
                            backgroundColor:
                            Colors.white,

                            backgroundImage:
                            photoUrl != null &&
                                photoUrl
                                    .toString()
                                    .isNotEmpty
                                ? NetworkImage(
                              photoUrl,
                            )
                                : null,

                            child: photoUrl == null ||
                                photoUrl
                                    .toString()
                                    .isEmpty
                                ? Text(
                              initials.isEmpty
                                  ? "U"
                                  : initials,

                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight:
                                FontWeight.bold,
                                color: app_colors
                                    .black,
                              ),
                            )
                                : null,
                          ),

                          SizedBox(height: 10.h),

                          Text(
                            fullName.isEmpty
                                ? "User"
                                : fullName,

                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16.sp,
                              fontFamily:
                              app_fonts.Medium,
                            ),
                          ),

                          SizedBox(height: 2.h),

                          Text(
                            email,

                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,

                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 10.sp,
                              fontFamily:
                              app_fonts.Regular,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Divider line
          Container(
            width: double.infinity,
            height: 1,
            color: Colors.grey.shade400,
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customers
                  _buildTile(
                    icon: Icons.people_outline,
                    label: "Customers",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CustomerScreen()),
                      );
                    },
                  ),

                  //Suppliers
                  _buildTile(
                    icon: Icons.people_outline,
                    label: "Suppliers",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SupplierScreen()),
                      );
                    },
                  ),

                  // // Warehouse
                  // _buildTile(
                  //   icon: Icons.warehouse_outlined,
                  //   label: "Warehouse",
                  //   onTap: () {
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(builder: (_) => const WarehouseScreen()),
                  //     );
                  //   },
                  // ),

                  // Subscription
                  _buildTile(
                    icon: Icons.workspace_premium_rounded,
                    label: "Subscription",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                      );
                    },
                  ),

                  // Profile
                  _buildTile(
                    icon: Icons.person_outline,
                    label: "Profile",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    },
                  ),

                  // Settings
                  // _buildTile(
                  //   icon: Icons.settings_outlined,
                  //   label: "Settings",
                  //   onTap: () {
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(builder: (_) => const SettingScreen()),
                  //     );
                  //   },
                  // ),

                  // Backup Now
                  _buildTile(
                    icon: Icons.backup_outlined,
                    label: "Backup Now",
                    onTap: () => _manualBackup(context),
                  ),

                  // Restore Data
                  _buildTile(
                    icon: Icons.restore_outlined,
                    label: "Restore Data",
                    onTap: () => _restoreData(context),
                  ),

                  // Privacy Policy
                  _buildTile(
                    icon: Icons.privacy_tip_outlined,
                    label: "Privacy Policy",
                    onTap: () {
                      _showPrivacyPolicy(context);
                    },
                  ),

                  // Terms & Conditions
                  _buildTile(
                    icon: Icons.description_outlined,
                    label: "Terms & Conditions",
                    onTap: () {
                      _showTermsConditions(context);
                    },
                  ),

                  // Contact Us
                  _buildTile(
                    icon: Icons.contact_support_outlined,
                    label: "Contact Us",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ContactUsScreen()),
                      );
                    },
                  ),

// Feedback
                  _buildTile(
                    icon: Icons.star_outline,
                    label: "Feedback",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                      );
                    },
                  ),

                  // Logout Option (Red Color)
                  _buildLogoutTile(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Simple tile widget
  Widget _buildTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Padding(
        padding: EdgeInsets.symmetric(horizontal: 2.w),
        child: Icon(icon, color: app_colors.black, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14.sp,
          fontFamily: app_fonts.Regular,
          color: app_colors.black,
        ),
      ),
      onTap: onTap,
    );
  }

  // Logout Tile (Red Color)
  Widget _buildLogoutTile(BuildContext context) {
    return ListTile(
      leading: Padding(
        padding: EdgeInsets.symmetric(horizontal: 2.w),
        child: Icon(Icons.logout, color: Colors.red, size: 20),
      ),
      title: Text(
        "Logout",
        style: TextStyle(
          fontSize: 14.sp,
          fontFamily: app_fonts.Regular,
          color: Colors.red,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () => _logout(context),
    );
  }

  // Logout Method
  void _logout(BuildContext context) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AuthScreen()),
            );},
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Logging out...'),
            ],
          ),
        ),
      );

      try {
        // Sign out from Firebase
        await FirebaseAuth.instance.signOut();

        // Close loading dialog
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        // Navigate to login screen
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } catch (e) {
        // Close loading dialog
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Manual Backup
  void _manualBackup(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Uploading backup...'),
          ],
        ),
      ),
    );

    final success = await FirebaseSyncService.uploadDatabase();

    // Close loading dialog
    if (navigator.canPop()) {
      navigator.pop();
    }

    if (success) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('✅ Backup completed successfully!')),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('❌ Backup failed. Check your internet connection.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Restore Data
  void _restoreData(BuildContext context) async {
    final info = await FirebaseSyncService.getBackupInfo();

    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No backup found in cloud')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to restore from cloud backup?'),
            SizedBox(height: 10.h),
            Text('Last backup: ${info['lastModified']?.toString().split(' ')[0] ?? 'Unknown'}'),
            Text('Size: ${(info['size'] / 1024).toStringAsFixed(2)} KB'),
            SizedBox(height: 10.h),
            const Text('⚠️ This will replace all current data!',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Restoring data...'),
            ],
          ),
        ),
      );

      final success = await FirebaseSyncService.downloadDatabase();

      // Close loading dialog
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Data restored! Restarting app...')),
        );
        await Future.delayed(const Duration(seconds: 1));
        // Restart the app
        Navigator.pushReplacementNamed(context, '/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Restore failed'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Privacy Policy Dialog
  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: SingleChildScrollView(
          child: Text(
            'Privacy Policy\n\n'
                'Last updated: ${DateTime.now().year}\n\n'
                '1. Information Collection\n'
                '   We collect business information including customer details, '
                'sales data, and inventory information to provide our services.\n\n'
                '2. Data Usage\n'
                '   Your data is stored locally on your device. We do not share '
                'your data with third parties without your consent.\n\n'
                '3. Security\n'
                '   We implement security measures to protect your data from '
                'unauthorized access.\n\n'
                '4. Your Rights\n'
                '   You have the right to access, modify, or delete your data '
                'at any time.\n\n'
                'For any questions, contact us at apnaca786@gmail.com',
            style: TextStyle(fontSize: 12.sp),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Terms & Conditions Dialog
  void _showTermsConditions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: SingleChildScrollView(
          child: Text(
            'Terms & Conditions\n\n'
                'Last updated: ${DateTime.now().year}\n\n'
                '1. Acceptance of Terms\n'
                '   By using Apna Hisab, you agree to these terms and conditions.\n\n'
                '2. Use of Service\n'
                '   You agree to use this service only for legitimate business '
                'purposes and in compliance with applicable laws.\n\n'
                '3. Data Ownership\n'
                '   You retain ownership of all data you enter into the application.\n\n'
                '4. Limitation of Liability\n'
                '   We are not liable for any business losses arising from the '
                'use of this application.\n\n'
                '5. Modifications\n'
                '   We reserve the right to modify these terms at any time.\n\n'
                '6. Termination\n'
                '   We may terminate or suspend access to our service immediately '
                'for violations of these terms.\n\n'
                'For questions, contact: apnaca786@gmail.com',
            style: TextStyle(fontSize: 12.sp),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}