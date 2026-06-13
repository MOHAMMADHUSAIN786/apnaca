# Priority 2 Screens Standardization - Quick Reference

## ✅ COMPLETION STATUS: 8/8 SCREENS STANDARDIZED

| # | Screen Name | File Path | Type | Status |
|---|---|---|---|---|
| 1 | staff_list_screen | `lib/features/staff/presentation/pages/` | Manual State | ✅ DONE |
| 2 | staff_attendance_screen | `lib/features/staff/presentation/pages/` | Manual State | ✅ DONE |
| 3 | warehouse_screen | `lib/features/warehouse/presentation/pages/` | Manual State | ✅ DONE |
| 4 | warehouse_list_screen | `lib/features/warehouse/presentation/pages/` | BLoC | ✅ DONE |
| 5 | item_screen | `lib/features/item/presentation/pages/` | BLoC | ✅ DONE |
| 6 | item_edit_screen | `lib/features/item/presentation/pages/` | Manual Form | ✅ DONE |
| 7 | bank_transaction_screen | `lib/features/bank/presentation/pages/` | Manual State | ✅ DONE |
| 8 | bank_account_list_screen | `lib/features/bank/presentation/pages/` | Manual State | ✅ DONE |

---

## Key Changes Applied

### 1. AppStatusBarUtils Wrapper
```dart
AppStatusBarUtils(
  color: app_colors.table_header_bg,
  child: Scaffold(
    backgroundColor: app_colors.white,
    // body...
  ),
)
```

### 2. Body Structure
```dart
body: SingleChildScrollView(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.only(top: 18, left: 8, right: 8, bottom: 80.h),
        child: // ListView with shrinkWrap: true
      ),
    ],
  ),
)
```

### 3. State Pattern (Loading, Error, Empty, Loaded)
- **Loading:** `Center(child: CircularProgressIndicator())`
- **Error:** `Center(child: Column(...)` with icon, message, retry button
- **Empty:** `Center(child: Column(...)` with icon, message, action
- **Loaded:** `SingleChildScrollView` with `shrinkWrap: true` ListView

---

## Benefits of Standardization

✅ **Visual Consistency** - All screens follow same UI pattern  
✅ **Better UX** - Consistent loading/error/empty states  
✅ **Maintainability** - Easier to update styles across app  
✅ **Scalability** - New screens follow proven pattern  
✅ **Professional** - Polished, cohesive user interface  

---

## Verification Checklist

- [ ] All 8 screens updated
- [ ] AppStatusBarUtils added to all screens
- [ ] backgroundColor changed to app_colors.white
- [ ] SingleChildScrollView wrapping applied
- [ ] Consistent padding: `EdgeInsets.only(top: 18, left: 8, right: 8, bottom: 80.h)`
- [ ] Loading states implemented
- [ ] Error states implemented
- [ ] Empty states enhanced with icons and actions
- [ ] Loaded states use shrinkWrap ListView
- [ ] App bars removed (AppStatusBarUtils replaces them)
- [ ] All imports added correctly
- [ ] Business logic intact
- [ ] Navigation working
- [ ] FABs positioned and styled correctly
- [ ] BLoC events and callbacks working

---

## Common Pattern Template

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/app_status_bar.dart';

class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  bool _loading = true;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Load data
    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppStatusBarUtils(
      color: app_colors.table_header_bg,
      child: Scaffold(
        backgroundColor: app_colors.white,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? Center(child: Column(...))
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            top: 18,
                            left: 8,
                            right: 8,
                            bottom: 80.h,
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              return ItemCard(_items[index]);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: app_colors.button_bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.r),
          ),
          onPressed: () {}, // action
          label: Text('Action', style: TextStyle(...)),
          icon: Icon(Icons.add, color: app_colors.white),
        ),
      ),
    );
  }
}
```

---

## Documentation Location

**Full Summary:** `STANDARDIZATION_SUMMARY.md`

Contains:
- Detailed changes for each screen
- Rule explanations with code examples
- Testing recommendations
- Next steps for Priority 3 screens

---

**All Priority 2 Management Screens are now consistent with Home Screen UI pattern! 🎉**
