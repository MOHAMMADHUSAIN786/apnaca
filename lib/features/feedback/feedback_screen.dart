// lib/features/feedback/presentation/pages/feedback_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _commentController = TextEditingController();

  int    _selectedStars    = 0;
  String _selectedCategory = '';
  bool   _isSubmitting     = false;

  final List<String> _categories = [
    'UI / Design',
    'Performance',
    'Features',
    'Billing',
    'Bug Report',
    'Other',
  ];

  // ── Submit to Firestore ───────────────────────────────────────────
  Future<void> _submit() async {
    if (_selectedStars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      // Fetch user name from Firestore
      String userName = 'Anonymous';
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = doc.data();
        if (data != null) {
          final fn = data['first_name'] ?? '';
          final ln = data['last_name']  ?? '';
          userName = "$fn $ln".trim().isEmpty ? (user.email ?? 'Anonymous') : "$fn $ln".trim();
        }
      }

      await FirebaseFirestore.instance.collection('feedbacks').add({
        'uid':        user?.uid ?? 'anonymous',
        'user_name':  userName,
        'email':      user?.email ?? '',
        'stars':      _selectedStars,
        'category':   _selectedCategory,
        'comment':    _commentController.text.trim(),
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🙏 Thank you for your feedback!'),
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
    _commentController.dispose();
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
          'Feedback',
          style: TextStyle(
            fontSize: 18.sp,
            fontFamily: app_fonts.Medium,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header ────────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: app_colors.table_header_bg.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.sentiment_satisfied_alt_rounded,
                      size: 40,
                      color: app_colors.black,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Share Your Experience',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontFamily: app_fonts.Medium,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Your feedback helps us improve Apna Hisab',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.black45,
                      fontFamily: app_fonts.Regular,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            SizedBox(height: 28.h),

            // ── Star Rating ───────────────────────────────────────────
            _sectionLabel('How would you rate us?'),
            SizedBox(height: 12.h),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final starIndex = i + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedStars = starIndex),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                      child: Icon(
                        starIndex <= _selectedStars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 42,
                        color: starIndex <= _selectedStars
                            ? Colors.amber.shade600
                            : Colors.grey.shade300,
                      ),
                    ),
                  );
                }),
              ),
            ),
            SizedBox(height: 8.h),
            Center(
              child: Text(
                _ratingLabel(_selectedStars),
                style: TextStyle(
                  fontSize: 13.sp,
                  fontFamily: app_fonts.Medium,
                  color: _selectedStars > 0
                      ? Colors.amber.shade700
                      : Colors.black26,
                ),
              ),
            ),

            SizedBox(height: 24.h),

            // ── Category Chips ─────────────────────────────────────────
            _sectionLabel('Category (optional)'),
            SizedBox(height: 10.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _categories.map((cat) {
                final selected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedCategory = selected ? '' : cat;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? app_colors.table_header_bg
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: selected
                            ? app_colors.table_header_bg
                            : app_colors.Dborder_color,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontFamily: selected
                            ? app_fonts.Medium
                            : app_fonts.Regular,
                        color: selected ? app_colors.black : Colors.black54,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            SizedBox(height: 24.h),

            // ── Comment ────────────────────────────────────────────────
            _sectionLabel('Additional Comments (optional)'),
            SizedBox(height: 8.h),
            TextFormField(
              controller: _commentController,
              maxLines:   5,
              decoration: InputDecoration(
                hintText:  'Tell us more about your experience...',
                hintStyle: TextStyle(fontSize: 13.sp, color: Colors.black38),
                filled:    true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: app_colors.Dborder_color),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: app_colors.Dborder_color),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(
                    color: app_colors.table_header_bg,
                    width: 1.6,
                  ),
                ),
                contentPadding: EdgeInsets.all(14.w),
              ),
            ),

            SizedBox(height: 28.h),

            // ── Submit Button ──────────────────────────────────────────
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
                  'Submit Feedback',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontFamily: app_fonts.Medium,
                    color: app_colors.black,
                  ),
                ),
              ),
            ),

            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 13.sp,
      fontFamily: app_fonts.Medium,
      color: Colors.black87,
    ),
  );

  String _ratingLabel(int stars) {
    switch (stars) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Very Good';
      case 5: return 'Excellent! 🎉';
      default: return 'Tap to rate';
    }
  }
}