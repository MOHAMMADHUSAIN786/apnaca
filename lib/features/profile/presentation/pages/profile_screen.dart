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
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState
    extends State<ProfileScreen> {

  Map<String, dynamic>? _userData;

  bool _isLoading = true;

  bool _isSaving = false;

  String? _error;

  final TextEditingController
  _nameController =
  TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // ─────────────────────────────────────────────
  // FETCH USER
  // ─────────────────────────────────────────────

  Future<void> _fetchUserData() async {

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {

      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception(
            'User not logged in');
      }

      final doc =
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        throw Exception(
            'User not found');
      }

      final data = doc.data()!;

      _userData = data;

      _nameController.text =
          "${data['first_name'] ?? ''} ${data['last_name'] ?? ''}"
              .trim();

      setState(() {
        _isLoading = false;
      });

    } catch (e) {

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ─────────────────────────────────────────────
  // UPDATE NAME
  // ─────────────────────────────────────────────

  Future<void> _updateDisplayName() async {

    final fullName =
    _nameController.text.trim();

    if (fullName.isEmpty) return;

    final parts =
    fullName.split(' ');

    final firstName =
        parts.first;

    final lastName =
    parts.length > 1
        ? parts.sublist(1).join(' ')
        : '';

    setState(() {
      _isSaving = true;
    });

    try {

      final uid =
          FirebaseAuth.instance
              .currentUser!
              .uid;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({

        'first_name': firstName,

        'last_name': lastName,
      });

      await FirebaseAuth.instance
          .currentUser
          ?.updateDisplayName(
          fullName);

      await _fetchUserData();

      if (mounted) {

        ScaffoldMessenger.of(context)
            .showSnackBar(

          const SnackBar(
            content: Text(
                'Profile updated'),
          ),
        );
      }

    } catch (e) {

      ScaffoldMessenger.of(context)
          .showSnackBar(

        SnackBar(
          content:
          Text('Error: $e'),
          backgroundColor:
          Colors.red,
        ),
      );

    } finally {

      setState(() {
        _isSaving = false;
      });
    }
  }

  // ─────────────────────────────────────────────
  // PROFILE IMAGE OPTIONS
  // ─────────────────────────────────────────────

  Future<void>
  _showImagePickerOptions() async {

    showModalBottomSheet(

      context: context,

      backgroundColor:
      Colors.white,

      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(
          top: Radius.circular(
              22.r),
        ),
      ),

      builder: (context) {

        return SafeArea(

          child: Padding(

            padding:
            EdgeInsets.all(18.w),

            child: Column(

              mainAxisSize:
              MainAxisSize.min,

              children: [

                Container(
                  width: 60.w,
                  height: 5.h,

                  decoration:
                  BoxDecoration(
                    color:
                    Colors.grey[300],

                    borderRadius:
                    BorderRadius.circular(
                        20.r),
                  ),
                ),

                SizedBox(height: 20.h),

                Text(
                  "Profile Photo",

                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                SizedBox(height: 20.h),

                Row(

                  mainAxisAlignment:
                  MainAxisAlignment
                      .spaceEvenly,

                  children: [

                    _imageOption(

                      icon:
                      Icons.camera_alt,

                      label: "Camera",

                      onTap: () {

                        Navigator.pop(
                            context);

                        _pickAndUploadImage(
                          ImageSource
                              .camera,
                        );
                      },
                    ),

                    _imageOption(

                      icon:
                      Icons.photo,

                      label: "Gallery",

                      onTap: () {

                        Navigator.pop(
                            context);

                        _pickAndUploadImage(
                          ImageSource
                              .gallery,
                        );
                      },
                    ),

                    _imageOption(

                      icon:
                      Icons.delete,

                      label: "Remove",

                      color: Colors.red,

                      onTap: () {

                        Navigator.pop(
                            context);

                        _removeProfileImage();
                      },
                    ),
                  ],
                ),

                SizedBox(height: 20.h),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // IMAGE OPTION WIDGET
  // ─────────────────────────────────────────────

  Widget _imageOption({

    required IconData icon,

    required String label,

    required VoidCallback onTap,

    Color color =
        app_colors.c_primary,
  }) {

    return GestureDetector(

      onTap: onTap,

      child: Column(

        children: [

          Container(

            padding:
            EdgeInsets.all(16.w),

            decoration:
            BoxDecoration(

              color:
              color.withOpacity(0.1),

              shape:
              BoxShape.circle,
            ),

            child: Icon(
              icon,
              color: color,
              size: 28.sp,
            ),
          ),

          SizedBox(height: 8.h),

          Text(
            label,

            style: TextStyle(
              fontSize: 13.sp,
              fontWeight:
              FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // PICK IMAGE
  // ─────────────────────────────────────────────

  Future<void>
  _pickAndUploadImage(
      ImageSource source) async {

    try {

      final ImagePicker picker =
      ImagePicker();

      final XFile? pickedFile =
      await picker.pickImage(

        source: source,

        imageQuality: 70,
      );

      if (pickedFile == null) return;

      setState(() {
        _isSaving = true;
      });

      final user =
      FirebaseAuth.instance
          .currentUser!;

      final file =
      File(pickedFile.path);

      final ref =
      FirebaseStorage.instance
          .ref()
          .child(
          'profile_pictures/${user.uid}.jpg');

      await ref.putFile(file);

      final downloadUrl =
      await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({

        'photo_url':
        downloadUrl,
      });

      await user.updatePhotoURL(
          downloadUrl);

      await _fetchUserData();

      if (mounted) {

        ScaffoldMessenger.of(context)
            .showSnackBar(

          const SnackBar(
            content: Text(
                'Profile picture updated'),
          ),
        );
      }

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context)
            .showSnackBar(

          SnackBar(
            content: Text(
                'Upload failed: $e'),
            backgroundColor:
            Colors.red,
          ),
        );
      }

    } finally {

      if (mounted) {

        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ─────────────────────────────────────────────
  // REMOVE IMAGE
  // ─────────────────────────────────────────────

  Future<void>
  _removeProfileImage() async {

    try {

      setState(() {
        _isSaving = true;
      });

      final user =
      FirebaseAuth.instance
          .currentUser!;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({

        'photo_url': '',
      });

      await user.updatePhotoURL(
          null);

      try {

        await FirebaseStorage.instance
            .ref()
            .child(
            'profile_pictures/${user.uid}.jpg')
            .delete();

      } catch (_) {}

      await _fetchUserData();

      if (mounted) {

        ScaffoldMessenger.of(context)
            .showSnackBar(

          const SnackBar(
            content: Text(
                'Profile photo removed'),
          ),
        );
      }

    } catch (e) {

      ScaffoldMessenger.of(context)
          .showSnackBar(

        SnackBar(
          content:
          Text('Error: $e'),
          backgroundColor:
          Colors.red,
        ),
      );

    } finally {

      setState(() {
        _isSaving = false;
      });
    }
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
      app_colors.white,

      appBar: AppBar(

        backgroundColor:
        app_colors.table_header_bg,

        elevation: 0,

        title: Text(

          "Profile",

          style: TextStyle(
            fontSize: 17.sp,
            fontWeight:
            FontWeight.w600,
          ),
        ),
      ),

      body: _buildBody(),
    );
  }

  Widget _buildBody() {

    if (_isLoading) {

      return const Center(
        child:
        CircularProgressIndicator(),
      );
    }

    if (_error != null) {

      return Center(
        child: Text(_error!),
      );
    }

    final createdAt =
    _userData?['created_at'];

    String joinedDate = '-';

    if (createdAt != null &&
        createdAt is Timestamp) {

      joinedDate = createdAt
          .toDate()
          .toString()
          .split(' ')[0];
    }

    final firstName =
        _userData?['first_name'] ?? '';

    final lastName =
        _userData?['last_name'] ?? '';

    final fullName =
    "$firstName $lastName"
        .trim();

    final photoUrl =
    _userData?['photo_url'];

    String initials = '';

    if (firstName.isNotEmpty) {
      initials +=
          firstName[0].toUpperCase();
    }

    if (lastName.isNotEmpty) {
      initials +=
          lastName[0].toUpperCase();
    }

    return SingleChildScrollView(

      padding:
      EdgeInsets.all(14.w),

      child: Column(

        children: [

          // HERO CARD

          Container(

            padding:
            EdgeInsets.all(18.w),

            decoration:
            BoxDecoration(

              color:
              app_colors
                  .Dbackgroun_color,

              borderRadius:
              BorderRadius.circular(
                  18.r),

              border: Border.all(
                color: app_colors
                    .Dborder_color,
              ),
            ),

            child: Column(

              children: [

                GestureDetector(

                  onTap:
                  _showImagePickerOptions,

                  child: Stack(

                    children: [

                      CircleAvatar(

                        radius: 48.r,

                        backgroundColor:
                        app_colors
                            .LightBlue,

                        backgroundImage:
                        photoUrl != null &&
                            photoUrl
                                .toString()
                                .isNotEmpty
                            ? NetworkImage(
                          photoUrl,
                        )
                            : null,

                        child:
                        photoUrl ==
                            null ||
                            photoUrl
                                .toString()
                                .isEmpty
                            ? Text(

                          initials
                              .isEmpty
                              ? "U"
                              : initials,

                          style:
                          TextStyle(

                            fontSize:
                            28.sp,

                            fontWeight:
                            FontWeight
                                .bold,

                            color:
                            app_colors
                                .c_primary,
                          ),
                        )
                            : null,
                      ),

                      Positioned(

                        bottom: 0,

                        right: 0,

                        child: Container(

                          padding:
                          EdgeInsets
                              .all(
                              6.w),

                          decoration:
                          BoxDecoration(

                            color:
                            app_colors
                                .c_primary,

                            shape:
                            BoxShape
                                .circle,
                          ),

                          child: Icon(

                            Icons
                                .camera_alt,

                            size:
                            16.sp,

                            color:
                            Colors
                                .white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 14.h),

                Text(

                  fullName.isEmpty
                      ? "No Name"
                      : fullName,

                  style: TextStyle(

                    fontSize:
                    22.sp,

                    fontWeight:
                    FontWeight.bold,

                    fontFamily:
                    app_fonts
                        .Medium,
                  ),
                ),

                SizedBox(height: 6.h),

                Text(

                  _userData?['email']
                      ?? '',

                  style: TextStyle(

                    fontSize:
                    13.sp,

                    color:
                    Colors.grey[700],
                  ),
                ),

                SizedBox(height: 6.h),

                Container(

                  padding:
                  EdgeInsets.symmetric(
                    horizontal:
                    12.w,
                    vertical:
                    5.h,
                  ),

                  decoration:
                  BoxDecoration(

                    color:
                    app_colors
                        .LightBlue,

                    borderRadius:
                    BorderRadius.circular(
                        20.r),
                  ),

                  child: Text(

                    _userData?[
                    'company_name']
                        ?? '',

                    style: TextStyle(

                      fontSize:
                      12.sp,

                      color:
                      app_colors
                          .c_primary,

                      fontWeight:
                      FontWeight
                          .bold,
                    ),
                  ),
                ),

                SizedBox(height: 10.h),

                Container(

                  padding:
                  EdgeInsets.symmetric(
                    horizontal:
                    12.w,
                    vertical:
                    6.h,
                  ),

                  decoration:
                  BoxDecoration(

                    color:
                    Colors.white,

                    borderRadius:
                    BorderRadius.circular(
                        20.r),
                  ),

                  child: Text(

                    "Member Since $joinedDate",

                    style: TextStyle(

                      fontSize:
                      12.sp,

                      color:
                      app_colors
                          .c_primary,

                      fontWeight:
                      FontWeight
                          .w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20.h),

          // NAME EDIT

          Container(

            padding:
            EdgeInsets.all(14.w),

            decoration:
            BoxDecoration(

              color:
              app_colors
                  .Dbackgroun_color,

              borderRadius:
              BorderRadius.circular(
                  16.r),

              border: Border.all(
                color: app_colors
                    .Dborder_color,
              ),
            ),

            child: Column(

              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [

                Text(

                  "Full Name",

                  style: TextStyle(

                    fontSize:
                    13.sp,

                    color:
                    Colors.grey[700],

                    fontWeight:
                    FontWeight.w500,
                  ),
                ),

                SizedBox(height: 10.h),

                TextField(

                  controller:
                  _nameController,

                  decoration:
                  InputDecoration(

                    filled: true,

                    fillColor:
                    Colors.white,

                    hintText:
                    "Enter name",

                    border:
                    OutlineInputBorder(

                      borderRadius:
                      BorderRadius.circular(
                          12.r),

                      borderSide:
                      BorderSide(
                        color:
                        app_colors
                            .Dborder_color,
                      ),
                    ),

                    enabledBorder:
                    OutlineInputBorder(

                      borderRadius:
                      BorderRadius.circular(
                          12.r),

                      borderSide:
                      BorderSide(
                        color:
                        app_colors
                            .Dborder_color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 18.h),

          _infoCard(
            icon:
            Icons.email_outlined,
            title: "Email",
            value:
            _userData?['email']
                ?? '-',
          ),

          SizedBox(height: 12.h),

          _infoCard(
            icon:
            Icons.phone_android,
            title: "Mobile",
            value:
            _userData?['mobile']
                ?? '-',
          ),

          SizedBox(height: 12.h),

          _infoCard(
            icon:
            Icons.alternate_email,
            title: "Username",
            value:
            _userData?['username']
                ?? '-',
          ),

          SizedBox(height: 12.h),

          _infoCard(
            icon:
            Icons.business_outlined,
            title: "Company",
            value:
            _userData?[
            'company_name']
                ?? '-',
          ),

          SizedBox(height: 24.h),

          SizedBox(

            width: double.infinity,

            height: 50.h,

            child:
            ElevatedButton.icon(

              onPressed:
              _isSaving
                  ? null
                  : _updateDisplayName,

              style:
              ElevatedButton
                  .styleFrom(

                backgroundColor:
                app_colors
                    .c_primary,

                shape:
                RoundedRectangleBorder(

                  borderRadius:
                  BorderRadius.circular(
                      14.r),
                ),
              ),

              icon:
              _isSaving
                  ? SizedBox(

                width: 18.w,

                height: 18.w,

                child:
                const CircularProgressIndicator(
                  strokeWidth:
                  2,
                  color: Colors
                      .white,
                ),
              )
                  : const Icon(

                Icons.save,

                color:
                Colors.white,
              ),

              label: Text(

                "Save Profile",

                style:
                TextStyle(

                  color:
                  Colors.white,

                  fontSize:
                  15.sp,

                  fontWeight:
                  FontWeight
                      .w600,
                ),
              ),
            ),
          ),

          SizedBox(height: 100.h),
        ],
      ),
    );
  }

  Widget _infoCard({

    required IconData icon,

    required String title,

    required String value,
  }) {

    return Container(

      padding:
      EdgeInsets.all(14.w),

      decoration: BoxDecoration(

        color:
        app_colors
            .Dbackgroun_color,

        borderRadius:
        BorderRadius.circular(
            14.r),

        border: Border.all(
          color:
          app_colors
              .Dborder_color,
        ),
      ),

      child: Row(

        children: [

          Container(

            padding:
            EdgeInsets.all(10.w),

            decoration:
            BoxDecoration(

              color:
              app_colors
                  .LightBlue,

              borderRadius:
              BorderRadius.circular(
                  10.r),
            ),

            child: Icon(
              icon,
              color:
              app_colors
                  .c_primary,
            ),
          ),

          SizedBox(width: 12.w),

          Expanded(

            child: Column(

              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [

                Text(

                  title,

                  style: TextStyle(

                    fontSize:
                    12.sp,

                    color:
                    Colors.grey,
                  ),
                ),

                SizedBox(height: 4.h),

                Text(

                  value,

                  style: TextStyle(

                    fontSize:
                    14.sp,

                    fontWeight:
                    FontWeight
                        .w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}