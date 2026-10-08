# Windows Features Implementation Guide

This document describes the Windows-specific features implemented for the Offline POS System.

## 1. Windows Store Distribution

### MSIX Package Configuration
- **Package.appxmanifest**: Contains app identity, capabilities, and file associations
- **AppInstaller.xml**: Configures auto-update via Microsoft Store or custom update server

### Building MSIX Package
```bash
# Build the app
flutter build windows --release

# Create MSIX package (requires Windows SDK and MSIX Packaging Tool)
# Use Visual Studio or MSIX Packaging Tool to create the package
```

### Certificate for Signing
1. Create a self-signed certificate for testing:
   ```powershell
   New-SelfSignedCertificate -Type Custom -Subject "CN=AirTech Solutions" -KeyUsage DigitalSignature -FriendlyName "POS System Certificate" -CertStoreLocation "Cert:\CurrentUser\My" -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3")
   ```

2. For production, obtain a code signing certificate from a trusted CA.

### Windows Store Listing
- Prepare store assets (screenshots, descriptions, icons)
- Submit through Microsoft Partner Center
- Configure auto-update settings

## 2. Windows-Specific Features

### Toast Notifications
Implemented via `WindowsFeaturesService.showToastNotification()`
- Uses Windows native notification system
- Supports title and message
- Can be upgraded to use Windows Runtime toast notifications

### Share Contract Integration
- Configured in Package.appxmanifest
- Supports sharing files and text with the POS system
- Handles shared content in the app

### File Picker Integration
- Uses `file_picker` package (already included)
- Enhanced with Windows-specific file dialogs
- Supports drag-and-drop via `desktop_drop` package

### Print Queue Integration
- Method available in `WindowsFeaturesService.getPrintQueue()`
- Returns list of printers and their status
- Can be extended to monitor print jobs

### Registry Access
Implemented via `WindowsFeaturesService`:
- `readRegistryValue()`: Read from Windows Registry
- `writeRegistryValue()`: Write to Windows Registry
- Supports HKEY_CURRENT_USER and HKEY_LOCAL_MACHINE

### Windows Service Integration
- Task scheduler integration available via `createScheduledTask()`
- Can create background tasks for data sync, backups, etc.

## 3. Windows Performance

### Native Printer Driver Integration
- Uses Windows printing APIs via `printing` package
- Direct printer communication available

### Task Scheduler Integration
- `WindowsFeaturesService.createScheduledTask()` method available
- Can schedule backups, data sync, reports, etc.

### Event Logging
- `WindowsFeaturesService.writeEventLog()` implemented
- Logs to Windows Event Viewer
- Supports INFO, WARNING, and ERROR levels

### Performance Counters
- Method available in `WindowsFeaturesService.getPerformanceCounters()`
- Can monitor CPU, memory, disk usage

### Memory Optimization
- Flutter Windows handles memory management
- Can be optimized further with native code if needed

## 4. Windows Security

### Windows Defender Exclusion
Users need to manually add exclusions:
1. Open Windows Security
2. Go to Virus & threat protection
3. Add exclusion for app directory

### Firewall Rules
Can be configured via:
- Group Policy
- PowerShell scripts
- Windows Firewall with Advanced Security

### UAC Handling
- App manifest can request elevation if needed
- Current implementation runs as standard user
- Can request elevation via `requestUACElevation()` method

### Security Center Integration
- App follows Windows security best practices
- Uses secure storage for sensitive data
- Implements proper file permissions

## 5. Windows UX

### Windows 11 Design Language (Fluent UI)
- App uses Material Design which adapts to Windows
- Can be enhanced with Fluent UI elements via custom widgets
- Dark mode support via system theme detection

### Context Menu Integration
- File associations configured in Package.appxmanifest
- Right-click context menu can be extended via registry

### Jump List Configuration
- Method available: `WindowsFeaturesService.updateJumpList()`
- Can add recent files, frequent tasks, etc.

### Thumbnail Preview
- Can be implemented via Windows thumbnail provider
- Requires COM component registration

### File Association
- Configured in Package.appxmanifest
- Supports .pos and .posbackup file types
- Double-click opens files in the app

## Implementation Status

✅ Completed:
- Windows platform channel plugin
- Registry access
- Event logging
- File associations (manifest)
- Toast notifications (basic)
- Dart service interface

🔄 Partially Implemented:
- Toast notifications (can be upgraded to Windows Runtime)
- Task scheduler (method available, needs COM implementation)
- Jump list (method available, needs COM implementation)
- Print queue (method available, needs implementation)
- Performance counters (method available, needs implementation)

📋 To Do:
- Complete task scheduler implementation
- Complete jump list implementation
- Complete print queue implementation
- Complete performance counters implementation
- Add thumbnail preview provider
- Enhance context menu
- Add Fluent UI widgets
- Complete MSIX packaging setup
- Windows Store submission

## Usage Examples

### Show Toast Notification
```dart
await WindowsFeaturesService.showToastNotification(
  title: 'New Sale',
  message: 'Sale completed successfully',
);
```

### Read Registry Value
```dart
final value = await WindowsFeaturesService.readRegistryValue(
  key: 'Software\\POSSystem',
  value: 'LastBackup',
);
```

### Write Event Log
```dart
await WindowsFeaturesService.writeEventLog(
  message: 'Application started',
  level: 'INFO',
);
```

### Register File Association
```dart
await WindowsFeaturesService.registerFileAssociation(
  extension: '.pos',
  progId: 'POSFile',
);
```

## Notes

- Some features require administrator privileges
- MSIX packaging requires Windows SDK
- Windows Store distribution requires Microsoft Partner account
- Some features may need additional native code implementation

