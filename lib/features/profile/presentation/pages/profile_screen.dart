import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  final _nameController = TextEditingController();

  // Branding
  String? _logoUrl;
  String? _signatureUrl;
  bool _logoLoading = false;
  bool _signatureLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // FETCH USER
  // ─────────────────────────────────────────────

  Future<void> _fetchUserData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final doc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      if (!doc.exists) throw Exception('User not found');

      final data = doc.data()!;
      _userData = data;
      _nameController.text =
          "${data['first_name'] ?? ''} ${data['last_name'] ?? ''}".trim();

      // Fetch branding URLs
      await _fetchBrandingUrls(user.uid);

      setState(() { _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _fetchBrandingUrls(String uid) async {
    try {
      final logoRef = FirebaseStorage.instance
          .ref()
          .child('users/$uid/branding/company_logo');
      _logoUrl = await logoRef.getDownloadURL();
    } catch (_) { _logoUrl = null; }

    try {
      final sigRef = FirebaseStorage.instance
          .ref()
          .child('users/$uid/branding/signature');
      _signatureUrl = await sigRef.getDownloadURL();
    } catch (_) { _signatureUrl = null; }
  }

  // ─────────────────────────────────────────────
  // UPDATE NAME
  // ─────────────────────────────────────────────

  Future<void> _updateDisplayName() async {
    final fullName = _nameController.text.trim();
    if (fullName.isEmpty) return;
    final parts = fullName.split(' ');
    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    setState(() { _isSaving = true; });
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'first_name': firstName,
        'last_name': lastName,
      });
      await FirebaseAuth.instance.currentUser?.updateDisplayName(fullName);
      await _fetchUserData();
      if (mounted) {
        _showSnack('Profile updated ✓', success: true);
      }
    } catch (e) {
      _showSnack('Error: $e', success: false);
    } finally {
      setState(() { _isSaving = false; });
    }
  }

  // ─────────────────────────────────────────────
  // PROFILE IMAGE
  // ─────────────────────────────────────────────

  Future<void> _showImagePickerOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44.w, height: 4.h,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(20.r)),
              ),
              SizedBox(height: 18.h),
              Text("Profile Photo",
                  style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 20.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _imageOptionBtn(icon: Icons.camera_alt_rounded, label: "Camera",
                      color: app_colors.c_primary, onTap: () {
                        Navigator.pop(ctx);
                        _pickAndUploadImage(ImageSource.camera, 'profile');
                      }),
                  _imageOptionBtn(icon: Icons.photo_rounded, label: "Gallery",
                      color: app_colors.c_primary, onTap: () {
                        Navigator.pop(ctx);
                        _pickAndUploadImage(ImageSource.gallery, 'profile');
                      }),
                  _imageOptionBtn(icon: Icons.delete_rounded, label: "Remove",
                      color: app_colors.c_danger, onTap: () {
                        Navigator.pop(ctx);
                        _removeProfileImage();
                      }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageOptionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26.sp),
          ),
          SizedBox(height: 8.h),
          Text(label,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source, String type) async {
    try {
      final picker = ImagePicker();
      final pickedFile =
      await picker.pickImage(source: source, imageQuality: 70);
      if (pickedFile == null) return;

      if (type == 'profile') setState(() { _isSaving = true; });
      if (type == 'logo') setState(() { _logoLoading = true; });
      if (type == 'signature') setState(() { _signatureLoading = true; });

      final user = FirebaseAuth.instance.currentUser!;
      final file = File(pickedFile.path);

      String storagePath;
      if (type == 'profile') {
        storagePath = 'profile_pictures/${user.uid}.jpg';
      } else if (type == 'logo') {
        storagePath = 'users/${user.uid}/branding/company_logo';
      } else {
        storagePath = 'users/${user.uid}/branding/signature';
      }

      final ref = FirebaseStorage.instance.ref().child(storagePath);
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();

      if (type == 'profile') {
        await FirebaseFirestore.instance
            .collection('users').doc(user.uid)
            .update({'photo_url': downloadUrl});
        await user.updatePhotoURL(downloadUrl);
        await _fetchUserData();
        _showSnack('Profile picture updated ✓', success: true);
      } else if (type == 'logo') {
        setState(() { _logoUrl = downloadUrl; _logoLoading = false; });
        _showSnack('Company logo updated ✓', success: true);
      } else {
        setState(() { _signatureUrl = downloadUrl; _signatureLoading = false; });
        _showSnack('Signature updated ✓', success: true);
      }
    } catch (e) {
      _showSnack('Upload failed: $e', success: false);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _logoLoading = false;
          _signatureLoading = false;
        });
      }
    }
  }

  Future<void> _removeProfileImage() async {
    try {
      setState(() { _isSaving = true; });
      final user = FirebaseAuth.instance.currentUser!;
      await FirebaseFirestore.instance
          .collection('users').doc(user.uid).update({'photo_url': ''});
      await user.updatePhotoURL(null);
      try {
        await FirebaseStorage.instance
            .ref().child('profile_pictures/${user.uid}.jpg').delete();
      } catch (_) {}
      await _fetchUserData();
      _showSnack('Profile photo removed', success: true);
    } catch (e) {
      _showSnack('Error: $e', success: false);
    } finally {
      setState(() { _isSaving = false; });
    }
  }

  Future<void> _removeBrandingAsset(String type) async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final path = type == 'logo'
          ? 'users/${user.uid}/branding/company_logo'
          : 'users/${user.uid}/branding/signature';
      await FirebaseStorage.instance.ref().child(path).delete();
      setState(() {
        if (type == 'logo') _logoUrl = null;
        else _signatureUrl = null;
      });
      _showSnack('${type == 'logo' ? 'Logo' : 'Signature'} removed', success: true);
    } catch (e) {
      _showSnack('Remove failed: $e', success: false);
    }
  }

  void _showSnack(String msg, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? app_colors.GreenColor : app_colors.c_danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
    ));
  }

  void _showBrandingOptions(String type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44.w, height: 4.h,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(20.r)),
              ),
              SizedBox(height: 18.h),
              Text(
                type == 'logo' ? "Company Logo" : "Signature",
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _imageOptionBtn(icon: Icons.camera_alt_rounded, label: "Camera",
                      color: app_colors.c_primary, onTap: () {
                        Navigator.pop(ctx);
                        _pickAndUploadImage(ImageSource.camera, type);
                      }),
                  _imageOptionBtn(icon: Icons.photo_rounded, label: "Gallery",
                      color: app_colors.c_primary, onTap: () {
                        Navigator.pop(ctx);
                        _pickAndUploadImage(ImageSource.gallery, type);
                      }),
                  _imageOptionBtn(icon: Icons.delete_rounded, label: "Remove",
                      color: app_colors.c_danger, onTap: () {
                        Navigator.pop(ctx);
                        _removeBrandingAsset(type);
                      }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: app_colors.white,
      appBar: AppBar(
        backgroundColor: app_colors.table_header_bg,
        elevation: 0,
        centerTitle: false,
        title: Text("Profile",
            style: TextStyle(
                fontSize: 17.sp, fontWeight: FontWeight.w600,
                color: app_colors.black)),
        iconTheme: const IconThemeData(color: app_colors.black),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: app_colors.c_danger),
            SizedBox(height: 12.h),
            Text(_error!, textAlign: TextAlign.center),
            SizedBox(height: 16.h),
            ElevatedButton(onPressed: _fetchUserData, child: const Text('Retry')),
          ],
        ),
      );
    }

    final createdAt = _userData?['created_at'];
    String joinedDate = '-';
    if (createdAt != null && createdAt is Timestamp) {
      joinedDate = createdAt.toDate().toString().split(' ')[0];
    }

    final firstName = _userData?['first_name'] ?? '';
    final lastName = _userData?['last_name'] ?? '';
    final fullName = "$firstName $lastName".trim();
    final photoUrl = _userData?['photo_url'];
    String initials = '';
    if (firstName.isNotEmpty) initials += firstName[0].toUpperCase();
    if (lastName.isNotEmpty) initials += lastName[0].toUpperCase();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 100.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── HERO CARD ──────────────────────────────────────────
          _card(
            child: Column(
              children: [
                // Avatar
                GestureDetector(
                  onTap: _showImagePickerOptions,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 46.r,
                        backgroundColor: app_colors.LightBlue,
                        backgroundImage: photoUrl != null &&
                            photoUrl.toString().isNotEmpty
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl == null || photoUrl.toString().isEmpty
                            ? Text(
                          initials.isEmpty ? "U" : initials,
                          style: TextStyle(
                              fontSize: 26.sp,
                              fontWeight: FontWeight.bold,
                              color: app_colors.c_primary),
                        )
                            : null,
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          padding: EdgeInsets.all(5.w),
                          decoration: const BoxDecoration(
                              color: app_colors.c_primary,
                              shape: BoxShape.circle),
                          child: Icon(Icons.camera_alt_rounded,
                              size: 14.sp, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 12.h),

                Text(
                  fullName.isEmpty ? "No Name" : fullName,
                  style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      fontFamily: app_fonts.Medium),
                ),

                SizedBox(height: 4.h),

                Text(
                  _userData?['email'] ?? '',
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                ),

                SizedBox(height: 10.h),

                // Tags row
                Wrap(
                  spacing: 8.w,
                  children: [
                    if ((_userData?['company_name'] ?? '').isNotEmpty)
                      _tag(
                        icon: Icons.business_rounded,
                        label: _userData!['company_name'],
                        bg: app_colors.LightBlue,
                        fg: app_colors.c_primary,
                      ),
                    _tag(
                      icon: Icons.calendar_today_rounded,
                      label: "Joined $joinedDate",
                      bg: app_colors.LightGreen,
                      fg: app_colors.GreenColor,
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          // ── EDIT NAME ──────────────────────────────────────────
          _sectionLabel("Personal Info"),
          SizedBox(height: 10.h),

          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Full Name",
                    style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500)),
                SizedBox(height: 8.h),
                TextField(
                  controller: _nameController,
                  style: TextStyle(fontSize: 14.sp),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: "Enter full name",
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: app_colors.Dborder_color)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: app_colors.Dborder_color)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                            color: app_colors.c_primary, width: 1.4)),
                    contentPadding:
                    EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 12.h),

          // Read-only info cards
          _infoRow(Icons.email_outlined, "Email",
              _userData?['email'] ?? '-'),
          SizedBox(height: 10.h),
          _infoRow(Icons.phone_android_rounded, "Mobile",
              _userData?['mobile'] ?? '-'),
          SizedBox(height: 10.h),
          _infoRow(Icons.alternate_email_rounded, "Username",
              _userData?['username'] ?? '-'),
          SizedBox(height: 10.h),
          _infoRow(Icons.business_outlined, "Company",
              _userData?['company_name'] ?? '-'),

          SizedBox(height: 24.h),

          // ── BRANDING ───────────────────────────────────────────
          _sectionLabel("Business Branding"),
          SizedBox(height: 4.h),
          Text("Bill PDF me use hoga",
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[500])),
          SizedBox(height: 12.h),

          // Company Logo
          _brandingTile(
            title: "Company Logo",
            subtitle: "Invoice header me dikhega",
            icon: Icons.business_center_rounded,
            imageUrl: _logoUrl,
            isLoading: _logoLoading,
            onTap: () => _showBrandingOptions('logo'),
            placeholderIcon: Icons.add_photo_alternate_outlined,
          ),

          SizedBox(height: 12.h),

          // Signature
          _brandingTile(
            title: "Signature",
            subtitle: "Invoice footer me dikhega",
            icon: Icons.draw_rounded,
            imageUrl: _signatureUrl,
            isLoading: _signatureLoading,
            onTap: () => _showBrandingOptions('signature'),
            placeholderIcon: Icons.edit_outlined,
          ),

          SizedBox(height: 28.h),

          // ── SAVE BUTTON ────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50.h,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _updateDisplayName,
              style: ElevatedButton.styleFrom(
                backgroundColor: app_colors.c_primary,
                disabledBackgroundColor: app_colors.c_primary.withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r)),
              ),
              icon: _isSaving
                  ? SizedBox(
                width: 18.w, height: 18.w,
                child: const CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.save_rounded, color: Colors.white),
              label: Text(
                _isSaving ? "Saving..." : "Save Profile",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── WIDGETS ───────────────────────────────────────────────────

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: app_colors.Dbackgroun_color,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: app_colors.Dborder_color),
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w700,
          color: app_colors.black,
          fontFamily: app_fonts.Medium),
    );
  }

  Widget _tag({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: fg),
          SizedBox(width: 4.w),
          Text(label,
              style: TextStyle(
                  fontSize: 12.sp, color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: app_colors.Dbackgroun_color,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: app_colors.Dborder_color),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(9.w),
            decoration: BoxDecoration(
                color: app_colors.LightBlue,
                borderRadius: BorderRadius.circular(10.r)),
            child: Icon(icon, color: app_colors.c_primary, size: 18.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
                SizedBox(height: 3.h),
                Text(value,
                    style: TextStyle(
                        fontSize: 14.sp, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandingTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required String? imageUrl,
    required bool isLoading,
    required VoidCallback onTap,
    required IconData placeholderIcon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: app_colors.Dbackgroun_color,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: app_colors.Dborder_color),
        ),
        child: Row(
          children: [
            // Preview box
            Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: app_colors.Dborder_color),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11.r),
                child: isLoading
                    ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    placeholderIcon,
                    color: Colors.grey[400],
                    size: 28.sp,
                  ),
                )
                    : Icon(
                  placeholderIcon,
                  color: Colors.grey[400],
                  size: 28.sp,
                ),
              ),
            ),

            SizedBox(width: 14.w),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          fontFamily: app_fonts.Medium)),
                  SizedBox(height: 4.h),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12.sp, color: Colors.grey[500])),
                  SizedBox(height: 6.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: imageUrl != null && imageUrl.isNotEmpty
                          ? app_colors.LightGreen
                          : app_colors.LightBlue,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      imageUrl != null && imageUrl.isNotEmpty
                          ? "✓ Uploaded"
                          : "Tap to upload",
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: imageUrl != null && imageUrl.isNotEmpty
                            ? app_colors.GreenColor
                            : app_colors.c_primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Icon(Icons.chevron_right_rounded,
                color: Colors.grey[400], size: 22.sp),
          ],
        ),
      ),
    );
  }
}