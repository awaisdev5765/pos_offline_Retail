# Settings & Printer Configuration Fixes

## Issues Fixed

### 1. **Currency Symbol Not Saving**
**Problem:** When changing currency in settings, only `currency_code` was saved, but `currency_symbol` was not being saved to the database.

**Fix:** Updated `currency_provider.dart` to save both currency code AND symbol:
```dart
await databaseService.setSetting('currency_code', currency.code);
await databaseService.setSetting('currency_symbol', currency.symbol); // ← ADDED
```

**Location:** `lib/providers/currency_provider.dart` (Line 47)

---

### 2. **Settings Save Not Validating Input**
**Problem:** The `_saveSettings()` method had no validation, allowing empty business names and invalid tax rates.

**Fix:** Added comprehensive validation:
- ✓ Business name is required (cannot be empty)
- ✓ Tax rate must be a number between 0-100
- ✓ All text fields are trimmed before saving
- ✓ Currency is properly saved when changed
- ✓ Language/locale is saved
- ✓ All UI toggles (dark mode, hide stats, bundles) are saved

**Location:** `lib/screens/settings_screen.dart` (Lines 2633-2718)

---

### 3. **Currency Not Saved in Main Save Button**
**Problem:** Currency was only saved when the dropdown changed, not when clicking the main "Save Settings" button.

**Fix:** The `_saveSettings()` method now explicitly saves currency:
```dart
if (_selectedCurrency != null) {
  await databaseService.setSetting('currency_code', _selectedCurrency!.code);
  await databaseService.setSetting('currency_symbol', _selectedCurrency!.symbol);
  
  // Update currency provider
  final currencyNotifier = ref.read(currencyProvider.notifier);
  await currencyNotifier.changeCurrency(_selectedCurrency!);
}
```

**Location:** `lib/screens/settings_screen.dart` (Lines 2667-2675)

---

### 4. **Missing Settings Being Saved**
**Problem:** Several settings were not being saved when clicking the save button:
- `bundles_enabled` toggle
- `locale_code` (language setting)

**Fix:** Added these to the save method:
```dart
await databaseService.setSetting('bundles_enabled', _bundlesEnabled.toString());
await databaseService.setSetting('locale_code', _effectiveLocaleCode(context));
```

**Location:** `lib/screens/settings_screen.dart` (Lines 2690-2693)

---

## What Gets Saved Now

### Business Information Section
When you click the **Save** button (top-right corner):

| Setting | Database Key | Validated | Notes |
|---------|-------------|-----------|-------|
| Business Name | `business_name` | ✓ Required | Trimmed of whitespace |
| Business Address | `business_address` | - | Trimmed of whitespace |
| Business Phone | `business_phone` | - | Trimmed of whitespace |
| Tax Rate | `tax_rate` | ✓ 0-100% | Must be valid number |
| Currency | `currency_code` + `currency_symbol` | ✓ | Both saved together |
| Language | `locale_code` | ✓ | en, fr, or ar |
| Dark Mode | `dark_mode` | - | true/false |
| Hide Stats Cards | `hide_stats_cards` | - | true/false |
| Bundles Enabled | `bundles_enabled` | - | true/false |

---

### Printer & Receipt Configuration
Printer settings are saved in the **Receipt Customization Screen** (separate screen):

| Setting | Database Key | Notes |
|---------|-------------|-------|
| Printer IP/Name | `printer_ip` | IP address or Windows printer name |
| Printer Port | `printer_port` | Default: 9100 |
| Receipt Type | `receipt_type` | "thermal" or "a4" |

**Additional Print Profile Settings** (saved to SharedPreferences):
- Printer type (thermal, A4, network, bluetooth)
- Paper size (58mm, 80mm, A4, Letter)
- Orientation (portrait/landscape)
- Margins (top, bottom, left, right)
- Display options (logo, business info, customer info, etc.)
- Font settings (size, family)
- Copies, auto-cut, cash drawer

**Location:** `lib/screens/receipt_customization_screen.dart` (Lines 2140-2170)

---

## How to Use

### Saving Business Settings
1. Open **Settings** from the main menu
2. Fill in:
   - Business Name (required)
   - Business Address
   - Business Phone
   - Tax Rate (0-100)
   - Currency (tap to select)
   - Language
   - Toggle Dark Mode, Hide Stats, Bundles
3. Click the **Save** icon (💾) in the top-right corner
4. You'll see: "✓ Settings saved successfully"

### Saving Printer Settings
1. Go to **Settings** → **Receipt & Printer Management**
2. Click **Open Receipt & Printer Management**
3. Configure:
   - Receipt Type (Thermal or A4)
   - Printer IP Address or Name
   - Port (usually 9100)
   - Select Windows printer (if on Windows)
   - Template settings (logo, fonts, etc.)
4. Click **Save Template & Printer Settings**
5. You'll see: "Receipt template and printer settings saved successfully!"

---

## Error Handling

### Validation Errors
- **Empty business name:** Shows red snackbar "Business name is required"
- **Invalid tax rate:** Shows "Tax rate must be a number between 0 and 100"

### Save Errors
- If any database error occurs, shows red snackbar with error details
- Loading indicator shows while saving
- All settings are saved in a transaction-like manner

### Success Feedback
- Green snackbar with checkmark: "✓ Settings saved successfully"
- Auto-dismisses after 2 seconds

---

## Testing Checklist

- [ ] Change business name and save → verify it persists after app restart
- [ ] Change currency and save → verify symbol appears correctly on POS
- [ ] Set tax rate to 15 → verify it's saved and applied to sales
- [ ] Enable dark mode → verify it persists
- [ ] Change language to Arabic → verify RTL layout works
- [ ] Leave business name empty → verify validation error shows
- [ ] Set tax rate to 150 → verify validation error shows
- [ ] Configure printer IP and save → verify it prints to correct printer
- [ ] Switch from thermal to A4 receipt → verify preview changes

---

## Files Modified

1. **lib/providers/currency_provider.dart**
   - Added `currency_symbol` to save operation

2. **lib/screens/settings_screen.dart**
   - Added validation for business name (required)
   - Added validation for tax rate (0-100)
   - Added currency save to main save button
   - Added bundles_enabled save
   - Added locale_code save
   - Improved success/error messages
   - Added trim() to all text fields

---

## Notes

- Currency changes are saved **twice**: once when dropdown changes, and once when Save button is clicked (for safety)
- Printer settings are saved in **two places**: database (for legacy compatibility) and SharedPreferences (for runtime use)
- All text inputs are trimmed before saving to prevent whitespace issues
- The save operation is **asynchronous** with proper loading states
- Error handling prevents partial saves (all-or-nothing approach)

---

## Future Improvements

Consider adding:
1. Auto-save with debounce (saves 1 second after user stops typing)
2. "Reset to defaults" button
3. Export/import settings as JSON
4. Settings change history/audit log
5. Backup settings before major changes
6. Test print button in printer settings
7. Printer auto-detection on Windows
8. Multiple printer profiles (save different configurations)
