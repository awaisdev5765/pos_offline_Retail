import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../widgets/app_snack_bar.dart';
import 'window_manager_service.dart';

class KeyboardShortcutsService {
  static final Map<LogicalKeySet, VoidCallback> _shortcuts = {};
  static final Map<String, String> _shortcutDescriptions = {};
  // Removed _pressedKeys tracking - Flutter handles keyboard state internally
  static bool _isInitialized = false;

  // Define all keyboard shortcuts
  static void initializeShortcuts(BuildContext context) {
    if (_isInitialized) return;

    _shortcuts.clear();
    _shortcutDescriptions.clear();
    _isInitialized = true;

    // Navigation: Ctrl+Alt+letter keeps Ctrl+C / Ctrl+P / Ctrl+S / etc. for text fields and POS.
    void addNav(LogicalKeyboardKey key, String route, String description) {
      _addShortcut(
        keySet: LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.alt,
          key,
        ),
        callback: () => context.go(route),
        description: description,
      );
    }

    addNav(LogicalKeyboardKey.keyD, '/', 'Go to Dashboard');
    addNav(LogicalKeyboardKey.keyP, '/pos', 'Open POS');
    addNav(LogicalKeyboardKey.keyI, '/products', 'Open Products');
    addNav(LogicalKeyboardKey.keyC, '/customers', 'Open Customers');
    addNav(LogicalKeyboardKey.keyR, '/reports', 'Open Reports');
    addNav(LogicalKeyboardKey.keyS, '/settings', 'Open Settings');
    addNav(LogicalKeyboardKey.keyB, '/banking-system', 'Open Banking System');
    addNav(LogicalKeyboardKey.keyU, '/suppliers', 'Open Suppliers');
    addNav(LogicalKeyboardKey.keyE, '/expense-heads', 'Open Expense Heads');
    addNav(LogicalKeyboardKey.keyM, '/inventory-management', 'Open Inventory');

    _addShortcut(
      keySet:
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK),
      callback: () => _showSearchDialog(context),
      description: 'Open Search',
    );

    _addShortcut(
      keySet:
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN),
      callback: () => _showNewItemDialog(context),
      description: 'New Item',
    );

    _addShortcut(
      keySet: LogicalKeySet(LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift, LogicalKeyboardKey.keyE),
      callback: () => _showExportDialog(context),
      description: 'Export Data',
    );

    // Ctrl+Shift+H avoids conflicting with POS Ctrl+H (hold order).
    _addShortcut(
      keySet: LogicalKeySet(LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift, LogicalKeyboardKey.keyH),
      callback: () => _showShortcutsHelp(context),
      description: 'Show Shortcuts Help',
    );

    _addShortcut(
      keySet:
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyW),
      callback: () => _closeCurrentTab(context),
      description: 'Close / go back',
    );

    _addShortcut(
      keySet: LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.f4),
      callback: () => _closeApplication(context),
      description: 'Close Application',
    );

    _addShortcut(
      keySet: LogicalKeySet(LogicalKeyboardKey.f11),
      callback: () => _toggleFullscreen(context),
      description: 'Toggle maximize / restore window',
    );

    _addShortcut(
      keySet: LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.enter),
      callback: () => _toggleMaximize(context),
      description: 'Toggle Maximize',
    );

    _addShortcut(
      keySet: LogicalKeySet(LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift, LogicalKeyboardKey.keyQ),
      callback: () => _logout(context),
      description: 'Logout',
    );

    _addShortcut(
      keySet: LogicalKeySet(LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift, LogicalKeyboardKey.keyF),
      callback: () => _showStaffPerformance(context),
      description: 'Staff Performance',
    );

    _addShortcut(
      keySet: LogicalKeySet(LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift, LogicalKeyboardKey.keyN),
      callback: () => _newSale(context),
      description: 'New Sale (open POS)',
    );

    _addShortcut(
      keySet: LogicalKeySet(LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift, LogicalKeyboardKey.keyP),
      callback: () => _processPayment(context),
      description: 'Open POS (payment)',
    );

    _addShortcut(
      keySet: LogicalKeySet(LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift, LogicalKeyboardKey.keyR),
      callback: () => _returnItem(context),
      description: 'Return Item',
    );

    _addShortcut(
      keySet: LogicalKeySet(LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift, LogicalKeyboardKey.keyD),
      callback: () => _discount(context),
      description: 'Apply Discount',
    );

    _addShortcut(
      keySet: LogicalKeySet(LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift, LogicalKeyboardKey.keyT),
      callback: () => _tax(context),
      description: 'Apply Tax',
    );

    // Number shortcuts for quick product selection - DISABLED to prevent unwanted toast messages
    // Uncomment and implement properly if you want product selection by number keys
    /*
    final digitKeys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    
    for (int i = 0; i < 9; i++) {
      _addShortcut(
        keySet: LogicalKeySet(digitKeys[i]),
        callback: () => _selectProductByNumber(context, i + 1),
        description: 'Select Product ${i + 1}',
      );
    }
    */
  }

  static void _addShortcut({
    required LogicalKeySet keySet,
    required VoidCallback callback,
    required String description,
  }) {
    _shortcuts[keySet] = callback;
    // Create a unique key string from the keySet for tracking descriptions
    final keyString = keySet.keys.map((k) {
      try {
        // Use keyId as a fallback if keyLabel is not available
        return k.debugName ?? k.keyId.toString();
      } catch (e) {
        return k.keyId.toString();
      }
    }).join('+');
    _shortcutDescriptions[keyString] = description;
  }

  /// When a text field has focus, let standard editing keys work; skip app shortcuts.
  static bool _isPrimaryFocusEditableText() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || !primary.hasFocus) return false;
    final ctx = primary.context;
    if (ctx == null) return false;
    final w = ctx.widget;
    return w is EditableText || w is TextField || w is TextFormField;
  }

  static bool handleKeyPress(KeyEvent event) {
    try {
      if (event is KeyDownEvent) {
        if (_isPrimaryFocusEditableText()) {
          return false;
        }
        // Check for exact match first
        final keySet = LogicalKeySet.fromSet({event.logicalKey});
        if (_shortcuts.containsKey(keySet)) {
          _shortcuts[keySet]!();
          return true;
        }

        // Windows Caps Lock Fix: Handle numpad keys with or without modifiers
        // On Windows, when Caps Lock is on, numpad keys can appear with different modifier states
        // We need to check if the logical key is a numpad key regardless of modifiers
        if (_isNumpadKey(event.logicalKey)) {
          // Get the list of known numpad keys
          final numpadKeys = [
            LogicalKeyboardKey.numpad0,
            LogicalKeyboardKey.numpad1,
            LogicalKeyboardKey.numpad2,
            LogicalKeyboardKey.numpad3,
            LogicalKeyboardKey.numpad4,
            LogicalKeyboardKey.numpad5,
            LogicalKeyboardKey.numpad6,
            LogicalKeyboardKey.numpad7,
            LogicalKeyboardKey.numpad8,
            LogicalKeyboardKey.numpad9,
          ];

          // Find which numpad key was pressed by comparing key IDs
          for (final knownNumpadKey in numpadKeys) {
            if (knownNumpadKey.keyId == event.logicalKey.keyId) {
              // Create a keySet for this numpad key
              final numpadKeySet = LogicalKeySet(knownNumpadKey);
              if (_shortcuts.containsKey(numpadKeySet)) {
                _shortcuts[numpadKeySet]!();
                return true;
              }
              break;
            }
          }
        }

        // Check for combination shortcuts
        for (final shortcut in _shortcuts.keys) {
          if (shortcut.keys.length > 1 &&
              shortcut.keys.contains(event.logicalKey)) {
            // This is a combination shortcut, check if all required keys are pressed
            final allKeysPressed = shortcut.keys.every((key) =>
                HardwareKeyboard.instance.logicalKeysPressed.contains(key));

            if (allKeysPressed) {
              _shortcuts[shortcut]!();
              return true;
            }
          }
        }
      }
      // Removed KeyUpEvent handling - Flutter handles keyboard state internally
    } catch (e) {
      debugPrint('Keyboard event error: $e');
      // Removed _pressedKeys.clear() - no longer tracking keys
    }
    return false;
  }

  // Helper method to check if a logical key is a numpad key
  static bool _isNumpadKey(LogicalKeyboardKey key) {
    // Check by comparing key IDs with known numpad keys
    return key.keyId == LogicalKeyboardKey.numpad0.keyId ||
        key.keyId == LogicalKeyboardKey.numpad1.keyId ||
        key.keyId == LogicalKeyboardKey.numpad2.keyId ||
        key.keyId == LogicalKeyboardKey.numpad3.keyId ||
        key.keyId == LogicalKeyboardKey.numpad4.keyId ||
        key.keyId == LogicalKeyboardKey.numpad5.keyId ||
        key.keyId == LogicalKeyboardKey.numpad6.keyId ||
        key.keyId == LogicalKeyboardKey.numpad7.keyId ||
        key.keyId == LogicalKeyboardKey.numpad8.keyId ||
        key.keyId == LogicalKeyboardKey.numpad9.keyId ||
        key.keyId == LogicalKeyboardKey.numpadEnter.keyId ||
        key.keyId == LogicalKeyboardKey.numpadAdd.keyId ||
        key.keyId == LogicalKeyboardKey.numpadSubtract.keyId ||
        key.keyId == LogicalKeyboardKey.numpadMultiply.keyId ||
        key.keyId == LogicalKeyboardKey.numpadDivide.keyId ||
        key.keyId == LogicalKeyboardKey.numpadComma.keyId ||
        key.keyId == LogicalKeyboardKey.numpadDecimal.keyId ||
        key.keyId == LogicalKeyboardKey.numpadParenLeft.keyId ||
        key.keyId == LogicalKeyboardKey.numpadParenRight.keyId;
  }

  static Map<String, String> getShortcutDescriptions() {
    return Map.from(_shortcutDescriptions);
  }

  // Action implementations
  static void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search'),
        content: const TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  static void _showNewItemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('New Product'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/add-product');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('New Customer'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/add-customer');
              },
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('New Supplier'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/add-supplier');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('common.cancel'.tr()),
          ),
        ],
      ),
    );
  }

  static void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Export to Excel'),
              onTap: () {
                Navigator.of(context).pop();
                AppSnackBar.show(
                  context,
                  const SnackBar(
                      content: Text(
                          'Excel export is available in the Reports section')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export to PDF'),
              onTap: () {
                Navigator.of(context).pop();
                AppSnackBar.show(
                  context,
                  const SnackBar(
                      content: Text(
                          'PDF export is available in the Reports section')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: const Text('Export to CSV'),
              onTap: () {
                Navigator.of(context).pop();
                AppSnackBar.show(
                  context,
                  const SnackBar(
                      content: Text(
                          'CSV export is available in the Reports section')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('common.cancel'.tr()),
          ),
        ],
      ),
    );
  }

  static void _showShortcutsHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.keyboard, color: Color(0xFF3B82F6)),
            SizedBox(width: 8),
            Text('Keyboard Shortcuts'),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 500,
          child: DefaultTabController(
            length: 4,
            child: Column(
              children: [
                const TabBar(
                  labelColor: Color(0xFF3B82F6),
                  unselectedLabelColor: Color(0xFF64748B),
                  tabs: [
                    Tab(text: 'Navigation'),
                    Tab(text: 'POS'),
                    Tab(text: 'Windows'),
                    Tab(text: 'Business'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildNavigationShortcuts(),
                      _buildPOSShortcuts(),
                      _buildWindowsShortcuts(),
                      _buildBusinessShortcuts(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  static Widget _buildNavigationShortcuts() {
    final navigationShortcuts = [
      {'shortcut': 'Ctrl + Alt + D', 'description': 'Go to Dashboard'},
      {'shortcut': 'Ctrl + Alt + P', 'description': 'Open POS'},
      {'shortcut': 'Ctrl + Alt + I', 'description': 'Open Products'},
      {'shortcut': 'Ctrl + Alt + C', 'description': 'Open Customers'},
      {'shortcut': 'Ctrl + Alt + R', 'description': 'Open Reports'},
      {'shortcut': 'Ctrl + Alt + S', 'description': 'Open Settings'},
      {'shortcut': 'Ctrl + Alt + B', 'description': 'Open Banking'},
      {'shortcut': 'Ctrl + Alt + U', 'description': 'Open Suppliers'},
      {'shortcut': 'Ctrl + Alt + E', 'description': 'Open Expenses'},
      {'shortcut': 'Ctrl + Alt + M', 'description': 'Open Inventory'},
    ];

    return _buildShortcutsList(navigationShortcuts);
  }

  static Widget _buildPOSShortcuts() {
    final posShortcuts = [
      {
        'shortcut': '—',
        'description':
            'POS shortcuts are handled on the POS screen (see POS help dialog there).',
      },
      {'shortcut': 'Ctrl + H', 'description': 'Hold order'},
      {'shortcut': 'Ctrl + R', 'description': 'Resume held order'},
      {'shortcut': 'Ctrl + C', 'description': 'Clear cart (when not in a text field)'},
      {'shortcut': 'Ctrl + S', 'description': 'Open Sales'},
      {'shortcut': 'Ctrl + P', 'description': 'Process payment'},
      {'shortcut': 'Ctrl + F', 'description': 'Focus product search / sales'},
      {'shortcut': 'F7', 'description': 'New bill'},
      {'shortcut': 'F8', 'description': 'Print'},
      {'shortcut': 'F9', 'description': 'Find sale (print)'},
      {'shortcut': 'F10', 'description': 'Focus cash amount'},
      {'shortcut': 'F10 + Enter', 'description': 'Focus cash received'},
      {'shortcut': 'F11 + Enter', 'description': 'Pay'},
    ];

    return _buildShortcutsList(posShortcuts);
  }

  static Widget _buildWindowsShortcuts() {
    final windowsShortcuts = [
      {'shortcut': 'Ctrl + W', 'description': 'Close / go back (pop route)'},
      {'shortcut': 'Alt + F4', 'description': 'Close application (desktop)'},
      {'shortcut': 'F11', 'description': 'Toggle maximize / restore window'},
      {'shortcut': 'Alt + Enter', 'description': 'Toggle maximize'},
    ];

    return _buildShortcutsList(windowsShortcuts);
  }

  static Widget _buildBusinessShortcuts() {
    final businessShortcuts = [
      {'shortcut': 'Ctrl + Shift + N', 'description': 'New sale (open POS)'},
      {'shortcut': 'Ctrl + Shift + P', 'description': 'Open POS'},
      {'shortcut': 'Ctrl + Shift + R', 'description': 'Return item (placeholder)'},
      {'shortcut': 'Ctrl + Shift + D', 'description': 'Apply discount (placeholder)'},
      {'shortcut': 'Ctrl + Shift + T', 'description': 'Apply tax (placeholder)'},
      {'shortcut': 'Ctrl + Shift + E', 'description': 'Export data'},
      {'shortcut': 'Ctrl + Shift + F', 'description': 'Staff performance'},
      {'shortcut': 'Ctrl + Shift + Q', 'description': 'Logout (use sidebar)'},
      {'shortcut': 'Ctrl + Shift + H', 'description': 'This shortcuts help'},
      {'shortcut': 'Ctrl + N', 'description': 'New item (product / customer / supplier)'},
      {'shortcut': 'Ctrl + K', 'description': 'Open search dialog'},
    ];

    return _buildShortcutsList(businessShortcuts);
  }

  static Widget _buildShortcutsList(List<Map<String, String>> shortcuts) {
    return ListView.builder(
      itemCount: shortcuts.length,
      itemBuilder: (context, index) {
        final shortcut = shortcuts[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  shortcut['description']!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  shortcut['shortcut']!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static void _closeCurrentTab(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      AppSnackBar.show(
        context,
        const SnackBar(content: Text('No tab to close')),
      );
    }
  }

  static void _closeApplication(BuildContext context) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Close Application'),
          content: const Text('Are you sure you want to close the application?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                WindowManagerService.close();
              },
              child: Text('common.close'.tr()),
            ),
          ],
        ),
      );
    } else {
      // On mobile, use system navigator
      SystemNavigator.pop();
    }
  }

  static void _toggleFullscreen(BuildContext context) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      WindowManagerService.isMaximized().then((isMax) {
        if (isMax) {
          WindowManagerService.restore();
        } else {
          WindowManagerService.maximize();
        }
      });
    }
  }

  static void _toggleMaximize(BuildContext context) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      WindowManagerService.toggleMaximize();
    }
  }

  static void _newSale(BuildContext context) {
    context.go('/pos');
  }

  static void _processPayment(BuildContext context) {
    context.go('/pos');
  }

  static void _returnItem(BuildContext context) {
    AppSnackBar.show(
      context,
      const SnackBar(content: Text('Return Item')),
    );
  }

  static void _discount(BuildContext context) {
    AppSnackBar.show(
      context,
      const SnackBar(content: Text('Apply Discount')),
    );
  }

  static void _tax(BuildContext context) {
    AppSnackBar.show(
      context,
      const SnackBar(content: Text('Apply Tax')),
    );
  }

  static void _logout(BuildContext context) {
    // This would need to be implemented with proper auth provider access
    AppSnackBar.show(
      context,
      const SnackBar(
          content: Text('Logout - Use the logout button in the sidebar')),
    );
  }

  static void _showStaffPerformance(BuildContext context) {
    // Navigate to staff performance screen
    context.go('/staff-performance');
  }
}

// Keyboard shortcut widget wrapper
class KeyboardShortcutWrapper extends StatefulWidget {
  final Widget child;
  final bool enableShortcuts;

  const KeyboardShortcutWrapper({
    super.key,
    required this.child,
    this.enableShortcuts = true,
  });

  @override
  State<KeyboardShortcutWrapper> createState() =>
      _KeyboardShortcutWrapperState();
}

class _KeyboardShortcutWrapperState extends State<KeyboardShortcutWrapper> {
  late FocusNode _focusNode;
  bool _isHandlingKey = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      KeyboardShortcutsService.initializeShortcuts(context);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (widget.enableShortcuts && !_isHandlingKey) {
          _isHandlingKey = true;
          try {
            final handled = KeyboardShortcutsService.handleKeyPress(event);
            if (handled) {
              return KeyEventResult.handled;
            }
          } finally {
            // Use a microtask to reset the flag after the current event
            Future.microtask(() {
              if (mounted) {
                _isHandlingKey = false;
              }
            });
          }
        }
        return KeyEventResult.ignored;
      },
      child: widget.child,
    );
  }
}
