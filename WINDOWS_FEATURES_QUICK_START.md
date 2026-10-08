# Windows Features Quick Start Guide

This is a quick reference for using Windows-specific features in the Offline POS System.

## 🚀 Quick Setup

### 1. Import the Service
```dart
import 'package:offline_pos_system/services/windows_features_service.dart';
```

### 2. Check if Running on Windows
```dart
if (WindowsFeaturesService.isWindows) {
  // Use Windows-specific features
}
```

## 📋 Common Use Cases

### Show Toast Notification
```dart
await WindowsFeaturesService.showToastNotification(
  title: 'Sale Complete',
  message: 'Transaction saved successfully',
);
```

### Store Settings in Registry
```dart
// Write setting
await WindowsFeaturesService.writeRegistryValue(
  key: 'Software\\POSSystem',
  value: 'LastBackup',
  data: DateTime.now().toIso8601String(),
);

// Read setting
final lastBackup = await WindowsFeaturesService.readRegistryValue(
  key: 'Software\\POSSystem',
  value: 'LastBackup',
);
```

### Log Events to Windows Event Viewer
```dart
await WindowsFeaturesService.writeEventLog(
  message: 'Application started successfully',
  level: 'INFO', // or 'WARNING', 'ERROR'
);
```

### Get System Performance Info
```dart
final perf = await WindowsFeaturesService.getPerformanceCounters();
print('Memory: ${perf['memoryPercent']}% used');
print('Disk Free: ${(perf['diskFree']! / 1024 / 1024 / 1024).toStringAsFixed(2)} GB');
```

### Get Print Queue
```dart
final printers = await WindowsFeaturesService.getPrintQueue();
for (final printer in printers) {
  print('${printer['name']}: ${printer['jobs']} jobs');
}
```

### Register File Association
```dart
await WindowsFeaturesService.registerFileAssociation(
  extension: '.pos',
  progId: 'POSFile',
);
```

## 🎨 Using Fluent UI Widgets

### Import
```dart
import 'package:offline_pos_system/widgets/windows_fluent_button.dart';
```

### Fluent Button
```dart
WindowsFluentButton(
  text: 'Save',
  icon: Icons.save,
  onPressed: () {
    // Handle save
  },
)
```

### Fluent Card
```dart
WindowsFluentCard(
  padding: EdgeInsets.all(16),
  child: Text('Card content'),
)
```

## 🔧 Configuration Scripts

### Configure Windows Security
Run as Administrator:
```powershell
.\windows\configure_windows_security.ps1 -AddFirewallRule -AddDefenderExclusion -ConfigureUAC
```

### Build MSIX Package
```powershell
.\windows\build_msix.ps1
```

## 📝 Notes

- All Windows features automatically check if running on Windows
- Features return gracefully on non-Windows platforms
- Some features require administrator privileges
- See `WINDOWS_FEATURES_IMPLEMENTATION.md` for detailed documentation

## 🔗 Related Files

- `lib/services/windows_features_service.dart` - Main service
- `lib/widgets/windows_fluent_button.dart` - Fluent UI widgets
- `windows/README_WINDOWS_FEATURES.md` - Detailed documentation
- `WINDOWS_FEATURES_IMPLEMENTATION.md` - Implementation summary

