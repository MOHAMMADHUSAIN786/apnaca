# Dashboard Screen Standardization Plan

## Overview
Standardize 4 Dashboard screens (Priority 3) to match Home Screen UI pattern with consistent status bar, colors, scrolling, and padding.

## Current State Analysis

### 1. gst_dashboard_screen.dart
- ✗ Uses custom AppBar (title: 'GST Compliance Suite')
- ✓ Has SingleChildScrollView but with padding: all(16)
- ✗ Missing AppStatusBarUtils wrapper
- ✗ Missing app_status_bar and app_colors imports
- ✓ Has loading state (_isLoading)
- **Content**: GST forms, period dropdown, compliance cards, e-invoice section

### 2. ecommerce_dashboard_screen.dart
- ✗ Uses custom AppBar (title: 'E-Commerce Integration')
- ✗ No SingleChildScrollView (only Padding + Column)
- ✗ Missing AppStatusBarUtils wrapper
- ✗ Missing app_status_bar and app_colors imports
- ✓ Has sync state (_isSyncing)
- **Content**: Shopify/WooCommerce card, sync button, recent sync logs in ListView

### 3. crm_dashboard_screen.dart
- ✗ Uses custom AppBar (title: 'CRM & Lead Management')
- ✗ No SingleChildScrollView (only Padding + Column)
- ✗ Missing AppStatusBarUtils wrapper
- ✗ Missing app_status_bar and app_colors imports
- ✓ Has FloatingActionButton
- **Content**: Metric cards (Open Leads, Pending Follow-ups), today's follow-ups ListView, FAB

### 4. franchise_dashboard_screen.dart
- ✗ Uses custom AppBar (title: 'Franchise Management')
- ✗ No SingleChildScrollView (only Padding + Column)
- ✗ Missing AppStatusBarUtils wrapper
- ✗ Missing app_status_bar and app_colors imports
- ✓ Has FloatingActionButton
- **Content**: Metric cards (Active Outlets, Total Royalty), outlets ListView, FAB

## Standardization Rules

### Imports to Add
```dart
import '../../../../core/constants/app_status_bar.dart';
import '../../../../core/constants/app_colors.dart';
```

### Structure Template
```dart
AppStatusBarUtils(
  color: app_colors.table_header_bg,
  child: Scaffold(
    backgroundColor: app_colors.white,
    body: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Content with consistent padding
        ],
      ),
    ),
  ),
)
```

### Padding Rules
- Wrap content items in Padding with: `EdgeInsets.only(top: 18, left: 8, right: 8)`
- Last item adds `bottom: 80.h` to prevent overlap with FAB/nav bar
- Import `flutter_screenutil` for `.h` responsive units if using bottom: 80.h

### State Management
- **GST Dashboard**: Convert _isLoading pattern to use Loading state display
- **Ecommerce Dashboard**: Keep _isSyncing state, enhance with error state
- **CRM Dashboard**: Keep current state patterns
- **Franchise Dashboard**: Keep current state patterns

### Error Handling Pattern (if needed)
```dart
if (state is DashboardLoading) {
  return Center(child: CircularProgressIndicator());
}
if (state is DashboardError) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 64, color: Colors.red),
        SizedBox(height: 16),
        Text('Error: ${state.message}'),
        ElevatedButton(
          onPressed: () { /* retry */ },
          child: Text('Retry'),
        ),
      ],
    ),
  );
}
```

## Implementation Steps

### Step 1: GST Dashboard Screen (gst_dashboard_screen.dart)
- Add imports for app_status_bar, app_colors, flutter_screenutil
- Wrap with AppStatusBarUtils + Scaffold structure
- Remove AppBar
- Update SingleChildScrollView padding to use consistent pattern
- Wrap each Card/widget in Padding with EdgeInsets.only(top: 18, left: 8, right: 8)
- Add bottom: 80.h to last visible item
- Preserve all GST-specific widgets and logic

### Step 2: Ecommerce Dashboard Screen (ecommerce_dashboard_screen.dart)
- Add imports for app_status_bar, app_colors, flutter_screenutil
- Wrap with AppStatusBarUtils + Scaffold structure
- Remove AppBar
- Replace Padding + Column with SingleChildScrollView + Column
- Wrap each widget section in Padding with consistent EdgeInsets
- Add bottom: 80.h to last section
- Preserve sync button and recent logs ListView

### Step 3: CRM Dashboard Screen (crm_dashboard_screen.dart)
- Add imports for app_status_bar, app_colors, flutter_screenutil
- Wrap with AppStatusBarUtils + Scaffold structure
- Remove AppBar
- Replace Padding + Column with SingleChildScrollView + Column
- Wrap sections in Padding with consistent EdgeInsets
- Add bottom: 80.h to last section
- Keep FloatingActionButton intact
- Preserve all CRM widgets

### Step 4: Franchise Dashboard Screen (franchise_dashboard_screen.dart)
- Add imports for app_status_bar, app_colors, flutter_screenutil
- Wrap with AppStatusBarUtils + Scaffold structure
- Remove AppBar
- Replace Padding + Column with SingleChildScrollView + Column
- Wrap sections in Padding with consistent EdgeInsets
- Add bottom: 80.h to last section
- Keep FloatingActionButton intact
- Preserve all franchise widgets

## Important Notes

1. **Preserve Business Logic**: All dashboard-specific functionality, data fetching, and calculations remain unchanged
2. **Keep Dashboard Widgets**: All custom cards, metrics displays, charts remain exactly as-is
3. **FloatingActionButtons**: Keep FABs in CRM and Franchise dashboards
4. **State Management**: Maintain existing state patterns (setState for GST, _isSyncing for Ecommerce)
5. **Color Consistency**: Use app_colors constants instead of hardcoded colors where applicable (optional enhancement)
6. **Responsive Units**: Use .h suffix for bottom padding if using flutter_screenutil

## Testing Checklist

- [ ] Status bar displays with correct background color (table_header_bg)
- [ ] Scaffold background is white (app_colors.white)
- [ ] Content scrolls properly in SingleChildScrollView
- [ ] Padding is consistent across all items
- [ ] No AppBar visible (replaced by AppStatusBar)
- [ ] All dashboard functionality works (forms, buttons, lists)
- [ ] Loading/Error states display correctly
- [ ] FloatingActionButtons visible and functional (CRM, Franchise)
- [ ] Bottom padding prevents content overlap with nav/FAB
- [ ] Imports are correct and no build errors

## Files to Modify
1. `lib/features/gst/presentation/pages/gst_dashboard_screen.dart`
2. `lib/features/ecommerce/presentation/pages/ecommerce_dashboard_screen.dart`
3. `lib/features/crm/presentation/pages/crm_dashboard_screen.dart`
4. `lib/features/franchise/presentation/pages/franchise_dashboard_screen.dart`
