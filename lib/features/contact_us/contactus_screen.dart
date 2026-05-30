// lib/features/contact/presentation/pages/contact_us_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController    = TextEditingController();
  final _emailController   = TextEditingController();
  final _queryController   = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _prefillUser();
  }

  // ── Pre-fill name + email from Firebase Auth ──────────────────────
  Future<void> _prefillUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;
      final data = doc.data();
      if (data == null) return;

      final firstName = data['first_name'] ?? '';
      final lastName  = data['last_name']  ?? '';
      _nameController.text  = "$firstName $lastName".trim();
      _emailController.text = data['email'] ?? user.email ?? '';
      setState(() {});
    } catch (_) {}
  }

  // ── Submit to Firestore ───────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('contact_queries').add({
        'uid':        user?.uid ?? 'anonymous',
        'name':       _nameController.text.trim(),
        'email':      _emailController.text.trim(),
        'query':      _queryController.text.trim(),
        'created_at': FieldValue.serverTimestamp(),
        'status':     'open',
      });

      if (!mounted) return;
      _queryController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Query submitted! We will get back to you soon.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to submit: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: app_colors.table_header_bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Contact Us',
          style: TextStyle(
            fontSize: 18.sp,
            fontFamily: app_fonts.Medium,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Header card ────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: app_colors.table_header_bg.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: app_colors.Dborder_color),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: app_colors.Dborder_color),
                      ),
                      child: Icon(
                        Icons.support_agent_rounded,
                        size: 28,
                        color: app_colors.black,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How can we help?',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontFamily: app_fonts.Medium,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Fill the form below and we will respond within 24 hours.',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontFamily: app_fonts.Regular,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              // ── Name ───────────────────────────────────────────────
              _label('Full Name'),
              SizedBox(height: 6.h),
              _buildField(
                controller:  _nameController,
                hint:        'Enter your name',
                icon:        Icons.person_outline,
                validator:   (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),

              SizedBox(height: 16.h),

              // ── Email ──────────────────────────────────────────────
              _label('Email Address'),
              SizedBox(height: 6.h),
              _buildField(
                controller:   _emailController,
                hint:         'Enter your email',
                icon:         Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator:    (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  final reg = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!reg.hasMatch(v.trim())) return 'Enter a valid email';
                  return null;
                },
              ),

              SizedBox(height: 16.h),

              // ── Query ──────────────────────────────────────────────
              _label('Your Query'),
              SizedBox(height: 6.h),
              _buildField(
                controller: _queryController,
                hint:       'Describe your issue or question...',
                icon:       Icons.help_outline,
                maxLines:   5,
                validator:  (v) => v == null || v.trim().isEmpty ? 'Please enter your query' : null,
              ),

              SizedBox(height: 28.h),

              // ── Submit Button ──────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: app_colors.table_header_bg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: app_colors.black,
                    ),
                  )
                      : Text(
                    'Submit Query',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontFamily: app_fonts.Medium,
                      color: app_colors.black,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 24.h),

              // ── Email contact info ─────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Text(
                      'Or reach us directly at',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.black45,
                        fontFamily: app_fonts.Regular,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'apnaca786@gmail.com',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontFamily: app_fonts.Medium,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 13.sp,
      fontFamily: app_fonts.Medium,
      color: Colors.black87,
    ),
  );

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller:   controller,
      keyboardType: keyboardType,
      maxLines:     maxLines,
      validator:    validator,
      decoration: InputDecoration(
        hintText:   hint,
        prefixIcon: maxLines == 1 ? Icon(icon, size: 20) : null,
        filled:     true,
        fillColor:  Colors.grey.shade50,
        hintStyle:  TextStyle(fontSize: 13.sp, color: Colors.black38),
        border:     OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide:   BorderSide(color: app_colors.Dborder_color),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide:   BorderSide(color: app_colors.Dborder_color),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide:   BorderSide(color: app_colors.table_header_bg, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide:   const BorderSide(color: Colors.red),
        ),
        contentPadding: maxLines > 1
            ? EdgeInsets.all(14.w)
            : EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      ),
    );
  }
}