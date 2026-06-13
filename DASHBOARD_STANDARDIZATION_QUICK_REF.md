# Dashboard Standardization Quick Reference

## Quick Copy-Paste Template

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_status_bar.dart';
import '../../../../core/constants/app_colors.dart';

class YourDashboardScreen extends StatefulWidget {
  const YourDashboardScreen({super.key});

  @override
  State<YourDashboardScreen> createState() => _YourDashboardScreenState();
}

class _YourDashboardScreenState extends State<YourDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return AppStatusBarUtils(
      color: app_colors.table_header_bg,
      child: Scaffold(
        backgroundColor: app_colors.white,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // FIRST ITEM - Use this padding
              Padding(
                padding: const EdgeInsets.only(top: 18, left: 8, right: 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Your content here
                      ],
                    ),
                  ),
                ),
              ),
              
              // MIDDLE ITEMS - Use this padding (same as first)
              Padding(
                padding: const EdgeInsets.only(top: 18, left: 8, right: 8),
                child: Card(
                  // Your content
                ),
              ),
              
              // LAST ITEM - Use this padding with bottom: 80.h
              Padding(
                padding: EdgeInsets.only(top: 18, left: 8, right: 8, bottom: 80.h),
                child: Card(
                  // Your content
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
```

## Key Points to Remember

1. **Always wrap Scaffold with AppStatusBarUtils**
   - `color: app_colors.table_header_bg`

2. **Always set Scaffold backgroundColor**
   - `backgroundColor: app_colors.white`

3. **Always use SingleChildScrollView**
   - Not Padding + Column
   - Not ListView at body level

4. **Padding Pattern**
   - First to middle items: `EdgeInsets.only(top: 18, left: 8, right: 8)`
   - Last item: Add `bottom: 80.h`

5. **Remove AppBar**
   - AppStatusBar replaces it

6. **For ListViews inside Column**
   - Remove `Expanded`
   - Add `shrinkWrap: true`
   - Add `physics: NeverScrollableScrollPhysics()`

7. **Imports Required**
   ```dart
   import 'package:flutter_screenutil/flutter_screenutil.dart';
   import '../../../../core/constants/app_status_bar.dart';
   import '../../../../core/constants/app_colors.dart';
   ```

## Check Dart Analysis

```bash
dart analyze lib/features/{feature}/presentation/pages/{screen_name}.dart
```

Should return: `No issues found!`

## If Using Responsive Units

Use `.h` for height and `.w` for width:
- `EdgeInsets.only(top: 18.h, left: 8.w, right: 8.w, bottom: 80.h)`

## Common Fixes

### Deprecated Warning: 'value' in DropdownButtonFormField
```dart
// Wrong (deprecated)
DropdownButtonFormField(value: _selected, ...)

// Correct (new)
DropdownButtonFormField(initialValue: _selected, ...)
```

### Unused Import Warning
Remove any unused imports from dashboard screens

### Missing Parenthesis Error
Ensure all nested Widgets close properly:
```dart
Padding(
  child: Card(
    child: ListTile(...),  // ← ListTile closes
  ),                       // ← Card closes
),                         // ← Padding closes
```

## Standardized Screens (Completed)

✅ Home Screen (original pattern)
✅ GST Dashboard
✅ Ecommerce Dashboard
✅ CRM Dashboard
✅ Franchise Dashboard

## Pattern Consistency

All standardized screens now have:
- ✅ Same status bar color
- ✅ Same background color
- ✅ Same scroll behavior
- ✅ Same padding/spacing
- ✅ Same structure hierarchy
- ✅ Same import patterns
