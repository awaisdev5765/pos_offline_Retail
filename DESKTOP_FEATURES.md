# Desktop Features Implementation

This document describes the desktop-specific features that have been implemented to enhance the desktop experience of the POS system.

## Features Implemented

### 1. Window Management ✅
- **Minimize, Maximize, Restore**: Full window control functionality
- **Window Controls Widget**: Custom window control buttons available for use in app bars
- **Keyboard Shortcuts**: 
  - `Alt + Enter`: Toggle maximize/restore
  - `F11`: Toggle fullscreen
  - `Alt + F4`: Close application (with confirmation)

**Usage:**
```dart
import 'package:offline_pos_system/widgets/window_controls.dart';

// Add to AppBar actions
actions: [
  WindowControls(),
  // ... other actions
],
```

**Service:**
```dart
import 'package:offline_pos_system/services/window_manager_service.dart';

// Minimize window
await WindowManagerService.minimize();

// Maximize window
await WindowManagerService.maximize();

// Restore window
await WindowManagerService.restore();

// Toggle maximize
await WindowManagerService.toggleMaximize();
```

### 2. System Tray Integration ✅
- **Minimize to Tray**: App can minimize to system tray
- **Tray Menu**: Right-click menu with options:
  - Show Window
  - Minimize to Tray
  - Exit
- **Click to Toggle**: Left-click on tray icon toggles window visibility

**Service:**
```dart
import 'package:offline_pos_system/services/system_tray_service.dart';

// Initialize (called automatically in main.dart)
await SystemTrayService.initialize();
```

### 3. Drag-and-Drop File Upload ✅
- **Visual Feedback**: Shows overlay when files are dragged over
- **File Type Filtering**: Supports filtering by file extensions
- **Multiple Files**: Can handle multiple files dropped at once

**Usage:**
```dart
import 'package:offline_pos_system/widgets/drag_drop_area.dart';

DragDropArea(
  onFilesDropped: (files) {
    // Process dropped files
    for (final file in files) {
      // Handle file
    }
  },
  allowedExtensions: ['xlsx', 'xls'],
  allowedExtensionsMessage: 'Only Excel files are supported',
  child: YourContentWidget(),
)
```

**Example Implementation:**
The Suppliers screen has been updated to support drag-and-drop for Excel file imports. Simply drag an Excel file onto the screen to import suppliers.

### 4. Enhanced Keyboard Shortcuts ✅
All keyboard shortcuts now perform actual actions instead of just showing toast messages:

- **Window Management:**
  - `Alt + Enter`: Toggle maximize/restore window
  - `F11`: Toggle fullscreen
  - `Alt + F4`: Close application (with confirmation)

- **Clipboard Operations:**
  - `Ctrl + C`: Copy (works with text fields automatically)
  - `Ctrl + X`: Cut (works with text fields automatically)
  - `Ctrl + V`: Paste (works with text fields automatically, shows notification if no field focused)

- **Navigation:**
  - `Ctrl + D`: Go to Dashboard
  - `Ctrl + P`: Open POS
  - `Ctrl + I`: Open Products
  - `Ctrl + C`: Open Customers
  - `Ctrl + R`: Open Reports
  - `Ctrl + S`: Open Settings
  - And many more...

**Service:**
```dart
import 'package:offline_pos_system/services/keyboard_shortcuts_service.dart';

// Shortcuts are automatically initialized via KeyboardShortcutWrapper
// which is already included in the MainNavigationWrapper
```

### 5. Enhanced Clipboard Integration ✅
- **Copy to Clipboard**: With visual feedback
- **Paste from Clipboard**: Automatic detection
- **Silent Operations**: Option for copy without notifications

**Usage:**
```dart
import 'package:offline_pos_system/services/clipboard_service.dart';

// Copy with notification
await ClipboardService.copyToClipboard('Text to copy', context);

// Copy silently (no notification)
await ClipboardService.copySilently('Text to copy');

// Get from clipboard
final text = await ClipboardService.getFromClipboard();

// Paste from clipboard
final pastedText = await ClipboardService.pasteFromClipboard();
```

### 6. Multi-Window Support Infrastructure ✅
- **Service Created**: `MultiWindowService` for future multi-window support
- **Placeholder Implementation**: Ready for future expansion

**Service:**
```dart
import 'package:offline_pos_system/services/multi_window_service.dart';

// Initialize
await MultiWindowService.initialize();

// Check if supported
if (MultiWindowService.isSupported()) {
  // Multi-window operations
}
```

## New Packages Added

1. **window_manager** (^0.3.7): Window management for desktop platforms
2. **desktop_drop** (^0.4.0): Drag-and-drop support for desktop

## Files Created

1. `lib/services/window_manager_service.dart` - Window management service
2. `lib/services/system_tray_service.dart` - System tray integration
3. `lib/services/clipboard_service.dart` - Enhanced clipboard operations
4. `lib/services/multi_window_service.dart` - Multi-window infrastructure
5. `lib/widgets/window_controls.dart` - Window control buttons widget
6. `lib/widgets/drag_drop_area.dart` - Drag-and-drop wrapper widget

## Files Modified

1. `lib/main.dart` - Added window manager and system tray initialization
2. `lib/services/keyboard_shortcuts_service.dart` - Updated shortcuts to perform actions
3. `lib/screens/suppliers_screen.dart` - Added drag-and-drop support as example
4. `pubspec.yaml` - Added new dependencies

## Platform Support

All desktop features are automatically enabled on:
- ✅ Windows
- ✅ Linux
- ✅ macOS

Features gracefully degrade on mobile platforms (no errors, just no functionality).

## Usage Examples

### Adding Drag-and-Drop to Any Screen

```dart
import 'package:offline_pos_system/widgets/drag_drop_area.dart';

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: DragDropArea(
      onFilesDropped: (files) async {
        // Process files
        for (final file in files) {
          // Your file processing logic
        }
      },
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      child: YourExistingContent(),
    ),
  );
}
```

### Adding Window Controls to AppBar

```dart
import 'package:offline_pos_system/widgets/window_controls.dart';

AppBar(
  title: Text('My Screen'),
  actions: [
    // Your existing actions
    WindowControls(),
  ],
)
```

### Using Clipboard Service

```dart
import 'package:offline_pos_system/services/clipboard_service.dart';

// In a button or action
ElevatedButton(
  onPressed: () async {
    await ClipboardService.copyToClipboard(
      'Important data',
      context,
    );
  },
  child: Text('Copy'),
)
```

## Notes

- All desktop features are automatically initialized in `main.dart`
- Features only work on desktop platforms (Windows, Linux, macOS)
- Mobile platforms are unaffected (no errors, features simply don't activate)
- System tray requires platform-specific setup (icons, etc.) for full functionality
- Window controls can be customized via the `WindowControls` widget parameters

## Future Enhancements

- Full multi-window support (infrastructure is ready)
- Custom system tray icons
- Window state persistence (remember size/position)
- Advanced drag-and-drop with preview
- More keyboard shortcuts for specific screens

