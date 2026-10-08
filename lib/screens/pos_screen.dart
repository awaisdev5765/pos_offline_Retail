import 'dart:async';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vibration/vibration.dart';
import '../models/currency.dart';
import '../providers/product_provider.dart';
import '../providers/bundle_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/category_provider.dart';
import '../models/product.dart';
import '../models/product_bundle.dart';
import '../models/product_ingredient.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../models/employee.dart';
import '../models/category.dart';
import '../services/pdf_service.dart';
import '../services/enhanced_thermal_print_service_v2.dart';
import '../services/unified_print_service.dart';
import '../services/windows_pdf_print_service.dart';
import '../services/print_settings_service.dart';
import '../services/bluetooth_printer_service.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'receipt_settings_screen.dart';
import '../services/database_service.dart';
import '../providers/audio_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/held_orders_provider.dart';
import '../providers/tax_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/discount_provider.dart';
import 'barcode_scanner_screen.dart';
import '../widgets/enhanced_product_card.dart';
import '../theme/app_theme.dart';
import '../utils/input_formatters.dart';
import '../utils/mobile_optimization.dart';
import '../utils/pos_helpers.dart';
import '../utils/haptic_feedback_util.dart';
import '../utils/money_math.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/pos/product_card_widget.dart';
import '../widgets/pos/category_filter_widget.dart';
import '../widgets/pos/cart_summary_widget.dart';
import '../widgets/pos/customer_info_widget.dart';
import '../widgets/pos/payment_button_widget.dart';
import '../controllers/pos_controller.dart';
import '../database/database.dart';

enum HapticFeedbackType { success, error, light, medium, heavy }

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerSearchController =
      TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _discountFocusNode = FocusNode();
  final FocusNode _cashAmountFocusNode = FocusNode();
  final FocusNode _cardAmountFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode =
      FocusNode(); // Persistent focus node for keyboard handling
  CustomerModel? _selectedCustomer;
  DateTime _selectedSaleDate = DateTime.now();
  String _orderType = 'dine_in'; // dine_in, takeout, delivery
  String _paymentType = 'cash';
  double _discount = 0;
  // Restaurant specific fields
  int? _tableNumber;
  double _serviceCharge = 0;
  double _tip = 0;
  int? _numberOfGuests;
  String _discountType = 'percentage'; // percentage or fixed
  double _cashAmount = 0;
  double _cardAmount = 0;
  double _creditAmount = 0;
  bool _isSplitPayment = false;
  String _remarks = ''; // Remarks/notes for the sale
  int _paymentFieldVersion = 0; // Force rebuild of payment inputs when reset
  DateTime? _dueDate; // Due date for credit sales
  String _selectedCategory = 'all';
  bool _showBundles = false;
  bool _isWholesaleMode = false; // Wholesale mode toggle
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final Map<String, double> _itemDiscounts =
      {}; // Track individual item discounts
  final Map<String, double> _itemPrices = {}; // Track individual item prices
  final Map<String, double> _itemAmounts = {}; // Track manual item amounts
  final Set<PhysicalKeyboardKey> _pressedKeys =
      <PhysicalKeyboardKey>{}; // Track pressed keys
  final Map<String, TextEditingController> _cartQuantityControllers = {};
  final Map<String, FocusNode> _cartQuantityFocusNodes = {};
  final Map<String, TextEditingController> _cartPriceControllers = {};
  final Map<String, FocusNode> _cartPriceFocusNodes = {};
  bool _isCreditSectionExpanded =
      false; // Track credit section expand/collapse state
  // Controllers for Amount (cost) field
  final Map<String, TextEditingController> _cartAmountControllers = {};
  final Map<String, FocusNode> _cartAmountFocusNodes = {};
  Timer? _categoryLoadingTimer;
  bool _isCategoryLoading = false;
  bool _isReceiptPrinting = false;
  bool _payLocked =
      false; // Disable Pay after successful payment until cart changes
  bool _isProcessingPayment =
      false; // Re-entrancy guard: blocks a second _processPayment call while one is in-flight
  bool _isSaleComplete =
      false; // Prevent adding items after payment until new bill is started
  /// After payment, cart is not auto-cleared; print must use the persisted sale (real id), not a temp id 0.
  SaleModel? _lastCompletedSaleForReceipt;
  // Global barcode scanner detection for desktop
  String _globalBarcodeBuffer = ''; // Buffer for global barcode input
  DateTime? _lastBarcodeKeyTime; // Last key press time for barcode detection
  Timer? _globalBarcodeTimer; // Timer for global barcode detection
  bool _isBarcodeScanning = false; // Flag to prevent duplicate processing
  bool _isMobileCustomerSectionExpanded =
      true; // Mobile-only: collapse/expand customer block in cart

  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    // Add focus listeners to prevent keyboard issues
    _discountFocusNode.addListener(_onDiscountFocusChange);
    _cashAmountFocusNode.addListener(_onCashAmountFocusChange);
    _cardAmountFocusNode.addListener(_onCardAmountFocusChange);

    // Initialize order type based on business nature
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeOrderType();
    });

    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  /// Handset & narrow layouts: bottom sheet. Wide web / Windows: material [Dialog].
  static const double _paymentDialogMinWidth = 720;

  bool _useCompactPaymentPresentation(BuildContext context) {
    if (_isMobileHandset) return true;
    return MediaQuery.sizeOf(context).width < _paymentDialogMinWidth;
  }

  Future<void> _onProductSearchSubmitted(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      _searchFocusNode.unfocus();
      return;
    }
    try {
      final databaseService = ref.read(databaseServiceProvider);
      final match = await databaseService.getProductByBarcode(trimmed);
      if (!mounted) return;
      if (match != null) {
        await _handleBarcodeInput(trimmed);
        _searchController.clear();
      }
    } catch (e) {
      debugPrint('Product search submit / barcode lookup: $e');
    }
    if (mounted) _searchFocusNode.unfocus();
  }

  // Helper: true only on physical mobile devices (Android/iOS), not web/desktop
  bool get _isMobileHandset {
    return !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  }

  double _clampPaymentToTotal(double amount, double total) {
    if (amount.isNaN || amount.isInfinite) {
      return total >= 0 ? 0.0 : total;
    }
    final lowerLimit = total >= 0 ? 0.0 : total;
    final upperLimit = total >= 0 ? total : 0.0;
    return amount.clamp(lowerLimit, upperLimit);
  }

  // Check if a key is a numpad key (works regardless of Num Lock state)
  bool _isNumpadKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.numpad0 ||
        key == LogicalKeyboardKey.numpad1 ||
        key == LogicalKeyboardKey.numpad2 ||
        key == LogicalKeyboardKey.numpad3 ||
        key == LogicalKeyboardKey.numpad4 ||
        key == LogicalKeyboardKey.numpad5 ||
        key == LogicalKeyboardKey.numpad6 ||
        key == LogicalKeyboardKey.numpad7 ||
        key == LogicalKeyboardKey.numpad8 ||
        key == LogicalKeyboardKey.numpad9 ||
        key == LogicalKeyboardKey.numpadDecimal ||
        key == LogicalKeyboardKey.numpadAdd ||
        key == LogicalKeyboardKey.numpadSubtract ||
        key == LogicalKeyboardKey.numpadMultiply ||
        key == LogicalKeyboardKey.numpadDivide ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.numpadEqual ||
        key == LogicalKeyboardKey.numpadComma;
  }

  // Check if any text input field has focus
  bool _hasAnyTextFieldFocus() {
    if (_searchFocusNode.hasFocus ||
        _discountFocusNode.hasFocus ||
        _cashAmountFocusNode.hasFocus ||
        _cardAmountFocusNode.hasFocus) {
      return true;
    }

    // Check all cart quantity, price, and amount focus nodes
    for (final focusNode in _cartQuantityFocusNodes.values) {
      if (focusNode.hasFocus) return true;
    }
    for (final focusNode in _cartPriceFocusNodes.values) {
      if (focusNode.hasFocus) return true;
    }
    for (final focusNode in _cartAmountFocusNodes.values) {
      if (focusNode.hasFocus) return true;
    }

    // Focus nodes inside EditableText are normally attached to an internal
    // Focus widget, not directly to TextField. Inspecting only the focused
    // widget can therefore miss active inputs and accidentally execute a POS
    // shortcut (including Clear Cart) while the cashier is typing.
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext != null &&
        (focusContext.widget is EditableText ||
            focusContext.findAncestorWidgetOfExactType<EditableText>() !=
                null)) {
      return true;
    }

    return false;
  }

  // Keyboard shortcuts for desktop
  KeyEventResult _handleKeyPress(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Handle function keys (F7, F8, F9) FIRST on Windows - these should work regardless of focus state
      // On Windows, function keys need to be handled before ANY other checks to ensure they always work
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        switch (event.logicalKey) {
          case LogicalKeyboardKey.f7:
            // Do not allow a destructive New Bill action while editing any
            // input. This also protects platform-remapped function keys.
            if (_hasAnyTextFieldFocus()) return KeyEventResult.ignored;
            // F7: New Bill - handle even if key was already tracked
            if (_pressedKeys.contains(event.physicalKey)) {
              // Key already tracked, but still handle it for function keys
              _pressedKeys.remove(event.physicalKey);
            }
            _pressedKeys.add(event.physicalKey);
            _clearCart();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.f8:
            // F8: Print - always handle, even if key was already tracked
            if (_pressedKeys.contains(event.physicalKey)) {
              // Key already tracked, but still handle it for function keys
              _pressedKeys.remove(event.physicalKey);
            }
            _pressedKeys.add(event.physicalKey);
            final cart = ref.read(cartProvider);
            if (cart.isNotEmpty) {
              _printAndRemove();
            } else {
              AppSnackBar.show(
                context,
                SnackBar(
                  content: Text('pos.cart_empty_print'.tr()),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
            }
            return KeyEventResult.handled;
          case LogicalKeyboardKey.f9:
            // F9: Print - Show find sale dialog for printing - always handle
            if (_pressedKeys.contains(event.physicalKey)) {
              // Key already tracked, but still handle it for function keys
              _pressedKeys.remove(event.physicalKey);
            }
            _pressedKeys.add(event.physicalKey);
            _showFindSaleDialog();
            return KeyEventResult.handled;
          default:
            break;
        }
      }

      // Prevent duplicate key events - check if key is already being tracked
      // This helps prevent conflicts with Flutter's internal keyboard state
      // Skip this check for function keys as we handle them above
      if (_pressedKeys.contains(event.physicalKey)) {
        // Key already tracked, ignore duplicate event
        return KeyEventResult.ignored;
      }

      // Track the pressed key
      _pressedKeys.add(event.physicalKey);

      // On Windows, allow numpad keys to pass through to text fields
      // This works regardless of Num Lock state
      if (Platform.isWindows || Platform.isLinux) {
        final isNumpadKey = _isNumpadKey(event.logicalKey);
        final hasTextFocus = _hasAnyTextFieldFocus();

        // If numpad key and any text field has focus, allow it to pass through to TextField
        if (isNumpadKey && hasTextFocus) {
          // Don't handle numpad keys here - let them pass through to text fields
          return KeyEventResult.ignored;
        }
      }

      // Check for modifier keys
      final pressedKeys = HardwareKeyboard.instance.logicalKeysPressed;
      final isCtrlPressed =
          pressedKeys.contains(LogicalKeyboardKey.controlLeft) ||
              pressedKeys.contains(LogicalKeyboardKey.controlRight) ||
              pressedKeys.contains(LogicalKeyboardKey.metaLeft) ||
              pressedKeys.contains(LogicalKeyboardKey.metaRight);
      final isShiftPressed =
          pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ||
              pressedKeys.contains(LogicalKeyboardKey.shiftRight);

      // If a text field has focus and Ctrl is pressed, let standard shortcuts pass through
      // (Ctrl+C, Ctrl+V, Ctrl+X, Ctrl+Z, Ctrl+A work automatically in TextFields)
      if (_hasAnyTextFieldFocus() && isCtrlPressed) {
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.keyC || // Copy
            key == LogicalKeyboardKey.keyV || // Paste
            key == LogicalKeyboardKey.keyX || // Cut
            key == LogicalKeyboardKey.keyZ || // Undo
            key == LogicalKeyboardKey.keyA) {
          // Select All
          return KeyEventResult.ignored; // Let TextField handle these
        }
      }

      // Handle keyboard shortcuts
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyH:
          if (isCtrlPressed) {
            _holdCurrentOrder();
            return KeyEventResult.handled;
          }
          break;
        case LogicalKeyboardKey.keyR:
          if (isCtrlPressed) {
            _showHeldOrders();
            return KeyEventResult.handled;
          }
          break;
        case LogicalKeyboardKey.keyC:
          if (isCtrlPressed) {
            // If a text field has focus, let Ctrl+C work as copy
            if (_hasAnyTextFieldFocus()) {
              return KeyEventResult.ignored;
            }
            // Otherwise, clear cart
            _clearCart();
            return KeyEventResult.handled;
          }
          break;
        case LogicalKeyboardKey.keyS:
          if (isCtrlPressed) {
            context.push('/sales');
            return KeyEventResult.handled;
          }
          break;
        case LogicalKeyboardKey.keyP:
          if (isCtrlPressed) {
            _processPayment();
            return KeyEventResult.handled;
          }
          break;
        case LogicalKeyboardKey.keyF:
          if (isCtrlPressed) {
            context.push('/sales');
            return KeyEventResult.handled;
          }
          _focusProductSearchField(selectAll: !isShiftPressed);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.f3:
          // F3: Focus on first amount field in cart
          if (Platform.isWindows || Platform.isMacOS) {
            final cart = ref.read(cartProvider);
            if (cart.isEmpty) {
              AppSnackBar.show(
                context,
                SnackBar(
                  content: Text('pos.cart_empty_add'.tr()),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
              return KeyEventResult.handled;
            }

            // Find first item with amount field (non-piece unit)
            CartItem? targetItem;
            for (final item in cart) {
              final product = item.product;
              if (product != null) {
                final unit = product.unit;
                if (unit != null) {
                  final unitLower = unit.toLowerCase();
                  final isPieceUnit = unitLower == 'pcs' || unitLower == 'pc';
                  if (!isPieceUnit) {
                    targetItem = item;
                    break;
                  }
                }
              }
            }

            if (targetItem != null) {
              final amountFocus = _getCartAmountFocusNode(targetItem);
              FocusScope.of(context).requestFocus(amountFocus);
            } else {
              AppSnackBar.show(
                context,
                SnackBar(
                  content: Text('pos.cart_empty_amount'.tr()),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
            }
            return KeyEventResult.handled;
          }
          break;
        case LogicalKeyboardKey.f4:
          // F4: Focus on first quantity field in cart
          if (Platform.isWindows || Platform.isMacOS) {
            final cart = ref.read(cartProvider);
            if (cart.isEmpty) {
              AppSnackBar.show(
                context,
                SnackBar(
                  content: Text('pos.cart_empty_add'.tr()),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
              return KeyEventResult.handled;
            }

            // Focus on first cart item's quantity field
            final firstItem = cart.first;
            final quantityFocus = _getCartQuantityFocusNode(firstItem);
            FocusScope.of(context).requestFocus(quantityFocus);
            return KeyEventResult.handled;
          }
          break;
        case LogicalKeyboardKey.f10:
          // F10: Focus receiving amount (cash) input
          if (Platform.isWindows || Platform.isMacOS) {
            FocusScope.of(context).requestFocus(_cashAmountFocusNode);
            return KeyEventResult.handled;
          }
          break;
        case LogicalKeyboardKey.f11:
          // F11: Reserved for F11+Enter (Pay button)
          // F11 alone does nothing, F11+Enter triggers payment
          if (Platform.isWindows || Platform.isMacOS) {
            // Do nothing when F11 is pressed alone
            return KeyEventResult.handled;
          }
          break;
        case LogicalKeyboardKey.numLock:
          // Num Lock: Focus product search field
          if (!_hasAnyTextFieldFocus()) {
            _focusProductSearchField(selectAll: true);
            return KeyEventResult.handled;
          }
          break;
        case LogicalKeyboardKey.numpadEnter:
          // Numpad Enter: Only handle if no text field has focus
          if (!_hasAnyTextFieldFocus()) {
            _focusProductSearchField(selectAll: true);
            return KeyEventResult.handled;
          }
          // Otherwise, let it pass through to text fields
          return KeyEventResult.ignored;
        case LogicalKeyboardKey.escape:
          // Escape: Unfocus all fields
          _unfocusAllFields();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.enter:
          // Enter: Handle based on context
          // Check for F10+Enter (focus cash received field) or F11+Enter (pay button)
          final pressedKeys = HardwareKeyboard.instance.logicalKeysPressed;
          final isF10Pressed = pressedKeys.contains(LogicalKeyboardKey.f10);
          final isF11Pressed = pressedKeys.contains(LogicalKeyboardKey.f11);

          if (isF10Pressed && (Platform.isWindows || Platform.isMacOS)) {
            // F10+Enter: Focus cash received field
            FocusScope.of(context).requestFocus(_cashAmountFocusNode);
            return KeyEventResult.handled;
          }

          if (isF11Pressed && (Platform.isWindows || Platform.isMacOS)) {
            // F11+Enter: Pay button
            final cart = ref.read(cartProvider);
            if (cart.isNotEmpty) {
              _processPayment();
            } else {
              AppSnackBar.show(
                context,
                SnackBar(
                  content: Text('pos.cart_empty_add'.tr()),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
            }
            return KeyEventResult.handled;
          }

          if (_hasAnyTextFieldFocus()) {
            // If a text field has focus, let Enter work normally (submit, next field, etc.)
            return KeyEventResult.ignored;
          }
          if (_searchFocusNode.hasFocus) {
            // Trigger search
            setState(() {});
            return KeyEventResult.handled;
          }
          break;
        case LogicalKeyboardKey.space:
          // Space: Only handle if no text field has focus
          if (!_hasAnyTextFieldFocus()) {
            // Quick add to cart (if a product is selected)
            return KeyEventResult.ignored;
          }
          // Otherwise, let space work normally in text fields
          return KeyEventResult.ignored;
        case LogicalKeyboardKey.backspace:
        case LogicalKeyboardKey.delete:
          // Standard editing keys: Always let them pass through to text fields
          if (_hasAnyTextFieldFocus()) {
            return KeyEventResult.ignored;
          }
          break;
        case LogicalKeyboardKey.tab:
          // Tab: Navigate between cart item fields (quantity → price → amount → next item)
          if (Platform.isWindows || Platform.isMacOS) {
            if (_hasAnyTextFieldFocus()) {
              // Check if we're in a cart item field
              final focusedChild = FocusScope.of(context).focusedChild;
              if (focusedChild != null) {
                // Try to find next field in current cart item or next item
                final handled = _handleTabNavigation(isShiftPressed);
                if (handled) {
                  return KeyEventResult.handled;
                }
              }
            }
            // Let Tab work normally if not in cart fields
            return KeyEventResult.ignored;
          }
          break;
        case LogicalKeyboardKey.numpadAdd:
          // Numpad +: Increase quantity of focused cart item
          if (Platform.isWindows && _hasAnyTextFieldFocus()) {
            final handled = _handleNumpadQuantityAdjustment(1);
            if (handled) {
              return KeyEventResult.handled;
            }
          }
          break;
        case LogicalKeyboardKey.numpadSubtract:
          // Numpad -: Decrease quantity of focused cart item
          if (Platform.isWindows && _hasAnyTextFieldFocus()) {
            final handled = _handleNumpadQuantityAdjustment(-1);
            if (handled) {
              return KeyEventResult.handled;
            }
          }
          break;
        // Handle standard alphanumeric keys - let them pass through to text fields
        default:
          // For any other key, if a text field has focus, let it pass through
          if (_hasAnyTextFieldFocus()) {
            // Check if it's a printable character or standard key
            final isPrintable = event.logicalKey.keyLabel.length == 1 ||
                event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.tab ||
                event.logicalKey == LogicalKeyboardKey.backspace ||
                event.logicalKey == LogicalKeyboardKey.delete ||
                event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                event.logicalKey == LogicalKeyboardKey.arrowRight ||
                event.logicalKey == LogicalKeyboardKey.arrowUp ||
                event.logicalKey == LogicalKeyboardKey.arrowDown ||
                event.logicalKey == LogicalKeyboardKey.home ||
                event.logicalKey == LogicalKeyboardKey.end ||
                event.logicalKey == LogicalKeyboardKey.pageUp ||
                event.logicalKey == LogicalKeyboardKey.pageDown;

            if (isPrintable || _isNumpadKey(event.logicalKey)) {
              return KeyEventResult.ignored;
            }
          }
          break;
      }
    } else if (event is KeyUpEvent) {
      // Remove key from pressed set when released
      // Always remove to keep state in sync, even if not in set
      _pressedKeys.remove(event.physicalKey);
    }
    return KeyEventResult.ignored;
  }

  void _showKeyboardShortcutsHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.keyboard, color: Color(0xFF3B82F6)),
            const SizedBox(width: 8),
            Text('pos.keyboard_shortcuts'.tr()),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'These shortcuts are optimized for Windows and other desktop platforms. '
                  'They do not affect Android or iOS devices.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              _buildShortcutRow('Ctrl + H', 'Hold Order'),
              _buildShortcutRow('Ctrl + R', 'Resume Order'),
              _buildShortcutRow('Ctrl + C', 'Clear Cart'),
              _buildShortcutRow('Ctrl + S', 'View Sales'),
              _buildShortcutRow('Ctrl + P', 'Process Payment'),
              _buildShortcutRow('Ctrl + F', 'Show All Sales'),
              _buildShortcutRow('F3', 'Focus Amount Field'),
              _buildShortcutRow('F4', 'Focus Quantity Field'),
              _buildShortcutRow('F7', 'New Bill'),
              _buildShortcutRow('F8', 'Print'),
              _buildShortcutRow('F9', 'Find Sale (Print)'),
              _buildShortcutRow('F10', 'Focus Cash Amount'),
              _buildShortcutRow('F10 + Enter', 'pos.shortcut_focus_cash'.tr()),
              _buildShortcutRow('F11 + Enter', 'Pay Button'),
              _buildShortcutRow('Escape', 'Unfocus Fields'),
              _buildShortcutRow('Enter', 'Search Products'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutRow(String shortcut, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              shortcut,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B82F6),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(description, style: const TextStyle(fontSize: 14)),
          ),
          CustomerInfoWidget(
            customer: _selectedCustomer,
            isCompact: true,
            onExpandToggle: () {
              setState(() {
                _isCreditSectionExpanded = !_isCreditSectionExpanded;
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _customerSearchController.dispose();
    _remarksController.dispose();
    _searchFocusNode.dispose();
    _discountFocusNode.dispose();
    _cashAmountFocusNode.dispose();
    _cardAmountFocusNode.dispose();
    _keyboardFocusNode.dispose();
    _animationController.dispose();
    _categoryLoadingTimer?.cancel();
    _disposeCartTextControllers();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Handle app lifecycle changes to prevent keyboard issues
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pressedKeys.clear();
      _unfocusAllFields();
    }
    // Refresh products when app resumes (in case new products were added)
    if (state == AppLifecycleState.resumed) {
      _pressedKeys.clear();
      // Delay to ensure widget is mounted
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          ref.invalidate(productNotifierProvider);
        }
      });
    }
  }

  void _onDiscountFocusChange() {
    // Handle discount focus changes
  }

  void _onCashAmountFocusChange() {
    // Handle cash amount focus changes
  }

  void _onCardAmountFocusChange() {
    // Handle card amount focus changes
  }

  void _initializeOrderType() {
    setState(() {
      _orderType = 'dine_in';
    });
  }

  // Build restaurant-specific fields UI - Not used in retail mode
  Widget _buildRestaurantFields(bool compactSummary) {
    return const SizedBox.shrink();
  }

  // Placeholder comment to mark removed restaurant UI section
  Widget _buildRestaurantFieldsPlaceholder() {
    // Original restaurant fields removed - retail only
    return const SizedBox.shrink();
  }

  Widget _buildOrderTypeButton(
    String type,
    IconData icon,
    String label,
    bool compactSummary,
  ) {
    final isSelected = _orderType == type;
    final isDarkMode = ref.watch(isDarkModeProvider);
    final bgColor = isSelected
        ? Colors.orange.shade600
        : (isDarkMode ? AppColors.surfaceDark : Colors.white);
    return GestureDetector(
      onTap: () {
        setState(() {
          _orderType = type;
          // Clear table number if not dine-in
          if (type != 'dine_in') {
            _tableNumber = null;
            _numberOfGuests = null;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          vertical: compactSummary ? 6 : 8,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? Colors.orange.shade600 : Colors.orange.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.orange.shade700,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.orange.shade700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _triggerCategoryLoading() {
    _categoryLoadingTimer?.cancel();
    setState(() {
      _isCategoryLoading = true;
    });
    _categoryLoadingTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _isCategoryLoading = false;
      });
    });
  }

  String _formatCurrency(double amount) {
    final currency = ref.read(currentCurrencyProvider);
    return '${currency.symbol.trim()} ${amount.toStringAsFixed(2)}';
  }

  String _formatEmployeeName(EmployeeModel? employee, int? fallbackId) {
    if (employee != null) {
      final trimmed = employee.name.trim();
      // Check if name is valid (not empty, not "unknown", not just whitespace)
      if (trimmed.isNotEmpty &&
          trimmed.toLowerCase() != 'unknown' &&
          trimmed.toLowerCase() != 'unknown user') {
        return trimmed;
      }
    }
    // If we have a cashierId but no employee, try to show a better message
    if (fallbackId != null) {
      // Try to get employee name from current user if it matches
      final currentUser = ref.read(authProvider).currentUser;
      if (currentUser?.id == fallbackId) {
        final name = currentUser?.name.trim();
        if (name != null && name.isNotEmpty) {
          return name;
        }
      }
      return 'Employee #$fallbackId';
    }
    return 'Unknown User';
  }

  String _formatEmployeeRoleLabel(EmployeeRole? role) {
    if (role == null) return '';
    final normalized = role.name.replaceAll('_', ' ');
    final words = normalized.split(' ');
    return words
        .map(
          (word) => word.isEmpty
              ? ''
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ')
        .trim();
  }

  void _unfocusAllFields() {
    _searchFocusNode.unfocus();
    _discountFocusNode.unfocus();
    _cashAmountFocusNode.unfocus();
    _cardAmountFocusNode.unfocus();
  }

  void _applyCustomerSelection(CustomerModel? customer) {
    var updatedCustomer = customer;
    if (customer != null) {
      final allowed = _isWholesaleMode
          ? customer.isWholesaleCustomer
          : customer.isRetailCustomer;
      if (!allowed) {
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text(
                _isWholesaleMode
                    ? 'Selected customer is not marked as wholesale.'
                    : 'Selected customer is not marked as retail.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        updatedCustomer = null;
      }
    }

    _selectedCustomer = updatedCustomer;
    // Don't clear remarks when customer is deselected (walking customer can have remarks)
    // Reset credit section state when customer changes
    _isCreditSectionExpanded = false;
    if (updatedCustomer != null) {
      if (_paymentType != 'credit') {
        _paymentType = 'credit';
        if (_dueDate == null) {
          _dueDate = DateTime.now().add(const Duration(days: 30));
        }
      }
      _creditAmount = 0;
    } else {
      _paymentType = 'cash';
      _isSplitPayment = false;
      _dueDate = null;
      _creditAmount = 0;
    }
    _cashAmount = 0;
    _cardAmount = 0;
    _itemPrices.clear();
    _itemAmounts.clear();
  }

  List<CustomerModel> _filteredCustomersForCurrentMode(
    List<CustomerModel> customers,
  ) {
    return customers.where((customer) {
      // Only show active customers in POS
      if (!customer.isActive) return false;

      if (_isWholesaleMode) {
        return customer.isWholesaleCustomer;
      }
      return customer.isRetailCustomer;
    }).toList();
  }

  void _focusProductSearchField({bool selectAll = true}) {
    FocusScope.of(context).requestFocus(_searchFocusNode);
    if (selectAll) {
      _searchController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchController.text.length,
      );
    } else {
      final textLength = _searchController.text.length;
      _searchController.selection = TextSelection.collapsed(offset: textLength);
    }
  }

  void _holdCurrentOrder() {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      AppSnackBar.show(
        context,
        SnackBar(
          content: Text('pos.cart_empty_hold'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Haptic feedback for mobile
    _triggerHapticFeedback(HapticFeedbackType.medium);

    // Calculate subtotal using _safeGetItemPrice to account for payment type
    final subtotal = cart.fold(0.0, (sum, item) {
      try {
        final basePrice = _safeGetItemPrice(item);
        final safePrice =
            basePrice.isNaN || basePrice.isInfinite ? 0.0 : basePrice;
        final safeQuantity = item.quantity.isNaN || item.quantity.isInfinite
            ? 0.0
            : item.quantity;
        return sum + (safePrice * safeQuantity);
      } catch (e) {
        return sum;
      }
    });
    final discountAmount = _discountType == 'percentage'
        ? (subtotal * _discount / 100)
        : _discount;
    final total = subtotal - discountAmount;

    // Create held order items with custom prices and discounts
    final heldOrderItems = cart
        .where((item) => !item.isBundle && item.product != null)
        .map((item) {
      final productId = item.product!.id.toString();
      final customPrice = _itemPrices[productId];
      final discount = _itemDiscounts[productId] ?? 0.0;

      return HeldOrderItem(
        product: item.product!,
        quantity: item.quantity,
        subtotal: item.subtotal,
        customPrice: customPrice,
        discount: discount,
      );
    }).toList();

    final heldOrder = HeldOrder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: _selectedSaleDate,
      customer: _selectedCustomer,
      orderType: _orderType,
      items: heldOrderItems,
      subtotal: subtotal,
      discount: discountAmount,
      total: total,
      paymentType: _paymentType,
      isSplitPayment: _isSplitPayment,
      cashAmount: _cashAmount,
      cardAmount: _cardAmount,
      isWholesale: _isWholesaleMode,
    );

    ref.read(heldOrdersProvider.notifier).addHeldOrder(heldOrder);

    // Clear cart after holding order
    _clearCart();

    AppSnackBar.show(
      context,
      SnackBar(
        content: Text(
          'pos.order_held_success'.tr(
            namedArgs: {'total': _formatCurrency(total)},
          ),
        ),
        backgroundColor: const Color(0xFFF59E0B),
        action: SnackBarAction(
          label: 'common.view'.tr(),
          textColor: Colors.white,
          onPressed: () => _showHeldOrders(),
        ),
      ),
    );
  }

  void _showHeldOrders() {
    final heldOrders = ref.read(heldOrdersProvider);
    if (heldOrders.isEmpty) {
      AppSnackBar.show(
        context,
        SnackBar(
          content: Text('pos.no_held'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final isMobile = MobileOptimization.isMobile(context);

    if (isMobile) {
      // Mobile: Use bottom sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildMobileHeldOrdersBottomSheet(heldOrders),
      );
    } else {
      // Desktop: Use dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.pause_circle, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text('pos.held_orders'.tr()),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${heldOrders.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            height: 400,
            child: ListView.builder(
              itemCount: heldOrders.length,
              itemBuilder: (context, index) {
                final order = heldOrders[index];
                return _buildHeldOrderCard(order, index, isMobile: false);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.close'.tr()),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildMobileHeldOrdersBottomSheet(List<HeldOrder> heldOrders) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color:
                    isDarkMode ? const Color(0xFF374151) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.pause_circle,
                      color: Color(0xFFF59E0B),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Held Orders',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${heldOrders.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Orders list
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: heldOrders.length,
                itemBuilder: (context, index) {
                  final order = heldOrders[index];
                  return _buildHeldOrderCard(order, index, isMobile: true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeldOrderCard(
    HeldOrder order,
    int index, {
    required bool isMobile,
  }) {
    final timestamp = order.timestamp;
    final customer = order.customer;
    final total = order.total;
    final items = order.items;
    final formattedSaleDate = DateFormat('dd MMM yyyy').format(timestamp);
    final formattedTime = DateFormat('hh:mm a').format(timestamp);
    final isWholesale = order.isWholesale;
    final orderType = order.orderType;

    if (isMobile) {
      // Mobile-optimized card with swipe actions
      return Dismissible(
        key: Key('held_order_${order.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.white, size: 28),
        ),
        confirmDismiss: (direction) async {
          return await _confirmDeleteHeldOrder(index);
        },
        onDismissed: (direction) {
          _deleteHeldOrder(index);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isWholesale
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isWholesale ? Icons.store : Icons.shopping_cart,
                      size: 18,
                      color: isWholesale ? Colors.red : Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isWholesale ? 'WHOLESALE ORDER' : 'RETAIL ORDER',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isWholesale ? Colors.red : Colors.blue,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.pause_circle,
                            size: 14,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'HELD',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer and order info
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF59E0B,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFFF59E0B),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer?.name ?? 'pos.walk_in'.tr(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    _getOrderTypeIcon(orderType),
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatOrderType(orderType),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Order details
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Items',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                '${items.length} items',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'misc.pos_total'.tr(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                _formatCurrency(total),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$formattedSaleDate at $formattedTime',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Action buttons
                    Consumer(
                      builder: (context, ref, child) {
                        final cart = ref.watch(cartProvider);
                        final canResume = cart.isEmpty;
                        return Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: canResume
                                    ? () {
                                        _triggerHapticFeedback(
                                          HapticFeedbackType.medium,
                                        );
                                        _resumeOrder(index);
                                      }
                                    : null,
                                icon: const Icon(Icons.play_circle, size: 20),
                                label: Text('common.resume'.tr()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canResume
                                      ? const Color(0xFF10B981)
                                      : Colors.grey.shade300,
                                  foregroundColor: canResume
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 56,
                              child: ElevatedButton(
                                onPressed: () {
                                  _triggerHapticFeedback(
                                    HapticFeedbackType.medium,
                                  );
                                  _deleteHeldOrder(index);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade50,
                                  foregroundColor: Colors.red,
                                  padding: const EdgeInsets.all(14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Icon(Icons.delete, size: 20),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    Builder(
                      builder: (context) {
                        final cart = ref.watch(cartProvider);
                        final canResume = cart.isEmpty;
                        if (!canResume) {
                          return Column(
                            children: [
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: Colors.orange.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Clear current cart to resume this order',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Desktop card (original design)
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wholesale/Retail Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isWholesale
                    ? Colors.red.withValues(alpha: 0.1)
                    : Colors.blue.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isWholesale ? Icons.store : Icons.shopping_cart,
                    size: 16,
                    color: isWholesale ? Colors.red : Colors.blue,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isWholesale ? 'WHOLESALE ORDER' : 'RETAIL ORDER',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isWholesale ? Colors.red : Colors.blue,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.pause_circle,
                          color: Color(0xFFF59E0B),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer?.name ?? 'pos.walk_in'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${items.length} items • ${_formatCurrency(total)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              'Sale Date: $formattedSaleDate',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Consumer(
                        builder: (context, ref, child) {
                          final cart = ref.watch(cartProvider);
                          final canResume = cart.isEmpty;
                          return Row(
                            children: [
                              IconButton(
                                onPressed: canResume
                                    ? () => _resumeOrder(index)
                                    : null,
                                icon: Icon(
                                  Icons.play_circle,
                                  color: canResume
                                      ? const Color(0xFF10B981)
                                      : Colors.grey.shade400,
                                ),
                                tooltip: canResume
                                    ? 'pos.resume_order'.tr()
                                    : 'pos.resume_disabled_hint'.tr(),
                              ),
                              IconButton(
                                onPressed: () => _deleteHeldOrder(index),
                                icon: const Icon(
                                  Icons.delete,
                                  color: Color(0xFFEF4444),
                                ),
                                tooltip: 'pos.delete_order_tooltip'.tr(),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<bool?> _confirmDeleteHeldOrder(int index) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text('pos.delete_held_title'.tr()),
          ],
        ),
        content: Text('pos.delete_held_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
  }

  IconData _getOrderTypeIcon(String orderType) {
    switch (orderType) {
      case 'dine_in':
        return Icons.table_restaurant;
      case 'takeout':
      case 'take_away':
        return Icons.shopping_bag;
      case 'delivery':
        return Icons.delivery_dining;
      default:
        return Icons.receipt;
    }
  }

  String _formatOrderType(String orderType) {
    switch (orderType) {
      case 'dine_in':
        return 'pos.order_type_dine_in'.tr();
      case 'takeout':
      case 'take_away':
        return 'pos.order_type_take_away'.tr();
      case 'delivery':
        return 'pos.order_type_delivery'.tr();
      default:
        return orderType.replaceAll('_', ' ').toUpperCase();
    }
  }

  void _resumeOrder(int index) {
    // Check if cart is not empty - prevent resuming another order while one is already resumed
    final cart = ref.read(cartProvider);
    if (cart.isNotEmpty) {
      AppSnackBar.show(
        context,
        SnackBar(
          content: Text(
            'pos.resume_blocked_cart'.tr(
              namedArgs: {
                'items': cart.length == 1
                    ? 'pos.cart_one_item'.tr()
                    : 'pos.cart_n_items'.tr(namedArgs: {'n': '${cart.length}'}),
              },
            ),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'pos.clear_cart'.tr(),
            textColor: Colors.white,
            onPressed: () {
              ref.read(cartProvider.notifier).clear();
              _clearCart();
            },
          ),
        ),
      );
      return;
    }

    final heldOrders = ref.read(heldOrdersProvider);
    final order = heldOrders[index];

    // Restore order data
    setState(() {
      _selectedCustomer = order.customer;
      _isCreditSectionExpanded = false; // Reset credit section state
      _selectedSaleDate = order.timestamp;
      _orderType = order.orderType;
      _paymentType = order.paymentType;
      _isSplitPayment = order.isSplitPayment;
      _cashAmount = order.cashAmount;
      _cardAmount = order.cardAmount;
      _discount = order.discount;
      _isWholesaleMode = order.isWholesale; // Restore wholesale mode

      // Clear existing custom prices and discounts
      _itemPrices.clear();
      _itemDiscounts.clear();
      _itemAmounts.clear();

      // Restore custom prices and discounts from held order
      for (final item in order.items) {
        if (item.product.id == null) continue;
        final productId = item.product.id.toString();
        if (item.customPrice != null) {
          _itemPrices[productId] = item.customPrice!;
        }
        if (item.discount > 0) {
          _itemDiscounts[productId] = item.discount;
        }
      }
    });

    // Restore cart items
    for (final item in order.items) {
      final product = item.product;
      final quantity = item.quantity;
      // Add items to cart with the specified quantity
      ref.read(cartProvider.notifier).addProduct(product);
      if (quantity > 1) {
        ref.read(cartProvider.notifier).updateQuantity(product.id!, quantity);
      }
      // Restore item-level discount if any
      if (item.discount > 0) {
        ref
            .read(cartProvider.notifier)
            .updateDiscount(product.id!, item.discount);
      }
    }

    // Remove from held orders
    ref.read(heldOrdersProvider.notifier).removeHeldOrderByIndex(index);

    // Close dialog safely
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    AppSnackBar.show(
      context,
      SnackBar(
        content: Text('pos.order_resumed'.tr()),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  void _deleteHeldOrder(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('pos.delete_held_appbar'.tr()),
        content: const Text(
          'Are you sure you want to delete this held order? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(heldOrdersProvider.notifier)
                  .removeHeldOrderByIndex(index);
              Navigator.pop(context);
              Navigator.pop(context); // Close held orders dialog
              AppSnackBar.show(
                context,
                SnackBar(
                  content: Text('pos.held_deleted'.tr()),
                  backgroundColor: Color(0xFFEF4444),
                ),
              );
            },
            child: Text(
              'common.delete'.tr(),
              style: const TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }

  void _showItemPriceEditDialog(CartItem item) {
    if (item.isBundle || item.product == null) return;

    final currentPrice =
        _itemPrices[item.product!.id.toString()] ?? item.product!.price;
    final priceController = TextEditingController(
      text: currentPrice.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.edit, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            Text(
              'pos.edit_price_with_name'.tr(
                namedArgs: {'name': item.product!.name},
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Original Price: ${_formatCurrency(item.product!.price)}',
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: InputDecoration(
                labelText: 'New Price',
                hintText: 'pos.hint_new_price'.tr(),
                prefixIcon: const Icon(
                  Icons.currency_rupee,
                  color: Color(0xFF10B981),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [DecimalInputFormatter(maxDecimalPlaces: 2)],
            ),
            if (priceController.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Column(
                  children: [
                    Text(
                      'New Price: ${_formatCurrency(double.tryParse(priceController.text) ?? 0.0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    Text(
                      'Difference: ${_formatCurrency((double.tryParse(priceController.text) ?? 0.0) - item.product!.price)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (item.product != null) {
                setState(() {
                  _itemPrices.remove(item.product!.id.toString());
                });
              }
              Navigator.pop(context);
            },
            child: Text('common.reset'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              final input = priceController.text.trim();
              final newPrice = double.tryParse(input);
              if (newPrice == null || !newPrice.isFinite || newPrice <= 0) {
                if (mounted) {
                  AppSnackBar.show(
                    context,
                    SnackBar(
                      content: Text('pos.enter_valid_price'.tr()),
                      backgroundColor: Color(0xFFEF4444),
                    ),
                  );
                }
                return;
              }
              _handlePriceInput(item, input);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
  }

  void _showQuickEditCartItemDialog(CartItem item) {
    if (item.product == null || item.isBundle) return;

    HapticFeedbackUtil.light();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _safeGetProductName(item.product!),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      leading: const Icon(Icons.edit, color: Color(0xFF3B82F6)),
                      title: Text('pos.edit_price'.tr()),
                      subtitle: Text(
                        'pos.current_amount'.tr(
                          namedArgs: {
                            'amount': _formatCurrency(_safeGetItemPrice(item)),
                          },
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showItemPriceEditDialog(item);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showItemDiscountDialog(CartItem item) {
    if (item.isBundle || item.product == null) return;

    final currentDiscount = _itemDiscounts[item.product!.id.toString()] ?? 0.0;
    final discountController = TextEditingController(
      text: currentDiscount > 0 ? currentDiscount.toString() : '',
    );
    String discountType = 'fixed'; // Default to fixed amount

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.discount, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 8),
              Text(
                'pos.item_discount_with_name'.tr(
                  namedArgs: {'name': item.product!.name},
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Original Price: ${_formatCurrency(item.product!.price)}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildItemDiscountButton(
                      'fixed',
                      ref.read(currentCurrencyProvider).symbol,
                      discountType,
                      () {
                        setDialogState(() {
                          discountType = 'fixed';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildItemDiscountButton(
                      'percentage',
                      '%',
                      discountType,
                      () {
                        setDialogState(() {
                          discountType = 'percentage';
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: discountController,
                decoration: InputDecoration(
                  labelText: discountType == 'percentage'
                      ? 'Discount %'
                      : 'Discount Amount',
                  hintText: discountType == 'percentage'
                      ? 'Enter percentage (e.g., 10)'
                      : 'pos.hint_amount_example'.tr(),
                  prefixIcon: Icon(
                    discountType == 'percentage'
                        ? Icons.percent
                        : Icons.currency_rupee,
                    color: const Color(0xFF8B5CF6),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [DecimalInputFormatter(maxDecimalPlaces: 2)],
              ),
              if (discountController.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF0EA5E9)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'New Price: ${_formatCurrency(_calculateNewPrice(item.product!.price, discountController.text, discountType))}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0EA5E9),
                        ),
                      ),
                      Text(
                        'Savings: ${_formatCurrency(item.product!.price - _calculateNewPrice(item.product!.price, discountController.text, discountType))}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (item.product != null) {
                  setState(() {
                    _itemDiscounts.remove(item.product!.id.toString());
                  });
                }
                Navigator.pop(context);
                AppSnackBar.show(
                  context,
                  SnackBar(
                    content: Text('pos.discount_removed'.tr()),
                    backgroundColor: Color(0xFFF59E0B),
                  ),
                );
              },
              child: Text('pos.remove_discount'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                if (item.product == null) return;
                final discountValue =
                    double.tryParse(discountController.text) ?? 0.0;
                if (discountValue > 0) {
                  setState(() {
                    if (discountType == 'percentage') {
                      _itemDiscounts[item.product!.id.toString()] =
                          (item.product!.price * discountValue / 100);
                    } else {
                      _itemDiscounts[item.product!.id.toString()] =
                          discountValue;
                    }
                  });
                  Navigator.pop(context);
                  AppSnackBar.show(
                    context,
                    SnackBar(
                      content: Text(
                        'Item discount applied: ${_formatCurrency(_itemDiscounts[item.product!.id.toString()]!)}',
                      ),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                } else {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
              child: Text('common.apply'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemDiscountButton(
    String type,
    String label,
    String selectedType,
    VoidCallback onTap,
  ) {
    final isSelected = selectedType == type;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B5CF6) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF8B5CF6) : const Color(0xFFE2E8F0),
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  double _calculateNewPrice(
    double originalPrice,
    String discountText,
    String discountType,
  ) {
    final discountValue = double.tryParse(discountText) ?? 0.0;
    if (discountType == 'percentage') {
      return originalPrice - (originalPrice * discountValue / 100);
    } else {
      return originalPrice - discountValue;
    }
  }

  Future<void> _showBarcodeScanner() async {
    try {
      final canOpen = await _ensureBarcodeScannerAvailable();
      if (!canOpen || !mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          // Use StatefulBuilder to manage scanner state
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final isDarkMode = ref.watch(isDarkModeProvider);
              return Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  height: 400,
                  decoration: BoxDecoration(
                    color: isDarkMode ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFF3B82F6),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.qr_code_scanner,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Scan Barcode',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () {
                                if (Navigator.canPop(dialogContext)) {
                                  Navigator.pop(dialogContext);
                                }
                              },
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: MobileScanner(
                              onDetect: (capture) {
                                final barcodes = capture.barcodes;
                                for (final barcode in barcodes) {
                                  final value = barcode.rawValue;
                                  if (value != null &&
                                      Navigator.canPop(dialogContext)) {
                                    _handleBarcodeScanned(value);
                                    Navigator.pop(dialogContext);
                                    break;
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'pos.hint_barcode_manual'.tr(),
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.keyboard),
                                ),
                                onSubmitted: (value) {
                                  if (value.isNotEmpty &&
                                      Navigator.canPop(dialogContext)) {
                                    _handleBarcodeScanned(value);
                                    Navigator.pop(dialogContext);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                if (Navigator.canPop(dialogContext)) {
                                  Navigator.pop(dialogContext);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B82F6),
                                foregroundColor: Colors.white,
                              ),
                              child: Text('common.close'.tr()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (error, stackTrace) {
      debugPrint('Barcode dialog error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              'pos.err_open_barcode_scanner'.tr(namedArgs: {'error': '$error'}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleBarcodeScanned(String barcode) async {
    // Ensure we're still mounted before processing
    if (!mounted) return;

    // Use the more robust barcode input handler
    await _handleBarcodeInput(barcode);
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final products = ref.watch(productNotifierProvider);
    final customers = ref.watch(customersProvider);

    // Get screen size and platform information
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 768;
    final isTablet = screenSize.width >= 768 && screenSize.width < 1024;
    final isDesktop = screenSize.width >= 1024;
    final isWeb = kIsWeb;

    // Use persistent focus node for keyboard handling
    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        _handleKeyPress(_keyboardFocusNode, event);
      },
      child: GestureDetector(
        onTap: () {
          // Unfocus all fields when tapping outside
          _unfocusAllFields();
        },
        child: Consumer(
          builder: (context, ref, child) {
            final isDarkMode = ref.watch(isDarkModeProvider);
            return Scaffold(
              backgroundColor: isDarkMode
                  ? AppColors.backgroundDark
                  : AppColors.backgroundLight,
              appBar: isMobile
                  ? _buildMobileAppBar(cart)
                  : _buildModernAppBar(cart),
              body: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.backgroundDark
                        : AppColors.backgroundLight,
                  ),
                  child: _buildResponsiveLayout(
                    cart,
                    products,
                    customers,
                    isMobile,
                    isTablet,
                    isDesktop,
                    isWeb,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildResponsiveLayout(
    List<CartItem> cart,
    AsyncValue<List<ProductModel>> products,
    AsyncValue<List<CustomerModel>> customers,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
    bool isWeb,
  ) {
    if (isMobile) {
      // Mobile: Tab-based layout with cleaner design
      final isDarkMode = ref.watch(isDarkModeProvider);
      final surfaceColor = isDarkMode ? AppColors.surfaceDark : Colors.white;
      final tabLabelColor = isDarkMode ? Colors.white : AppColors.primaryColor;
      final tabUnselectedColor = AppColors.textSecondary;

      return DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDarkMode ? 0.3 : 0.05,
                    ),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                labelColor: tabLabelColor,
                unselectedLabelColor: tabUnselectedColor,
                indicatorColor: AppColors.primaryColor,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                tabs: [
                  Tab(text: 'pos.tab_products'.tr()),
                  Tab(text: 'pos.tab_cart'.tr()),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildMobileProductsSection(products),
                  _buildMobileCartSection(cart, customers),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Laptop/desktop: keep the cart comfortably usable while giving products
      // the larger working area. This avoids the cramped 50/50 split on
      // common 13- and 14-inch screens.
      return LayoutBuilder(
        builder: (context, constraints) {
          final cartWidth = (constraints.maxWidth * (isTablet ? .38 : .36))
              .clamp(410.0, 520.0);
          return Row(
            children: [
              Expanded(child: _buildModernProductsSection(products)),
              SizedBox(
                width: cartWidth,
                child: _buildModernCartSection(cart),
              ),
            ],
          );
        },
      );
    }
  }

  PreferredSizeWidget _buildMobileAppBar(List<CartItem> cart) {
    // Calculate cart total using _safeGetItemPrice to account for payment type
    final cartTotal = cart.fold(0.0, (sum, item) {
      try {
        final basePrice = _safeGetItemPrice(item);
        final safePrice =
            basePrice.isNaN || basePrice.isInfinite ? 0.0 : basePrice;
        final safeQuantity = item.quantity.isNaN || item.quantity.isInfinite
            ? 0.0
            : item.quantity;
        return sum + (safePrice * safeQuantity);
      } catch (e) {
        return sum;
      }
    });

    final isDarkMode = ref.watch(isDarkModeProvider);
    return AppBar(
      backgroundColor: isDarkMode ? AppColors.surfaceDark : Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryLight, AppColors.primaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.point_of_sale,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'POS System',
              style: TextStyle(
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Cart Summary - Cleaner design
        Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryLight.withValues(alpha: 0.12),
                AppColors.primaryColor.withValues(alpha: 0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primaryColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.shopping_cart,
                  size: 16,
                  color: AppColors.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cart.length} items',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  Text(
                    _formatCurrency(cartTotal),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Quick Actions Menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
          onSelected: (value) {
            switch (value) {
              case 'hold':
                _holdCurrentOrder();
                break;
              case 'resume':
                _showHeldOrders();
                break;
              case 'clear':
                _clearCart();
                break;
              case 'sales':
                context.push('/sales');
                break;
              case 'reports':
                context.push('/reports');
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'hold',
              child: Row(
                children: [
                  const Icon(Icons.pause_circle, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  Text('pos.hold_order'.tr()),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'resume',
              child: Consumer(
                builder: (context, ref, child) {
                  final heldOrdersCount = ref.watch(heldOrdersCountProvider);
                  return Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.play_circle,
                            color: Color(0xFF10B981),
                          ),
                          if (heldOrdersCount > 0)
                            Positioned(
                              right: -6,
                              top: -6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF59E0B),
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  heldOrdersCount > 9
                                      ? '9+'
                                      : '$heldOrdersCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Text('pos.resume_order'.tr()),
                    ],
                  );
                },
              ),
            ),
            PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  const Icon(Icons.clear_all, color: Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  Text('pos.clear_cart'.tr()),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'sales',
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  Text('pos.sales'.tr()),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'reports',
              child: Row(
                children: [
                  const Icon(Icons.analytics, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  Text('pos.reports_nav'.tr()),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  PreferredSizeWidget _buildModernAppBar(List<CartItem> cart) {
    // Calculate cart total using _safeGetItemPrice to account for payment type
    final cartTotal = cart.fold(0.0, (sum, item) {
      try {
        final basePrice = _safeGetItemPrice(item);
        final safePrice =
            basePrice.isNaN || basePrice.isInfinite ? 0.0 : basePrice;
        final safeQuantity = item.quantity.isNaN || item.quantity.isInfinite
            ? 0.0
            : item.quantity;
        return sum + (safePrice * safeQuantity);
      } catch (e) {
        return sum;
      }
    });
    final titleText = _isWholesaleMode
        ? (_selectedCustomer != null ? 'Wholesale Credit' : 'Wholesale Cash')
        : (_selectedCustomer != null ? 'Retail Credit' : 'Point of Sale');

    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1E293B),
      title: Row(
        children: [
          // Space for the full-screen POS navigation reveal button supplied by
          // the desktop shell.
          const SizedBox(width: 44),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.point_of_sale,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titleText,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                '${cart.length} items • ${_formatCurrency(cartTotal)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Wholesale Mode Toggle Button
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _isWholesaleMode = !_isWholesaleMode;
                  _itemPrices.clear();
                  _itemAmounts.clear();
                  if (_selectedCustomer != null) {
                    final allowed = _isWholesaleMode
                        ? _selectedCustomer!.isWholesaleCustomer
                        : _selectedCustomer!.isRetailCustomer;
                    if (!allowed) {
                      _applyCustomerSelection(null);
                    }
                  }
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: _isWholesaleMode
                      ? Colors.red.withValues(alpha: 0.15)
                      : Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isWholesaleMode
                        ? Colors.red
                        : Colors.red.withValues(alpha: 0.3),
                    width: _isWholesaleMode ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.store,
                      size: 14,
                      color: _isWholesaleMode
                          ? Colors.red
                          : Colors.red.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Wholesale',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _isWholesaleMode
                            ? Colors.red
                            : Colors.red.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildQuickActionButton(
          icon: Icons.pause_circle,
          label: 'pos.label_hold_short'.tr(),
          color: const Color(0xFFF59E0B),
          onPressed: () => _holdCurrentOrder(),
          tooltip: 'pos.tooltip_hold_current'.tr(),
        ),
        _buildQuickActionButton(
          icon: Icons.play_circle,
          label: 'pos.resume_order'.tr(),
          color: const Color(0xFF10B981),
          onPressed: () => _showHeldOrders(),
        ),
        // Split Payment Toggle Button
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (_selectedCustomer == null) {
                  if (mounted) {
                    AppSnackBar.show(
                      context,
                      SnackBar(
                        content: Text('pos.split_customer'.tr()),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                  return;
                }
                setState(() {
                  _isSplitPayment = !_isSplitPayment;
                  if (!_isSplitPayment) {
                    _cashAmount = 0;
                    _cardAmount = 0;
                    _creditAmount = 0;
                  }
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: _isSplitPayment
                      ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                      : const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isSplitPayment
                        ? const Color(0xFF6366F1)
                        : const Color(0xFF6366F1).withValues(alpha: 0.3),
                    width: _isSplitPayment ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.call_split,
                      size: 14,
                      color: _isSplitPayment
                          ? const Color(0xFF6366F1)
                          : const Color(0xFF6366F1).withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'pos.label_split_payment'.tr(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _isSplitPayment
                            ? const Color(0xFF6366F1)
                            : const Color(0xFF6366F1).withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildQuickActionButton(
          icon: Icons.clear_all,
          label: 'common.clear'.tr(),
          color: const Color(0xFFEF4444),
          onPressed: () => _clearCart(),
        ),
        _buildQuickActionButton(
          icon: Icons.payments,
          label: 'pos.currency_notes'.tr(),
          color: const Color(0xFF6366F1),
          onPressed: () => _showCurrencyNotesDialog(),
        ),
        _buildQuickActionButton(
          icon: Icons.keyboard,
          label: 'pos.shortcuts'.tr(),
          color: const Color(0xFF8B5CF6),
          onPressed: () => _showKeyboardShortcutsHelp(),
        ),
        _buildQuickActionButton(
          icon: Icons.print,
          label: 'pos.label_printer'.tr(),
          color: const Color(0xFF059669),
          onPressed: () => _openPrinterSettings(),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
    String? tooltip,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Tooltip(
            message: tooltip ?? label,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: onPressed == null
                    ? color.withValues(alpha: 0.05)
                    : color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: onPressed == null
                      ? color.withValues(alpha: 0.1)
                      : color.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: onPressed == null
                        ? color.withValues(alpha: 0.5)
                        : color,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: onPressed == null
                          ? color.withValues(alpha: 0.5)
                          : color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileProductsSection(AsyncValue<List<ProductModel>> products) {
    return Container(
      color: AppColors.backgroundLight,
      child: Column(
        children: [
          // Search and Filter Section with better spacing
          Container(
            padding: MobileOptimization.getResponsivePadding(context),
            color: Colors.white,
            child: _buildMobileSearchAndFilterSection(),
          ),
          // Products Grid
          Expanded(child: _buildMobileProductsGrid(products)),
        ],
      ),
    );
  }

  Widget _buildMobileSearchAndFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Bar - Cleaner design
        TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          textInputAction: TextInputAction.search,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'pos.hint_search_products'.tr(),
            hintStyle: TextStyle(
              color: const Color(0xFF94A3B8),
              fontSize: MobileOptimization.getResponsiveFontSize(
                context,
                mobile: 15,
                tablet: 16,
                desktop: 16,
              ),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.search,
                color: AppColors.primaryColor,
                size: MobileOptimization.getResponsiveIconSize(
                  context,
                  mobile: 20,
                  tablet: 22,
                  desktop: 24,
                ),
              ),
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_searchController.text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    child: IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _searchFocusNode.unfocus();
                        setState(() {});
                      },
                    ),
                  ),
                // Hide barcode icon on Windows (automatic scanning enabled)
                if (!Platform.isWindows)
                  Container(
                    padding: const EdgeInsets.all(8),
                    child: IconButton(
                      icon: const Icon(
                        Icons.qr_code_scanner,
                        color: AppColors.primaryColor,
                        size: 20,
                      ),
                      onPressed: () => _showBarcodeScanner(),
                      tooltip: 'pos.tooltip_scan_barcode'.tr(),
                    ),
                  ),
              ],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.borderColor,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.borderColor,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primaryColor,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: AppColors.backgroundLight,
            contentPadding: MobileOptimization.getTextFieldPadding(context),
          ),
          onChanged: (value) {
            if (mounted) {
              setState(() {});
            }
          },
          onSubmitted: (value) {
            unawaited(_onProductSearchSubmitted(value));
          },
        ),

        SizedBox(height: MobileOptimization.getFormFieldSpacing(context)),
        // Category Filter
        CategoryFilterWidget(
          selectedCategory: _selectedCategory,
          onCategorySelected: (category) {
            setState(() {
              _selectedCategory = category;
              _showBundles = category == 'bundles';
            });
            _triggerCategoryLoading();
          },
          isMobile: true,
        ),
      ],
    );
  }

  Widget _buildMobileCategoryFilter() {
    final categoriesAsync = ref.watch(categoryNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Categories',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            if (_selectedCategory != 'all')
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = 'all';
                    _showBundles = false;
                  });
                  _triggerCategoryLoading();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildMobileCategoryChip(
                'all',
                'All',
                Icons.apps,
                const Color(0xFF3B82F6),
              ),
              const SizedBox(width: 10),
              _buildMobileCategoryChip(
                'bundles',
                'Bundles',
                Icons.inventory_2,
                Colors.orange,
              ),
              const SizedBox(width: 10),
              ...categoriesAsync.when(
                data: (categories) => categories.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _buildMobileCategoryChip(
                      category.name.toLowerCase(),
                      category.name,
                      _getIconFromString(category.icon),
                      Color(int.parse('FF${category.color}', radix: 16)),
                    ),
                  );
                }).toList(),
                loading: () => [
                  const SizedBox(
                    width: 100,
                    height: 40,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (_, __) => [
                  SizedBox(
                    width: 100,
                    height: 40,
                    child: Center(child: Text('pos.error_categories'.tr())),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileCategoryChip(
    String category,
    String label,
    IconData icon,
    Color categoryColor,
  ) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () {
        if (!mounted || _selectedCategory == category) return;
        setState(() {
          _selectedCategory = category;
          _showBundles = category == 'bundles';
        });
        if (category != 'bundles') {
          _triggerCategoryLoading();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: MobileOptimization.isMobile(context) ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? categoryColor : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? categoryColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: categoryColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: MobileOptimization.getResponsiveIconSize(
                context,
                mobile: 16,
                tablet: 18,
                desktop: 18,
              ),
              color: isSelected ? Colors.white : categoryColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF1E293B),
                fontSize: MobileOptimization.getResponsiveFontSize(
                  context,
                  mobile: 13,
                  tablet: 14,
                  desktop: 14,
                ),
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileProductsGrid(AsyncValue<List<ProductModel>> products) {
    // Show bundles if bundles category is selected
    if (_showBundles) {
      return _buildBundlesGrid();
    }

    return products.when(
      data: (productList) {
        final filteredProducts = productList.where((product) {
          // Business Rule: Only show items where Retail Cash (price) >= Cost Price (cost)
          final validPrice = product.price >= product.cost;

          final searchTerm = _searchController.text.trim().toLowerCase();
          final categoryMatch = _selectedCategory == 'all' ||
              product.category.toLowerCase() == _selectedCategory;
          final matchesSearch = _productNameMatchesQuery(product, searchTerm);

          return validPrice && categoryMatch && matchesSearch;
        }).toList();

        if (filteredProducts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'No products found',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Try adjusting your search terms',
                  style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 16),
                if (_isMobileHandset)
                  ElevatedButton.icon(
                    onPressed: () {
                      if (!mounted) return;
                      setState(() {
                        _searchController.clear();
                        _selectedCategory = 'all';
                        _showBundles = false;
                      });
                      // Refresh products after clearing filters
                      ref.invalidate(productNotifierProvider);
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text('pos.clear_filters'.tr()),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Refresh products
            ref.invalidate(productNotifierProvider);
            // Haptic feedback
            _triggerHapticFeedback(HapticFeedbackType.light);
          },
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              if (index >= filteredProducts.length) {
                return const SizedBox.shrink();
              }

              final product = filteredProducts[index];
              final currency = ref.watch(currentCurrencyProvider);

              // Safety check for product validity
              if (product.id == null || product.name.isEmpty) {
                return const SizedBox.shrink();
              }

              return GestureDetector(
                onLongPress: () {
                  HapticFeedbackUtil.medium();
                  _showProductQuickActionsMenu(product, currency);
                },
                child: EnhancedProductCard(
                  product: product,
                  currency: currency,
                  onTap: () => _addToCart(product),
                  showStockWarning: true,
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        // Log error for debugging
        debugPrint('Error loading products in POS (mobile): $error');
        debugPrint('Stack trace: $stack');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('pos.err_load_products'.tr(namedArgs: {'error': '$error'})),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(productNotifierProvider);
                },
                child: Text('common.retry'.tr()),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showProductQuickActionsMenu(ProductModel product, Currency currency) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${currency.symbol}${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      leading: const Icon(
                        Icons.add_shopping_cart,
                        color: Color(0xFF3B82F6),
                      ),
                      title: Text('pos.add_to_cart'.tr()),
                      onTap: () {
                        Navigator.pop(context);
                        _addToCart(product);
                        HapticFeedbackUtil.success();
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.info_outline,
                        color: Color(0xFF8B5CF6),
                      ),
                      title: Text('pos.view_details'.tr()),
                      onTap: () {
                        Navigator.pop(context);
                        _showProductDetailsDialog(product);
                      },
                    ),
                    if (ref
                            .watch(authProvider)
                            .currentUser
                            ?.canManageProducts() ??
                        false)
                      ListTile(
                        leading: const Icon(
                          Icons.edit,
                          color: Color(0xFF10B981),
                        ),
                        title: Text('pos.edit_product'.tr()),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/edit-product?id=${product.id}');
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBundlesGrid() {
    final bundlesAsync = ref.watch(bundlesProvider);
    final currency = ref.watch(currentCurrencyProvider);

    return bundlesAsync.when(
      data: (bundles) {
        final searchTerm = _searchController.text.trim().toLowerCase();
        final filteredBundles = bundles.where((bundle) {
          if (searchTerm.isEmpty) return true;
          return bundle.name.toLowerCase().contains(searchTerm) ||
              (bundle.description?.toLowerCase().contains(searchTerm) ?? false);
        }).toList();

        if (filteredBundles.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No bundles found',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create bundles in the Bundles screen',
                  style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(bundlesProvider);
            _triggerHapticFeedback(HapticFeedbackType.light);
          },
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: filteredBundles.length,
            itemBuilder: (context, index) {
              final bundle = filteredBundles[index];
              return _buildBundleCard(bundle, currency);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('pos.err_load_bundles'.tr(namedArgs: {'error': '$error'})),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(bundlesProvider),
              child: Text('common.retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBundleCard(ProductBundleModel bundle, Currency currency) {
    final isOutOfStock = bundle.items.any((item) => item.product.stock <= 0);
    final isDarkMode = ref.watch(isDarkModeProvider);
    final bgColor = isOutOfStock
        ? (isDarkMode ? const Color(0xFF2A2F36) : const Color(0xFFF1F5F9))
        : (isDarkMode ? AppColors.surfaceDark : Colors.white);
    final borderColor = isDarkMode
        ? const Color(0xFF374151)
        : (isOutOfStock ? const Color(0xFFE2E8F0) : const Color(0xFFE2E8F0));

    return GestureDetector(
      onTap: () => _addBundleToCart(bundle),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bundle Header
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isOutOfStock
                        ? (isDarkMode
                            ? [
                                const Color(0xFF2A2F36),
                                const Color(0xFF23272F),
                              ]
                            : [
                                const Color(0xFFF1F5F9),
                                const Color(0xFFE2E8F0),
                              ])
                        : (isDarkMode
                            ? [
                                Colors.orange.shade900.withValues(alpha: 0.3),
                                Colors.orange.shade800.withValues(alpha: 0.2),
                              ]
                            : [
                                Colors.orange.shade100,
                                Colors.orange.shade50,
                              ]),
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.inventory_2,
                        size: 40,
                        color: isOutOfStock
                            ? (isDarkMode
                                ? const Color(0xFF64748B)
                                : Colors.grey.shade400)
                            : Colors.orange.shade700,
                      ),
                    ),
                    if (bundle.discountPercentage > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${bundle.discountPercentage.toStringAsFixed(0)}% OFF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    if (isOutOfStock)
                      const Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: Center(
                          child: Text(
                            'OUT',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Bundle Info
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bundle.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isOutOfStock
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF1E293B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      '${currency.symbol}${bundle.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isOutOfStock
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF059669),
                      ),
                    ),
                    if (bundle.items.isNotEmpty)
                      Text(
                        '${bundle.items.length} items',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedMobileProductCard(ProductModel product) {
    final isLowStock = product.stock <= 5;
    final isOutOfStock = product.stock <= 0;

    return GestureDetector(
      onTap: isOutOfStock ? null : () => _addToCart(product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image/Icon Section
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isOutOfStock
                        ? [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)]
                        : [
                            const Color(0xFF3B82F6).withValues(alpha: 0.1),
                            const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                          ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        _getProductIcon(product.category),
                        size: 32,
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                    // Stock indicator
                    if (isLowStock && !isOutOfStock)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Low Stock',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    // Out of Stock indicator
                    if (isOutOfStock)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Out of Stock',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Product Info Section
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isOutOfStock
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF1E293B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(product.price),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isOutOfStock
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF059669),
                      ),
                    ),
                    // Stock info
                    ...[
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Stock: ${product.stock.toInt()}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isOutOfStock
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF3B82F6,
                              ).withValues(alpha: isOutOfStock ? 0.05 : 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.add,
                              size: 16,
                              color: const Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileProductCard(ProductModel product) {
    final isLowStock = product.stock <= 5;
    final isOutOfStock = product.stock <= 0;
    final isDarkMode = ref.watch(isDarkModeProvider);

    return GestureDetector(
      onTap: () => _addToCart(product),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isDarkMode ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image/Icon
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      const Color(0xFF1D4ED8).withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        _getProductIcon(product.category),
                        size: 32,
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                    // Stock indicators
                    if (isLowStock && !isOutOfStock)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFF59E0B,
                                ).withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'LOW',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    // Out of Stock indicator
                    if (isOutOfStock)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFEF4444,
                                ).withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'OUT',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Product Info
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isOutOfStock
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF1E293B),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatCurrency(product.price),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isOutOfStock
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF059669),
                          ),
                        ),
                        // Stock info
                        ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.inventory_2,
                                size: 10,
                                color: isLowStock
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${product.stock.toInt()}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isLowStock
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCartSection(
    List<CartItem> cart,
    AsyncValue<List<CustomerModel>> customers,
  ) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF374151)
                  : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Cart Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.shopping_cart,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shopping Cart',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        '${cart.length} items',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (cart.isNotEmpty)
                  IconButton(
                    onPressed: _clearCart,
                    icon: const Icon(Icons.clear_all, color: Color(0xFFEF4444)),
                    tooltip: 'Clear Cart',
                  ),
              ],
            ),
          ),
          // Customer Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildEnhancedMobileCustomerSection(customers),
          ),
          const SizedBox(height: 16),
          // Cart Items
          Expanded(child: _buildEnhancedMobileCartItems(cart)),
          // Cart Summary
          _buildEnhancedMobileCartSummary(cart),
        ],
      ),
    );
  }

  Widget _buildStickyPaymentButton(List<CartItem> cart) {
    if (cart.isEmpty) return const SizedBox.shrink();

    final isDarkMode = ref.watch(isDarkModeProvider);

    // Calculate total the same way as _buildEnhancedMobileCartSummary
    final subtotal = cart.fold(0.0, (sum, item) {
      try {
        final basePrice = _safeGetItemPrice(item);
        final safePrice =
            basePrice.isNaN || basePrice.isInfinite ? 0.0 : basePrice;
        final safeQuantity = item.quantity.isNaN || item.quantity.isInfinite
            ? 0.0
            : item.quantity;
        final itemSubtotal = safePrice * safeQuantity;
        final safeItemSubtotal =
            itemSubtotal.isNaN || itemSubtotal.isInfinite ? 0.0 : itemSubtotal;
        return sum + safeItemSubtotal;
      } catch (e) {
        return sum;
      }
    });
    final discountAmount = _discountType == 'percentage'
        ? (subtotal * _discount / 100)
        : _discount;
    final subtotalAfterDiscount = subtotal - discountAmount;
    final taxRate = ref.watch(currentTaxRateProvider);
    final taxAmount = TaxCalculator.calculateTax(
      subtotalAfterDiscount,
      taxRate,
    );
    final total = subtotalAfterDiscount + taxAmount;
    final safeTotal = total.isNaN || total.isInfinite ? 0.0 : total;

    // Button is always enabled if cart has items
    final isButtonEnabled =
        cart.isNotEmpty && !_payLocked && !_isProcessingPayment;

    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(
            color:
                isDarkMode ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isButtonEnabled
                ? () => unawaited(_openPaymentCheckout(cart))
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isButtonEnabled
                  ? const Color(0xFF3B82F6)
                  : Colors.grey.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: isButtonEnabled ? 4 : 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.payment,
                  size: 22,
                  color: isButtonEnabled ? Colors.white : Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _payLocked
                        ? 'Payment locked'
                        : 'Pay ${_formatCurrency(safeTotal)}',
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color:
                          isButtonEnabled ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPaymentCheckout(List<CartItem> cart) async {
    HapticFeedbackUtil.light();
    if (!mounted) return;
    final taxRate = ref.read(currentTaxRateProvider);
    final fin = _computeCartFinancialTotals(cart, taxRate);
    final cashController = TextEditingController(
      text: _cashAmount > 0 ? _cashAmount.toStringAsFixed(2) : '',
    );
    final useSheet = _useCompactPaymentPresentation(context);

    try {
      if (useSheet) {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (modalContext) => _buildPaymentCheckoutSurface(
            modalContext,
            cart,
            cashController,
            useSheet: true,
            safeOriginalSubtotal: fin.safeOriginalSubtotal,
            itemDiscountTotal: fin.itemDiscountTotal,
            safeOrderDiscount: fin.safeOrderDiscount,
            taxRate: taxRate,
            safeTaxAmount: fin.safeTaxAmount,
            safeTotal: fin.safeTotal,
          ),
        );
      } else {
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (dialogContext) {
            final screenSize = MediaQuery.sizeOf(dialogContext);
            final maxH = screenSize.height * 0.92;
            // 520px read as cramped on 13-15" laptop screens (typically
            // 1280-1920 logical px wide) — scale with the window instead of
            // a fixed width, capped so it never sprawls on very wide monitors.
            final maxW = (screenSize.width * 0.55).clamp(560.0, 920.0);
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 32,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
                child: _buildPaymentCheckoutSurface(
                  dialogContext,
                  cart,
                  cashController,
                  useSheet: false,
                  safeOriginalSubtotal: fin.safeOriginalSubtotal,
                  itemDiscountTotal: fin.itemDiscountTotal,
                  safeOrderDiscount: fin.safeOrderDiscount,
                  taxRate: taxRate,
                  safeTaxAmount: fin.safeTaxAmount,
                  safeTotal: fin.safeTotal,
                ),
              ),
            );
          },
        );
      }
    } finally {
      cashController.dispose();
    }
  }

  Widget _buildPaymentCheckoutSurface(
    BuildContext context,
    List<CartItem> cart,
    TextEditingController cashController, {
    required bool useSheet,
    required double safeOriginalSubtotal,
    required double itemDiscountTotal,
    required double safeOrderDiscount,
    required double taxRate,
    required double safeTaxAmount,
    required double safeTotal,
  }) {
    final currency = ref.read(currentCurrencyProvider);
    return StatefulBuilder(
      builder: (context, setSheetState) {
        final isDark = ref.watch(isDarkModeProvider);
        final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
        final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
        final handleColor =
            isDark ? const Color(0xFF374151) : Colors.grey.shade300;
        final totalsSection = Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.summarize,
                    size: 18,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF475569),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'pos.totals_and_actions'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _remarks.isNotEmpty
                        ? 'Edit remarks: $_remarks'
                        : 'Add remarks',
                    icon: Icon(
                      _remarks.isNotEmpty
                          ? Icons.comment
                          : Icons.comment_outlined,
                      size: 20,
                      color: _remarks.isNotEmpty
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFF64748B),
                    ),
                    onPressed: () async {
                      await _showRemarksDialog();
                      setSheetState(() {});
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildTotalsBreakdownCard(
                safeOriginalSubtotal: safeOriginalSubtotal,
                itemDiscountTotal: itemDiscountTotal,
                safeOrderDiscount: safeOrderDiscount,
                taxRate: taxRate,
                safeTaxAmount: safeTaxAmount,
                safeTotal: safeTotal,
              ),
            ],
          ),
        );

        final paymentOptionsSection = Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Selection
              Text(
                'pos.customer_section_label'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<CustomerModel?>(
                          value: _selectedCustomer,
                          hint: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.directions_walk,
                                  color: Color(0xFF10B981),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text('pos.walk_in'.tr()),
                              ],
                            ),
                          ),
                          isExpanded: true,
                          items: [
                            DropdownMenuItem<CustomerModel?>(
                              value: null,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.directions_walk,
                                      color: Color(0xFF10B981),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text('pos.walk_in'.tr()),
                                  ],
                                ),
                              ),
                            ),
                            ...ref.watch(customerNotifierProvider).when(
                                  data: (customerList) {
                                    final filteredCustomers =
                                        _filteredCustomersForCurrentMode(
                                      customerList,
                                    );
                                    return filteredCustomers
                                        .map(
                                          (customer) =>
                                              DropdownMenuItem<CustomerModel?>(
                                            value: customer,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.person,
                                                    color: Color(0xFF3B82F6),
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      customer.name,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList();
                                  },
                                  loading: () => [],
                                  error: (_, __) => [],
                                ),
                          ],
                          onChanged: (CustomerModel? customer) {
                            setSheetState(() {
                              _applyCustomerSelection(customer);
                            });
                            if (mounted) setState(() {});
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Add customer',
                    child: OutlinedButton.icon(
                      onPressed: () => unawaited(context.push('/add-customer')),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Add'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(88, 50),
                        foregroundColor: AppColors.primaryColor,
                        side: const BorderSide(color: AppColors.borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Sale Date
              Text(
                'Sale Date',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _selectedSaleDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null && mounted) {
                    setSheetState(() {
                      _selectedSaleDate = pickedDate;
                    });
                  }
                },
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Color(0xFF3B82F6),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd MMM yyyy').format(_selectedSaleDate),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Customer info if selected
              if (_selectedCustomer != null) ...[
                _buildCheckoutCustomerCreditSummary(_selectedCustomer!),
                const SizedBox(height: 16),
                // Payment method selection for customers
                Row(
                  children: [
                    Expanded(
                      child: PaymentButtonWidget(
                        type: 'cash',
                        icon: Icons.money,
                        label: 'pos.pay_cash'.tr(),
                        isSelected: _paymentType == 'cash',
                        onTap: () {
                          setSheetState(() {
                            _paymentType = 'cash';
                            _cashAmount = 0;
                            cashController.clear();
                          });
                        },
                        isCompact: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PaymentButtonWidget(
                        type: 'card',
                        icon: Icons.credit_card,
                        label: 'pos.pay_card'.tr(),
                        isSelected: _paymentType == 'card',
                        onTap: () {
                          setSheetState(() {
                            _paymentType = 'card';
                            _cashAmount = 0;
                            cashController.clear();
                          });
                        },
                        isCompact: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PaymentButtonWidget(
                        type: 'credit',
                        icon: Icons.receipt_long,
                        label: 'pos.pay_khata'.tr(),
                        isSelected: _paymentType == 'credit',
                        onTap: () {
                          setSheetState(() {
                            _paymentType = 'credit';
                            _cashAmount = 0;
                            cashController.clear();
                          });
                        },
                        isCompact: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ] else ...[
                // Walk-in customer - Cash only
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'pos.walk_in_cash_only'.tr(),
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Cash amount input for cash payments
              if (_selectedCustomer == null || _paymentType == 'cash') ...[
                // Quick Amount Buttons
                _buildQuickPaymentButtons(
                  safeTotal,
                  false,
                  setSheetState,
                  cashController,
                ),
                const SizedBox(height: 12),
                // Cash Received Input
                TextField(
                  controller: cashController,
                  focusNode: _cashAmountFocusNode,
                  decoration: InputDecoration(
                    labelText: 'pos.cash_received'.tr(),
                    hintText: 'pos.hint_payment_amount'.tr(),
                    prefixText: '${currency.symbol} ',
                    prefixIcon: const Icon(Icons.money),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [DecimalInputFormatter(maxDecimalPlaces: 2)],
                  onChanged: (value) {
                    setSheetState(() {
                      _cashAmount = double.tryParse(value) ?? 0.0;
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Change Preview
                Builder(
                  builder: (context) {
                    final cashReceived =
                        _cashAmount.isNaN || _cashAmount.isInfinite
                            ? 0.0
                            : _cashAmount;
                    if (cashReceived > safeTotal && safeTotal > 0) {
                      final change = cashReceived - safeTotal;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.money,
                                  size: 20,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Change',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _formatCurrency(change),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else if (cashReceived > 0 && cashReceived < safeTotal) {
                      final due = safeTotal - cashReceived;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFFEF4444,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Due',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                            Text(
                              _formatCurrency(due),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 16),
              ],
              // Process Payment Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: Builder(
                  builder: (context) {
                    bool isButtonEnabled =
                        cart.isNotEmpty && !_payLocked && !_isProcessingPayment;

                    if (_selectedCustomer == null && _paymentType == 'cash') {
                      final safeCash =
                          _cashAmount.isNaN || _cashAmount.isInfinite
                              ? 0.0
                              : _cashAmount;
                      isButtonEnabled = isButtonEnabled && safeCash > 0;
                    } else if (_selectedCustomer != null &&
                        _paymentType == 'cash') {
                      final safeCash =
                          _cashAmount.isNaN || _cashAmount.isInfinite
                              ? 0.0
                              : _cashAmount;
                      isButtonEnabled = isButtonEnabled && safeCash > 0;
                    }

                    return ElevatedButton(
                      onPressed: isButtonEnabled
                          ? () {
                              Navigator.pop(context);
                              _processPayment();
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isButtonEnabled
                            ? const Color(0xFF3B82F6)
                            : Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: isButtonEnabled ? 2 : 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.payment,
                            size: 22,
                            color: isButtonEnabled
                                ? Colors.white
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Process Payment',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isButtonEnabled
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );

        final wideDesktopPayment =
            !useSheet && MediaQuery.sizeOf(context).width >= 900;
        return Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: useSheet
                ? const BorderRadius.vertical(top: Radius.circular(20))
                : BorderRadius.circular(20),
            boxShadow: useSheet
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (useSheet)
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: handleColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    if (!useSheet) const SizedBox(height: 8),
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF3B82F6,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.payment,
                              color: Color(0xFF3B82F6),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Payment',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (cart.isNotEmpty)
                                  Text(
                                    '${cart.length} ${cart.length == 1 ? 'item' : 'items'}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    if (wideDesktopPayment)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: totalsSection),
                            Container(
                              width: 1,
                              color: isDark
                                  ? const Color(0xFF374151)
                                  : const Color(0xFFE2E8F0),
                            ),
                            Expanded(flex: 6, child: paymentOptionsSection),
                          ],
                        ),
                      )
                    else ...[
                      totalsSection,
                      paymentOptionsSection,
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckoutCustomerCreditSummary(CustomerModel customer) {
    final creditLimit = customer.creditLimit;
    final outstanding = customer.totalDue > 0 ? customer.totalDue : 0.0;
    final advance = customer.totalDue < 0 ? -customer.totalDue : 0.0;
    final available = creditLimit > 0
        ? (creditLimit - outstanding).clamp(0.0, double.infinity)
        : 0.0;

    Widget metric(
      String label,
      double amount,
      IconData icon,
      Color color,
    ) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      _formatCurrency(amount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final balanceLabel = advance > 0 ? 'Advance' : 'Outstanding';
    final balanceAmount = advance > 0 ? advance : outstanding;
    final balanceColor = advance > 0 ? AppColors.success : AppColors.error;
    final balanceIcon =
        advance > 0 ? Icons.savings_outlined : Icons.warning_amber_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.hoverColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_circle_outlined,
                color: AppColors.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              metric(
                'Credit limit',
                creditLimit,
                Icons.credit_card_outlined,
                AppColors.primaryColor,
              ),
              const SizedBox(width: 8),
              metric(
                balanceLabel,
                balanceAmount,
                balanceIcon,
                balanceColor,
              ),
              if (creditLimit > 0) ...[
                const SizedBox(width: 8),
                metric(
                  'Available',
                  available,
                  Icons.account_balance_wallet_outlined,
                  AppColors.success,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedMobileCustomerSection(
    AsyncValue<List<CustomerModel>> customers,
  ) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final surfaceColor = isDarkMode ? AppColors.surfaceDark : Colors.white;
    final bgColor =
        isDarkMode ? const Color(0xFF23272F) : const Color(0xFFF8FAFC);
    final borderColor =
        isDarkMode ? const Color(0xFF374151) : const Color(0xFFE2E8F0);
    final textPrimary = isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final textSecondary =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: EdgeInsets.all(_isMobileHandset ? 8 : 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          // Header row for collapse/expand on mobile handsets
          if (_isMobileHandset)
            InkWell(
              onTap: () {
                if (!mounted) return;
                setState(() {
                  _isMobileCustomerSectionExpanded =
                      !_isMobileCustomerSectionExpanded;
                });
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Customer & Date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  Icon(
                    _isMobileCustomerSectionExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: textSecondary,
                  ),
                ],
              ),
            ),
          if (_isMobileHandset) const SizedBox(height: 8),
          if (!_isMobileHandset || _isMobileCustomerSectionExpanded)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildSaleDateSelector(
                    backgroundColor: surfaceColor,
                    borderColor: borderColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 7,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: _buildMobileCustomerDropdown(customers),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _selectSaleDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedSaleDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select Sale Date',
      cancelText: 'Cancel',
      confirmText: 'Set',
    );
    if (pickedDate != null && mounted) {
      setState(() {
        _selectedSaleDate = pickedDate;
      });
    }
  }

  Widget _buildSaleDateSelector({
    Color? backgroundColor,
    Color? borderColor,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
  }) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final bgColor =
        backgroundColor ?? (isDarkMode ? AppColors.surfaceDark : Colors.white);
    final border = borderColor ??
        (isDarkMode ? const Color(0xFF374151) : const Color(0xFFE2E8F0));
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1E293B);

    final formattedDate = DateFormat('dd MMM yyyy').format(_selectedSaleDate);
    double horizontalPadding = 8;
    if (padding is EdgeInsets) {
      horizontalPadding = padding.left;
    } else if (padding is EdgeInsetsDirectional) {
      horizontalPadding = padding.start;
    }
    return GestureDetector(
      onTap: _selectSaleDate,
      child: Container(
        margin: margin,
        height: 32,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Icon(
              Icons.calendar_today,
              size: 14,
              color: Color(0xFF3B82F6),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedMobileCartItems(List<CartItem> cart) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final emptyStateBg =
        isDarkMode ? const Color(0xFF23272F) : const Color(0xFFF8FAFC);
    final emptyStateIcon =
        isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    final emptyStateText = isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final emptyStateSubtext =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: emptyStateBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 48,
                color: emptyStateIcon,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: emptyStateText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add products to get started',
              style: TextStyle(fontSize: 14, color: emptyStateSubtext),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 0,
        bottom: 100, // Space for sticky payment button
      ),
      itemCount: cart.length,
      itemBuilder: (context, index) {
        final item = cart[index];
        return _buildEnhancedMobileCartItem(item, index);
      },
    );
  }

  Widget _buildEnhancedMobileCartItem(CartItem item, int index) {
    // Handle bundles differently
    if (item.isBundle && item.bundle != null) {
      return _buildBundleCartItem(item, isCompact: true);
    }

    if (item.product == null) return const SizedBox.shrink();

    final isDarkMode = ref.watch(isDarkModeProvider);
    final surfaceColor = isDarkMode ? AppColors.surfaceDark : Colors.white;
    final borderColor =
        isDarkMode ? const Color(0xFF374151) : const Color(0xFFE2E8F0);
    final textPrimary = isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final textSecondary =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final quantityController = _getCartQuantityController(item);
    final quantityFocus = _getCartQuantityFocusNode(item);
    final priceController = _getCartPriceController(item);
    final priceFocus = _getCartPriceFocusNode(item);

    return Dismissible(
      key: Key('cart_item_${item.product!.id ?? 'unknown_${item.hashCode}'}'),
      direction: DismissDirection.horizontal,
      background: Container(
        margin: EdgeInsets.only(bottom: _isMobileHandset ? 8 : 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: 20),
            child: Icon(Icons.delete, color: Colors.white, size: 24),
          ),
        ),
      ),
      secondaryBackground: Container(
        margin: EdgeInsets.only(bottom: _isMobileHandset ? 8 : 12),
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 20),
            child: Icon(Icons.edit, color: Colors.white, size: 24),
          ),
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Delete action
          HapticFeedbackUtil.medium();
          return true;
        } else if (direction == DismissDirection.startToEnd) {
          // Edit action - show quick edit dialog
          HapticFeedbackUtil.light();
          _showQuickEditCartItemDialog(item);
          return false; // Don't dismiss, just show dialog
        }
        return false;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart &&
            item.product?.id != null) {
          final productId = item.product!.id!;
          ref.read(cartProvider.notifier).removeProduct(productId);
          // Clear custom price and discount when item is removed
          setState(() {
            _itemPrices.remove(productId.toString());
            _itemDiscounts.remove(productId.toString());
          });
          // Haptic feedback
          HapticFeedbackUtil.success();
          if (mounted) {
            AppSnackBar.show(
              context,
              SnackBar(
                content: Text(
                  'Removed ${_safeGetProductName(item.product!)} from cart',
                ),
                backgroundColor: const Color(0xFFEF4444),
                duration: const Duration(seconds: 1),
              ),
            );
          }
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: _isMobileHandset ? 8 : 12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(_isMobileHandset ? 10 : 12),
          child: Row(
            children: [
              // Product Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getProductIcon(item.product!.category),
                  color: const Color(0xFF3B82F6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _safeGetProductName(item.product!),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatCurrency(_safeGetItemPrice(item))} × ${_formatQuantityDisplay(item.quantity)}',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
              // Quantity Controls
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (item.product?.id == null) return;
                      if (item.quantity > 1) {
                        ref.read(cartProvider.notifier).updateQuantity(
                              item.product!.id!,
                              item.quantity - 1,
                            );
                        _triggerHapticFeedback(HapticFeedbackType.light);
                      } else {
                        final productId = item.product!.id!;
                        ref
                            .read(cartProvider.notifier)
                            .removeProduct(productId);
                        // Clear custom price and discount when item is removed
                        setState(() {
                          _itemPrices.remove(productId.toString());
                          _itemDiscounts.remove(productId.toString());
                        });
                        _triggerHapticFeedback(HapticFeedbackType.medium);
                      }
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.remove,
                        size: 16,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 56,
                    child: TextField(
                      controller: quantityController,
                      focusNode: quantityFocus,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: isDarkMode
                            ? AppColors.backgroundDark
                            : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 6,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: Color(0xFF3B82F6),
                            width: 1.5,
                          ),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        DecimalInputFormatter(maxDecimalPlaces: 2),
                      ],
                      onEditingComplete: () =>
                          _applyQuantitySubmission(item, quantityController),
                      onSubmitted: (_) =>
                          _applyQuantitySubmission(item, quantityController),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      if (item.product?.id == null) return;
                      ref
                          .read(cartProvider.notifier)
                          .updateQuantity(item.product!.id!, item.quantity + 1);
                      _triggerHapticFeedback(HapticFeedbackType.light);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 16,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Subtotal
              Text(
                _formatCurrency(item.subtotal),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF059669),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedMobileCartSummary(List<CartItem> cart) {
    if (cart.isEmpty) return const SizedBox.shrink();

    final isDarkMode = ref.watch(isDarkModeProvider);
    final surfaceColor = isDarkMode ? AppColors.surfaceDark : Colors.white;
    final borderColor =
        isDarkMode ? const Color(0xFF374151) : const Color(0xFFE2E8F0);
    final textPrimary = isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final textSecondary =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    // Calculate subtotal using _safeGetItemPrice to account for payment type
    final subtotal = cart.fold(0.0, (sum, item) {
      try {
        final basePrice = _safeGetItemPrice(item);
        final safePrice =
            basePrice.isNaN || basePrice.isInfinite ? 0.0 : basePrice;
        final safeQuantity = item.quantity.isNaN || item.quantity.isInfinite
            ? 0.0
            : item.quantity;
        final itemSubtotal = safePrice * safeQuantity;
        final safeItemSubtotal =
            itemSubtotal.isNaN || itemSubtotal.isInfinite ? 0.0 : itemSubtotal;
        return sum + safeItemSubtotal;
      } catch (e) {
        return sum;
      }
    });
    final discountAmount = _discountType == 'percentage'
        ? (subtotal * _discount / 100)
        : _discount;
    final subtotalAfterDiscount = subtotal - discountAmount;

    // Get tax rate
    final taxRate = ref.watch(currentTaxRateProvider);
    final taxAmount = TaxCalculator.calculateTax(
      subtotalAfterDiscount,
      taxRate,
    );
    final total = subtotalAfterDiscount + taxAmount;
    const bool compactSummary = true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Compact Summary - Single line with key info only
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'misc.pos_total'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              Text(
                _formatCurrency(total),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF059669),
                ),
              ),
            ],
          ),
          // Tax details remain available in the payment dialog. Keep only a
          // compact discount note on the POS screen when one is applied.
          if (discountAmount > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Disc: -${_formatCurrency(discountAmount)}',
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileCustomerSection(
    AsyncValue<List<CustomerModel>> customers,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildSaleDateSelector(),
          const SizedBox(height: 8),
          // Compact Customer Selection
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<CustomerModel?>(
                value: _selectedCustomer,
                hint: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_add,
                        color: Color(0xFF10B981),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'pos.walk_in'.tr(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                isExpanded: true,
                items: [
                  DropdownMenuItem<CustomerModel?>(
                    value: null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person_add,
                            color: Color(0xFF10B981),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'pos.walk_in'.tr(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ...customers.when(
                    data: (customerList) {
                      final filteredCustomers =
                          _filteredCustomersForCurrentMode(customerList);
                      return filteredCustomers
                          .map(
                            (customer) => DropdownMenuItem<CustomerModel?>(
                              value: customer,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      color: Color(0xFF3B82F6),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        customer.name,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E293B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList();
                    },
                    loading: () => [],
                    error: (_, __) => [],
                  ),
                ],
                onChanged: (CustomerModel? customer) {
                  if (mounted) {
                    setState(() {
                      _applyCustomerSelection(customer);
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactOrderTypeButton(
    String type,
    IconData icon,
    String label,
  ) {
    final isSelected = _orderType == type;
    return GestureDetector(
      onTap: () {
        if (mounted) {
          setState(() => _orderType = type);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
              size: 14,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCartItems(List<CartItem> cart) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final emptyStateBg =
        isDarkMode ? const Color(0xFF23272F) : const Color(0xFFF1F5F9);
    final emptyStateIcon =
        isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    final emptyStateText = isDarkMode ? Colors.white : const Color(0xFF475569);
    final emptyStateSubtext =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8);

    if (cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: emptyStateBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 48,
                color: emptyStateIcon,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: emptyStateText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add products to get started',
              style: TextStyle(fontSize: 14, color: emptyStateSubtext),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: cart.length,
      itemBuilder: (context, index) {
        final item = cart[index];
        return _buildMobileCartItem(item);
      },
    );
  }

  Widget _buildMobileCartItem(CartItem item) {
    // Professional: Use safe helper methods
    final itemDiscount = _safeGetItemDiscount(item);
    final basePrice = _safeGetItemPrice(item);
    final finalSubtotal = _safeCalculateSubtotal(item);
    final isDarkMode = ref.watch(isDarkModeProvider);
    final surfaceColor = isDarkMode ? AppColors.surfaceDark : Colors.white;
    final borderColor =
        isDarkMode ? const Color(0xFF374151) : const Color(0xFFE2E8F0);
    final textPrimary = isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final textSecondary =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final bgColor =
        isDarkMode ? const Color(0xFF23272F) : const Color(0xFFF8FAFC);

    // Additional safety check - handle bundles
    if (item.isBundle && item.bundle != null) {
      return _buildBundleCartItem(item, isCompact: false);
    }

    if (item.product == null || item.product!.id == null) {
      return const SizedBox.shrink();
    }

    final priceController = _getCartPriceController(item);
    final priceFocus = _getCartPriceFocusNode(item);
    final quantityController = _getCartQuantityController(item);
    final quantityFocus = _getCartQuantityFocusNode(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _safeGetProductName(item.product!),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (itemDiscount > 0) ...[
                            Text(
                              _formatCurrency(basePrice),
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 10,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 80,
                                  child: TextField(
                                    controller: priceController,
                                    focusNode: priceFocus,
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      filled: true,
                                      fillColor: isDarkMode
                                          ? AppColors.backgroundDark
                                          : Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 4,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: BorderSide(
                                          color: borderColor,
                                          width: 1,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: BorderSide(
                                          color: borderColor,
                                          width: 1,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF10B981),
                                          width: 1.5,
                                        ),
                                      ),
                                      prefixText: ref
                                              .read(currentCurrencyProvider)
                                              .symbol +
                                          ' ',
                                      prefixStyle: const TextStyle(
                                        color: Color(0xFF10B981),
                                        fontSize: 10,
                                      ),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    inputFormatters: [
                                      DecimalInputFormatter(
                                        maxDecimalPlaces: 2,
                                      ),
                                    ],
                                    onEditingComplete: () =>
                                        _applyPriceSubmission(
                                      item,
                                      priceController,
                                    ),
                                    onSubmitted: (_) => _applyPriceSubmission(
                                      item,
                                      priceController,
                                    ),
                                  ),
                                ),
                                if (itemDiscount == 0)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Text(
                                      'each',
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Color(0xFFEF4444),
                      ),
                      onPressed: item.product?.id == null
                          ? null
                          : () => _removeFromCart(item.product!.id!),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.remove,
                            size: 14,
                            color: textSecondary,
                          ),
                          onPressed: () => _updateQuantity(
                            item.product!.id!,
                            item.quantity - 1,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        SizedBox(
                          width: 52,
                          child: TextField(
                            controller: quantityController,
                            focusNode: quantityFocus,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: isDarkMode
                                  ? AppColors.backgroundDark
                                  : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 6,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                  color: Color(0xFF3B82F6),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              DecimalInputFormatter(maxDecimalPlaces: 2),
                            ],
                            onEditingComplete: () => _applyQuantitySubmission(
                              item,
                              quantityController,
                            ),
                            onSubmitted: (_) => _applyQuantitySubmission(
                              item,
                              quantityController,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add, size: 14, color: textSecondary),
                          onPressed: () => _updateQuantity(
                            item.product!.id!,
                            item.quantity + 1,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (itemDiscount > 0) ...[
                      Text(
                        _formatCurrency(item.subtotal),
                        style: TextStyle(
                          fontSize: 10,
                          color: textSecondary,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      Text(
                        _formatCurrency(finalSubtotal),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ] else
                      Text(
                        _formatCurrency(item.subtotal),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF059669),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCartSummary(List<CartItem> cart) {
    // Calculate subtotal with item discounts
    final subtotal = cart.fold(0.0, (sum, item) {
      if (item.isBundle && item.bundle != null) {
        final safePrice =
            item.bundle!.price.isNaN || item.bundle!.price.isInfinite
                ? 0.0
                : item.bundle!.price;
        final safeQuantity = item.quantity.isNaN || item.quantity.isInfinite
            ? 0.0
            : item.quantity;
        return sum + (safePrice * safeQuantity);
      }
      if (item.product == null) return sum;
      final productId = item.product!.id?.toString() ?? '';
      final itemDiscount = _itemDiscounts[productId] ?? 0.0;
      // Use _safeGetItemPrice to account for payment type (retail credit vs cash)
      final customPrice = _itemPrices[productId] ?? _safeGetItemPrice(item);
      final discountedPrice = customPrice - itemDiscount;
      final safeQuantity =
          item.quantity.isNaN || item.quantity.isInfinite ? 0.0 : item.quantity;
      return sum + (discountedPrice * safeQuantity);
    });

    // Calculate original subtotal (without item discounts) using _safeGetItemPrice
    final originalSubtotal = cart.fold(0.0, (sum, item) {
      try {
        final basePrice = _safeGetItemPrice(item);
        final safePrice =
            basePrice.isNaN || basePrice.isInfinite ? 0.0 : basePrice;
        final safeQuantity = item.quantity.isNaN || item.quantity.isInfinite
            ? 0.0
            : item.quantity;
        return sum + (safePrice * safeQuantity);
      } catch (e) {
        return sum;
      }
    });

    // Calculate item discount total
    final itemDiscountTotal = originalSubtotal - subtotal;

    // Calculate order-level discount
    final orderDiscountAmount = _discountType == 'percentage'
        ? (subtotal * _discount / 100)
        : _discount;

    final total = subtotal - orderDiscountAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'misc.pos_subtotal'.tr(),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              Text(
                _formatCurrency(originalSubtotal),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
            ],
          ),
          if (itemDiscountTotal > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'misc.pos_item_discounts'.tr(),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                ),
                Text(
                  '-${_formatCurrency(itemDiscountTotal)}',
                  style: const TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
          if (orderDiscountAmount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'misc.pos_order_discount'.tr(),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                ),
                Text(
                  '-${_formatCurrency(orderDiscountAmount)}',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'misc.pos_total'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatCurrency(total),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Action Buttons Row
          if (cart.length > 1) ...[
            OutlinedButton.icon(
              onPressed: () {
                final currency = ref.read(currentCurrencyProvider);
                _showSplitBillDialog(cart, total, currency);
              },
              icon: const Icon(Icons.call_split, size: 18),
              label: Text('pos.split_bill'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3B82F6),
                side: const BorderSide(color: Color(0xFF3B82F6)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Pay Button
          Builder(
            builder: (context) {
              // Calculate if button should be enabled
              bool isButtonEnabled =
                  cart.isNotEmpty && !_payLocked && !_isProcessingPayment;

              // If total is negative, enable button without requiring cash payment
              final safeTotal = total.isNaN || total.isInfinite ? 0.0 : total;
              if (safeTotal < 0) {
                // Negative total: enable button without cash requirement
                isButtonEnabled = isButtonEnabled;
              }
              // For cash payments (walk-in customers), require valid cash amount
              else if (_selectedCustomer == null &&
                  _paymentType == 'cash' &&
                  !_isSplitPayment) {
                final safeCash = _cashAmount.isNaN || _cashAmount.isInfinite
                    ? 0.0
                    : _cashAmount;
                isButtonEnabled = isButtonEnabled && safeCash > 0;
              }
              // For split payments, require at least some payment
              else if (_isSplitPayment) {
                final safeCash = _cashAmount.isNaN || _cashAmount.isInfinite
                    ? 0.0
                    : _cashAmount;
                final safeCard = _cardAmount.isNaN || _cardAmount.isInfinite
                    ? 0.0
                    : _cardAmount;
                isButtonEnabled =
                    isButtonEnabled && (safeCash > 0 || safeCard > 0);
              }

              return SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isButtonEnabled ? _processPayment : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: isButtonEnabled
                        ? const Color(0xFF3B82F6)
                        : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: isButtonEnabled ? 2 : 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.payment,
                        size: 20,
                        color: isButtonEnabled
                            ? Colors.white
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pay ${_formatCurrency(total)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isButtonEnabled
                              ? Colors.white
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModernProductsSection(AsyncValue<List<ProductModel>> products) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkNavy.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with Search and Categories
          _buildProductsHeader(),
          // Products Grid
          Expanded(child: _buildProductsGrid(products)),
        ],
      ),
    );
  }

  Widget _buildProductsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
              decoration: InputDecoration(
                hintText: 'pos.hint_search_products_full'.tr(),
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Container(
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.search,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Hide barcode icon on Windows (automatic scanning enabled)
                    if (!Platform.isWindows)
                      GestureDetector(
                        onTap: () => _openBarcodeScanner(),
                        onLongPress: () => _showBarcodeInputDialog(),
                        child: const Icon(
                          Icons.qr_code_scanner,
                          color: Color(0xFF3B82F6),
                          size: 20,
                        ),
                      ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: Color(0xFF64748B),
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _searchFocusNode.unfocus();
                          setState(() {});
                        },
                      ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF3B82F6),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: (value) {
                if (mounted) {
                  setState(() {});
                }
              },
              onSubmitted: (value) {
                unawaited(_onProductSearchSubmitted(value));
              },
            ),
          ),
          const SizedBox(height: 10),
          // Category Filter
          CategoryFilterWidget(
            selectedCategory: _selectedCategory,
            onCategorySelected: (category) {
              setState(() {
                _selectedCategory = category;
                _showBundles = category == 'bundles';
              });
              _triggerCategoryLoading();
            },
            isMobile: false,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final categoriesAsync = ref.watch(categoryNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Categories',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildCategoryChip(
                'all',
                'All Products',
                Icons.apps,
                const Color(0xFF3B82F6),
              ),
              const SizedBox(width: 8),
              _buildCategoryChip(
                'bundles',
                'Bundles',
                Icons.inventory_2,
                Colors.orange,
              ),
              const SizedBox(width: 8),
              ...categoriesAsync.when(
                data: (categories) => categories.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildCategoryChip(
                      category.name.toLowerCase(),
                      category.name,
                      _getIconFromString(category.icon),
                      Color(int.parse('FF${category.color}', radix: 16)),
                    ),
                  );
                }).toList(),
                loading: () => [
                  const SizedBox(
                    width: 100,
                    height: 50,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (_, __) => [
                  SizedBox(
                    width: 100,
                    height: 50,
                    child: Center(child: Text('pos.error_categories'.tr())),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(
    String category,
    String label,
    IconData icon,
    Color categoryColor,
  ) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () {
        if (!mounted || _selectedCategory == category) return;
        setState(() {
          _selectedCategory = category;
          _showBundles = category == 'bundles';
        });
        if (category != 'bundles') {
          _triggerCategoryLoading();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? categoryColor : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? categoryColor : const Color(0xFFE2E8F0),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: categoryColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : categoryColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsGrid(AsyncValue<List<ProductModel>> products) {
    // Show bundles if bundles category is selected
    if (_showBundles) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: _buildBundlesGrid(),
      );
    }

    if (_isCategoryLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: _buildCategoryLoadingState(),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: products.when(
        data: (productList) {
          final filteredProducts = _filterProducts(productList);

          if (filteredProducts.isEmpty) {
            return _buildEmptyState();
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              // Max extent keeps cards readable and naturally changes the
              // column count as the cart/sidebar width changes.
              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 176,
                  childAspectRatio: .92,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  if (index >= filteredProducts.length) {
                    return const SizedBox.shrink();
                  }

                  final product = filteredProducts[index];
                  final currency = ref.watch(currentCurrencyProvider);

                  // Safety check for product validity
                  if (product.id == null || product.name.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return EnhancedProductCard(
                    product: product,
                    currency: currency,
                    onTap: () => _addToCart(product),
                    showStockWarning: true,
                  );
                },
              );
            },
          );
        },
        loading: () => _buildLoadingState(),
        error: (error, stack) {
          // Log error for debugging
          debugPrint('Error loading products in POS: $error');
          debugPrint('Stack trace: $stack');
          return _buildErrorState(error);
        },
      ),
    );
  }

  List<ProductModel> _filterProducts(List<ProductModel> products) {
    final searchTerm = _searchController.text.trim().toLowerCase();
    final categoryFilter = _selectedCategory;

    final result = products.where((product) {
      // Business Rule: Only show items where Retail Cash (price) >= Cost Price (cost)
      final validPrice = product.price >= product.cost;

      final matchesSearch = _productNameMatchesQuery(product, searchTerm);

      final matchesCategory = categoryFilter == 'all' ||
          product.category.toLowerCase() == categoryFilter;

      return validPrice && matchesSearch && matchesCategory;
    }).toList();
    return result;
  }

  bool _productNameMatchesQuery(ProductModel product, String query) {
    if (query.isEmpty) return true;
    final normalizedName = product.name.toLowerCase();
    final barcode = product.barcode?.toLowerCase() ?? '';
    final tokens =
        query.split(RegExp(r'\s+')).where((token) => token.isNotEmpty).toList();
    if (tokens.isEmpty) {
      return true;
    }
    bool tokenMatches(String token) {
      if (normalizedName.contains(token)) return true;
      if (barcode.isNotEmpty && barcode.contains(token)) return true;
      return false;
    }

    return tokens.every(tokenMatches);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.search_off,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No products found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search or category filter',
            style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
          ),
          SizedBox(height: 16),
          Text(
            'Loading products...',
            style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 46,
            height: 46,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              strokeWidth: 4,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Loading products…',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Switching category view',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.error_outline,
              size: 48,
              color: Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Error loading products',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModernProductCard(ProductModel product) {
    final isLowStock = product.stock <= 5;
    final isOutOfStock = product.stock <= 0;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _addToCart(product);
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              _showProductDetailsDialog(product);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Image/Icon
                      Expanded(
                        flex: 1,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              _getProductIcon(product.category),
                              size: 20,
                              color: const Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                      ),
                      // Product Info
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatCurrency(product.price),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF059669),
                                ),
                              ),
                              // Stock info
                              ...[
                                const Spacer(),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Stock: ${product.stock.toInt()}',
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: isLowStock
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (isOutOfStock)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'OUT',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Low Stock Indicator
                  if (isLowStock && !isOutOfStock)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LOW',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showProductDetailsDialog(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'pos.detail_category'.tr(
                namedArgs: {'category': product.category},
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'pos.detail_price'.tr(
                namedArgs: {'price': _formatCurrency(product.price)},
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'pos.detail_stock'.tr(
                namedArgs: {
                  'stock': product.stock.toStringAsFixed(0),
                  'unit': product.unit,
                },
              ),
            ),
            if (product.description != null) ...[
              const SizedBox(height: 8),
              Text(
                'pos.detail_description'.tr(
                  namedArgs: {'description': product.description ?? ''},
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('common.close'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _addToCart(product);
            },
            child: Text('pos.add_to_cart'.tr()),
          ),
        ],
      ),
    );
  }

  IconData _getProductIcon(String category) {
    switch (category.toLowerCase()) {
      case 'electronics':
        return Icons.devices;
      case 'clothing':
        return Icons.checkroom;
      case 'food':
        return Icons.restaurant;
      case 'books':
        return Icons.menu_book;
      case 'beauty':
        return Icons.face;
      default:
        return Icons.inventory;
    }
  }

  IconData _getIconFromString(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'devices':
        return Icons.devices;
      case 'checkroom':
        return Icons.checkroom;
      case 'restaurant':
        return Icons.restaurant;
      case 'menu_book':
        return Icons.menu_book;
      case 'face':
        return Icons.face;
      case 'home':
        return Icons.home;
      case 'sports':
        return Icons.sports;
      case 'cake':
        return Icons.cake;
      case 'local_drink':
        return Icons.local_drink;
      case 'eco':
        return Icons.eco;
      case 'medication':
        return Icons.medication;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'medical_services':
        return Icons.medical_services;
      case 'category':
      default:
        return Icons.category;
    }
  }

  Widget _buildModernCartSection(
    List<CartItem> cart,
  ) {
    final isCompactMode = cart.length >= 6;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkNavy.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: _buildModernCartItems(cart, isCompactMode: isCompactMode),
          ),
          _buildModernCartSummary(cart, isCompactMode: isCompactMode),
        ],
      ),
    );
  }

  Widget _buildModernCustomerSection(
    AsyncValue<List<CustomerModel>> customers,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(children: [_buildSaleDateAndCustomerRow(customers)]),
          ),
          CustomerInfoWidget(
            customer: _selectedCustomer,
            isCompact: false,
            onExpandToggle: () {
              setState(() {
                _isCreditSectionExpanded = !_isCreditSectionExpanded;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSaleDateAndCustomerRow(
    AsyncValue<List<CustomerModel>> customers,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final saleDateWidget = _buildSaleDateSelector(
          backgroundColor: AppColors.hoverColor,
          borderColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        );
        return Column(
          children: [
            Row(
              children: [
                const Text(
                  'Customer',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                SizedBox(width: 132, child: saleDateWidget),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      onTap: () => _showCustomerSearchDialog(customers),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _selectedCustomer == null
                                  ? Icons.directions_walk
                                  : Icons.person_outline,
                              size: 19,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _selectedCustomer?.name ?? 'Walk-in Customer',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.expand_more,
                              size: 18,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Add customer',
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/add-customer'),
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('Add'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(88, 48),
                      foregroundColor: AppColors.textPrimary,
                      backgroundColor: AppColors.hoverColor,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchableCustomerDropdown(
    AsyncValue<List<CustomerModel>> customers,
  ) {
    return customers.when(
      data: (customerList) {
        final filteredCustomers = _filteredCustomersForCurrentMode(
          customerList,
        );
        return DropdownButtonFormField<CustomerModel?>(
          value: _selectedCustomer,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
          ),
          hint: Row(
            children: [
              Icon(Icons.directions_walk, size: 12, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'pos.walk_in_short'.tr(),
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          icon: const Icon(
            Icons.arrow_drop_down,
            size: 16,
            color: Color(0xFF64748B),
          ),
          isExpanded: true,
          items: [
            DropdownMenuItem<CustomerModel?>(
              value: null,
              child: Row(
                children: [
                  Icon(
                    Icons.directions_walk,
                    size: 12,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'pos.walk_in'.tr(),
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            ...filteredCustomers
                .map(
                  (customer) => DropdownMenuItem<CustomerModel?>(
                    value: customer,
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              customer.name[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            customer.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ],
          onChanged: (CustomerModel? customer) {
            if (mounted) {
              setState(() {
                _applyCustomerSelection(customer);
              });
            }
          },
          onTap: () {
            // Show search dialog when dropdown is tapped
            _showCustomerSearchDialog(customers);
          },
        );
      },
      loading: () => Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              'pos.customers_loading'.tr(),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      error: (_, __) => Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          'pos.customers_error'.tr(),
          style: const TextStyle(fontSize: 12, color: Colors.red),
        ),
      ),
    );
  }

  void _showCustomerSearchDialog(AsyncValue<List<CustomerModel>> customers) {
    String searchQuery = '';
    List<CustomerModel> filteredCustomers = [];
    final searchFocusNode = FocusNode();
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Helper function to filter customers
            void updateFilteredCustomers() {
              customers.whenData((customerList) {
                final baseList = _filteredCustomersForCurrentMode(customerList);
                setDialogState(() {
                  if (searchQuery.isEmpty) {
                    filteredCustomers = baseList;
                  } else {
                    filteredCustomers = baseList.where((customer) {
                      return customer.name.toLowerCase().contains(
                                searchQuery,
                              ) ||
                          customer.phone.toLowerCase().contains(searchQuery);
                    }).toList();
                  }
                });
              });
            }

            // Helper function to select first customer or walk-in
            void selectFirstOrWalkIn() {
              // Get latest filtered customers based on current search query
              customers.whenData((customerList) {
                final baseList = _filteredCustomersForCurrentMode(customerList);
                List<CustomerModel> currentFiltered = [];
                if (searchQuery.isEmpty) {
                  currentFiltered = baseList;
                } else {
                  currentFiltered = baseList.where((customer) {
                    return customer.name.toLowerCase().contains(searchQuery) ||
                        customer.phone.toLowerCase().contains(searchQuery);
                  }).toList();
                }

                if (currentFiltered.isNotEmpty) {
                  // Select first matching customer
                  setState(() {
                    _applyCustomerSelection(currentFiltered[0]);
                  });
                  Navigator.pop(context);
                } else {
                  // No match found, select walk-in
                  setState(() {
                    _applyCustomerSelection(null);
                  });
                  Navigator.pop(context);
                }
              });
            }

            final screenWidth = MediaQuery.of(context).size.width;
            // Narrow phones need most of the width; wider windows/tablets
            // keep the previous half-width look instead of stretching edge to edge.
            final dialogWidth =
                screenWidth < 600 ? screenWidth * 0.92 : screenWidth * 0.5;
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: dialogWidth,
                height: MediaQuery.of(context).size.height * 0.7,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(
                          Icons.search,
                          color: Color(0xFF10B981),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Select Customer',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            searchFocusNode.dispose();
                            searchController.dispose();
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Search Field
                    TextField(
                      controller: searchController,
                      focusNode: searchFocusNode,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'pos.hint_search_customer'.tr(),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF10B981),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      textInputAction: TextInputAction.search,
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value.toLowerCase();
                          updateFilteredCustomers();
                        });
                      },
                      onSubmitted: (value) {
                        // When Enter is pressed, select first matching customer
                        if (value.isNotEmpty) {
                          // Update search query and filter customers
                          searchQuery = value.toLowerCase();
                          updateFilteredCustomers();

                          // Select first customer immediately
                          selectFirstOrWalkIn();
                          searchFocusNode.dispose();
                          searchController.dispose();
                        } else {
                          // Empty search, select walk-in
                          setState(() {
                            _applyCustomerSelection(null);
                          });
                          searchFocusNode.dispose();
                          searchController.dispose();
                          Navigator.pop(context);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    // Customer List
                    Expanded(
                      child: customers.when(
                        data: (customerList) {
                          final baseList = _filteredCustomersForCurrentMode(
                            customerList,
                          );
                          // Update filtered customers if needed
                          if (searchQuery.isEmpty) {
                            filteredCustomers = baseList;
                          } else {
                            filteredCustomers = baseList.where((customer) {
                              return customer.name.toLowerCase().contains(
                                        searchQuery,
                                      ) ||
                                  customer.phone.toLowerCase().contains(
                                        searchQuery,
                                      );
                            }).toList();
                          }

                          if (filteredCustomers.isEmpty) {
                            return Center(
                              child: Text('pos.no_customers_found'.tr()),
                            );
                          }

                          return ListView.builder(
                            itemCount: filteredCustomers.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                // Walk-in Customer option
                                return ListTile(
                                  leading: const Icon(
                                    Icons.directions_walk,
                                    color: Color(0xFF64748B),
                                  ),
                                  title: Text('pos.walk_in'.tr()),
                                  onTap: () {
                                    setState(() {
                                      _applyCustomerSelection(null);
                                    });
                                    Navigator.pop(context);
                                  },
                                );
                              }

                              final customer = filteredCustomers[index - 1];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.1),
                                  child: Text(
                                    customer.name[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(customer.name),
                                subtitle: customer.phone.isNotEmpty
                                    ? Text(customer.phone)
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _applyCustomerSelection(customer);
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            },
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stack) => Center(
                          child: Text(
                            'pos.err_with_message'.tr(
                              namedArgs: {'error': '$error'},
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMobileCustomerDropdown(
    AsyncValue<List<CustomerModel>> customers,
  ) {
    return DropdownButtonHideUnderline(
      child: customers.when(
        data: (customerList) {
          final filteredCustomers = _filteredCustomersForCurrentMode(
            customerList,
          );
          return DropdownButton<CustomerModel?>(
            value: _selectedCustomer,
            hint: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_walk,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'pos.walk_in'.tr(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
            isExpanded: true,
            items: [
              DropdownMenuItem<CustomerModel?>(
                value: null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.directions_walk,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'pos.walk_in'.tr(),
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ),
              ...filteredCustomers.map((customer) {
                return DropdownMenuItem<CustomerModel?>(
                  value: customer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 16,
                          color: Color(0xFF3B82F6),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            customer.name,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
            onChanged: (customer) {
              if (mounted) {
                setState(() => _applyCustomerSelection(customer));
              }
            },
          );
        },
        loading: () =>
            DropdownButton<CustomerModel?>(items: const [], onChanged: null),
        error: (_, __) =>
            DropdownButton<CustomerModel?>(items: const [], onChanged: null),
      ),
    );
  }

  Widget _buildSegmentedButton(String type, IconData icon, String label) {
    final isSelected = _orderType == type;
    return GestureDetector(
      onTap: () {
        if (mounted) {
          setState(() => _orderType = type);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 12,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernCartItems(
    List<CartItem> cart, {
    bool isCompactMode = false,
  }) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final emptyStateIcon =
        isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    final emptyStateText = isDarkMode ? Colors.white : const Color(0xFF475569);
    final emptyStateSubtext =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8);

    if (cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 44, color: emptyStateIcon),
            const SizedBox(height: 10),
            Text(
              'Cart is empty',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: emptyStateText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add items from the product area',
              style: TextStyle(fontSize: 13, color: emptyStateSubtext),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          height: 26,
          // Match the ListView (8) + item row (6) horizontal insets so every
          // header sits directly above its corresponding cart value.
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: const BoxDecoration(
            color: AppColors.backgroundLight,
            border: Border(
              top: BorderSide(color: AppColors.borderColor),
              bottom: BorderSide(color: AppColors.borderColor),
            ),
          ),
          child: const Row(
            children: [
              Expanded(child: Text('NAME', style: _compactCartHeaderStyle)),
              SizedBox(width: _cartNameColumnGap),
              SizedBox(
                width: _cartPriceColumnWidth,
                child: Text(
                  'PRICE',
                  textAlign: TextAlign.right,
                  style: _compactCartHeaderStyle,
                ),
              ),
              SizedBox(width: _cartColumnGap),
              SizedBox(
                width: _cartQuantityColumnWidth,
                child: Text(
                  'QTY',
                  textAlign: TextAlign.center,
                  style: _compactCartHeaderStyle,
                ),
              ),
              SizedBox(width: _cartColumnGap),
              SizedBox(
                width: _cartTotalColumnWidth,
                child: Text(
                  'AMOUNT',
                  textAlign: TextAlign.right,
                  style: _compactCartHeaderStyle,
                ),
              ),
              SizedBox(width: _cartRemoveColumnWidth),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
            itemCount: cart.length,
            itemBuilder: (context, index) {
              final item = cart[index];
              return KeyedSubtree(
                key: ValueKey(_cartItemKey(item)),
                child: _buildModernCartItem(item, isCompact: isCompactMode),
              );
            },
          ),
        ),
      ],
    );
  }

  static const TextStyle _compactCartHeaderStyle = TextStyle(
    fontSize: 9,
    height: 1,
    letterSpacing: .5,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
  );

  static const double _cartNameColumnGap = 5;
  static const double _cartColumnGap = 6;
  static const double _cartPriceColumnWidth = 66;
  static const double _cartQuantityColumnWidth = 64;
  static const double _cartTotalColumnWidth = 72;
  static const double _cartRemoveColumnWidth = 32;

  Widget _buildCustomerCreditInfo({bool isCompact = false}) {
    final customer = _selectedCustomer;
    if (customer == null) {
      return const SizedBox.shrink();
    }

    final creditLimit = customer.creditLimit;
    final outstanding = customer.totalDue > 0 ? customer.totalDue : 0.0;
    final advance = customer.totalDue < 0 ? -customer.totalDue : 0.0;
    final hasLimit = creditLimit > 0;
    final hasBalance = outstanding > 0 || advance > 0;

    // Default state: Show only if outstanding > 0, otherwise collapse completely
    // If compact mode, always show collapsed
    final shouldShowByDefault = outstanding > 0;
    final isCollapsed = isCompact || !_isCreditSectionExpanded;

    // If no credit info and no outstanding, don't show at all
    if (!hasLimit && !hasBalance) {
      return const SizedBox.shrink();
    }

    double available = 0.0;
    if (hasLimit) {
      available = creditLimit - outstanding;
      if (available < 0) {
        available = 0;
      }
    }

    // Compact horizontal bar (collapsed state)
    if (isCollapsed) {
      // Only show if outstanding > 0 or if explicitly expanded
      if (!shouldShowByDefault && !_isCreditSectionExpanded) {
        return const SizedBox.shrink();
      }

      return Container(
        width: double.infinity,
        margin: EdgeInsets.only(top: isCompact ? 4 : 6),
        padding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: isCompact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: outstanding > 0
              ? const Color(0xFFFEF2F2)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: outstanding > 0
                ? const Color(0xFFFECACA)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: isCompact
              ? null
              : () {
                  setState(() {
                    _isCreditSectionExpanded = !_isCreditSectionExpanded;
                  });
                },
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              // Customer name
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: isCompact ? 14 : 16,
                      color: const Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        customer.name,
                        style: TextStyle(
                          fontSize: isCompact ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Credit Limit (if exists)
              if (hasLimit) ...[
                Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.credit_card,
                          size: isCompact ? 12 : 14,
                          color: const Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Credit: ${_formatCurrency(creditLimit)}',
                            style: TextStyle(
                              fontSize: isCompact ? 10 : 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF2563EB),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              // Outstanding (if > 0)
              if (outstanding > 0) ...[
                Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: isCompact ? 12 : 14,
                          color: const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Outstanding: ${_formatCurrency(outstanding)}',
                            style: TextStyle(
                              fontSize: isCompact ? 10 : 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFDC2626),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              // Expand/Collapse button (only in non-compact mode)
              if (!isCompact) ...[
                const SizedBox(width: 8),
                Icon(
                  _isCreditSectionExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 18,
                  color: const Color(0xFF6B7280),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Expanded state with full details
    TextStyle labelStyle(Color color) => TextStyle(
          fontSize: isCompact ? 9.5 : 10.5,
          fontWeight: FontWeight.w500,
          color: color.withOpacity(0.75),
        );

    TextStyle valueStyle(Color color) => TextStyle(
          fontSize: isCompact ? 11.5 : 12.5,
          fontWeight: FontWeight.w700,
          color: color,
        );

    Widget buildStat(String label, String value, Color color, IconData icon) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: 8,
          vertical: isCompact ? 4 : 5,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: isCompact ? 12 : 13.5, color: color),
            const SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: labelStyle(color)),
                Text(value, style: valueStyle(color)),
              ],
            ),
          ],
        ),
      );
    }

    final stats = <Widget>[];
    if (hasLimit) {
      stats.add(
        buildStat(
          'Credit Limit',
          _formatCurrency(creditLimit),
          const Color(0xFF2563EB),
          Icons.credit_card,
        ),
      );
      stats.add(
        buildStat(
          'Available',
          _formatCurrency(available),
          const Color(0xFF059669),
          Icons.trending_up,
        ),
      );
    }
    if (outstanding > 0) {
      stats.add(
        buildStat(
          'Outstanding',
          _formatCurrency(outstanding),
          const Color(0xFFDC2626),
          Icons.warning_amber_rounded,
        ),
      );
    }
    if (advance > 0) {
      stats.add(
        buildStat(
          'Advance',
          _formatCurrency(advance),
          const Color(0xFF7C3AED),
          Icons.savings,
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: isCompact ? 6 : 8),
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: isCompact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  size: isCompact ? 14 : 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Customer Credit',
                  style: TextStyle(
                    fontSize: isCompact ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ),
              if (!isCompact)
                IconButton(
                  icon: Icon(
                    _isCreditSectionExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                    color: const Color(0xFF6B7280),
                  ),
                  onPressed: () {
                    setState(() {
                      _isCreditSectionExpanded = !_isCreditSectionExpanded;
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: _isCreditSectionExpanded ? 'Collapse' : 'Expand',
                ),
              if (hasLimit && outstanding > creditLimit)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: isCompact ? 3 : 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.priority_high,
                        size: 12,
                        color: Color(0xFFB91C1C),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Limit exceeded',
                        style: TextStyle(
                          fontSize: isCompact ? 10 : 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFB91C1C),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: isCompact ? 6 : 7, children: stats),
        ],
      ),
    );
  }

  Widget _buildModernCartItem(CartItem item, {required bool isCompact}) {
    // Handle bundles differently
    if (item.isBundle && item.bundle != null) {
      return _buildBundleCartItem(item, isCompact: isCompact);
    }

    // Professional: Use safe helper methods
    if (item.product == null || item.product!.id == null) {
      return const SizedBox.shrink();
    }
    final stock = item.product!.stock;
    final isWeightBased = _isWeightBasedUnit(item.product!.unit);
    // Only check stock for positive quantities; negative quantities represent returns/adjustments
    final qtyExceedsStock = item.quantity > 0 && item.quantity > stock;
    final unitLower = (item.product!.unit).toString().toLowerCase();
    final isPieceUnit = unitLower == 'pcs' || unitLower == 'pc';

    final amountController = _getCartAmountController(item);
    final amountFocus = _getCartAmountFocusNode(item);
    final priceController = _getCartPriceController(item);
    final priceFocus = _getCartPriceFocusNode(item);
    final quantityController = _getCartQuantityController(item);
    final quantityFocus = _getCartQuantityFocusNode(item);
    final currency = ref.read(currentCurrencyProvider);

    // Calculate sale price from controller for real-time updates
    // Remove currency symbol and any non-numeric characters except decimal point
    final priceText = priceController.text
        .trim()
        .replaceAll(currency.symbol, '')
        .trim()
        .replaceAll(RegExp(r'[^\d.]'), '');
    final currentSalePrice =
        (priceText.isNotEmpty && double.tryParse(priceText) != null)
            ? double.parse(priceText)
            : (_itemPrices[_cartItemKey(item)] ?? _safeGetItemPrice(item));

    // Calculate quantity from controller for real-time updates
    // Remove unit suffix and any non-numeric characters except decimal point
    final qtyText = quantityController.text
        .trim()
        .replaceAll(item.product!.unit, '')
        .trim()
        .replaceAll(RegExp(r'[^\d.]'), '');
    final currentQuantity =
        (qtyText.isNotEmpty && double.tryParse(qtyText) != null)
            ? double.parse(qtyText)
            : item.quantity;

    // Calculate total price in real-time
    final safeSalePrice = currentSalePrice.isNaN || currentSalePrice.isInfinite
        ? 0.0
        : currentSalePrice;
    final safeQuantity = currentQuantity.isNaN || currentQuantity.isInfinite
        ? 0.0
        : currentQuantity;
    final totalPrice = safeSalePrice * safeQuantity;
    final bool isDesktop = MediaQuery.of(context).size.width >= 1024;

    final double sectionSpacing = isCompact ? 4 : 10;
    final double fieldSpacing = isCompact ? 4 : 8;
    final EdgeInsets fieldPadding = EdgeInsets.symmetric(
      horizontal: 6,
      vertical: isCompact ? 4 : 6,
    );

    if (isDesktop && MediaQuery.sizeOf(context).width.isFinite) {
      return _buildSingleLineDesktopCartItem(
        item: item,
        qtyExceedsStock: qtyExceedsStock,
        priceController: priceController,
        priceFocus: priceFocus,
        quantityController: quantityController,
        quantityFocus: quantityFocus,
        amountController: amountController,
        amountFocus: amountFocus,
        isWeightBased: isWeightBased,
        totalPrice: totalPrice,
      );
    }

    if (isDesktop) {
      // Legacy desktop layout retained as a fallback while older integrations
      // are migrated to the consistent cart-card renderer above.
      return Container(
        margin: EdgeInsets.only(bottom: isCompact ? 6 : 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: qtyExceedsStock
                ? const Color(0xFFEF4444)
                : const Color(0xFFE2E8F0),
            width: qtyExceedsStock ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Product Name (max width 150)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  _safeGetProductName(item.product!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              SizedBox(width: fieldSpacing),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stock',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: fieldPadding,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '${_formatQuantityDisplay(stock)} ${item.product!.unit}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: fieldSpacing),
              // Amount (optional for weight-based etc.)
              if (!isPieceUnit)
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sale amount',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: amountController,
                        focusNode: amountFocus,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: fieldPadding,
                          prefixText: '${currency.symbol} ',
                          prefixStyle: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFF3B82F6),
                              width: 1.5,
                            ),
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          DecimalInputFormatter(maxDecimalPlaces: 2),
                        ],
                        onChanged: (value) {
                          _storeCartAmountFromText(item, value);
                          if (isWeightBased) {
                            _handleAmountInputForWeightBased(item, value);
                          }
                        },
                        onEditingComplete: () =>
                            _applyAmountSubmission(item, amountController),
                        onSubmitted: (_) =>
                            _applyAmountSubmission(item, amountController),
                      ),
                    ],
                  ),
                ),
              if (!isPieceUnit) SizedBox(width: fieldSpacing),
              // Sale Amount (Price)
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sale Price',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: priceController,
                      focusNode: priceFocus,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3B82F6),
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: fieldPadding,
                        prefixText: '${currency.symbol} ',
                        prefixStyle: const TextStyle(
                          color: Color(0xFF3B82F6),
                          fontSize: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: Color(0xFF3B82F6),
                            width: 1.5,
                          ),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        DecimalInputFormatter(maxDecimalPlaces: 2),
                      ],
                      onChanged: (value) {
                        final key = _cartItemKey(item);
                        final priceTextSanitized = value
                            .trim()
                            .replaceAll(currency.symbol, '')
                            .trim()
                            .replaceAll(RegExp(r'[^\d.]'), '');
                        final parsed = double.tryParse(priceTextSanitized);
                        if (parsed != null && parsed.isFinite && parsed > 0) {
                          setState(() {
                            _itemPrices[key] = parsed;
                          });
                        }
                      },
                      onEditingComplete: () =>
                          _applyPriceSubmission(item, priceController),
                      onSubmitted: (_) =>
                          _applyPriceSubmission(item, priceController),
                    ),
                  ],
                ),
              ),
              SizedBox(width: fieldSpacing),
              // Quantity
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'pos.qty_short'.tr(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: quantityController,
                      focusNode: quantityFocus,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: qtyExceedsStock
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF1E293B),
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: fieldPadding,
                        suffixText: item.product!.unit,
                        suffixStyle: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: qtyExceedsStock
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: qtyExceedsStock
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: qtyExceedsStock
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF3B82F6),
                            width: 1.5,
                          ),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      inputFormatters: [
                        DecimalInputFormatter(
                          maxDecimalPlaces: 2,
                          allowNegative: true,
                        ),
                      ],
                      onChanged: (value) {
                        // Allow negative values - remove unit and parse with sign
                        final qtyTextSanitized = value
                            .trim()
                            .replaceAll(item.product!.unit, '')
                            .trim()
                            .replaceAll(RegExp(r'[^\d.\-]'), '');
                        final parsed = double.tryParse(qtyTextSanitized);
                        if (parsed != null && parsed.isFinite && parsed != 0) {
                          double finalQty;
                          if (parsed > 0) {
                            // Positive: validate against stock
                            final stockCap = item.product!.stock;
                            finalQty = parsed > stockCap ? stockCap : parsed;
                          } else {
                            // Negative: allow it (represents returns/adjustments)
                            finalQty = parsed;
                          }
                          if ((finalQty - item.quantity).abs() > 0.001) {
                            setState(() {
                              _updateQuantity(item.product!.id!, finalQty);
                            });
                          }
                        }
                      },
                      onEditingComplete: () =>
                          _applyQuantitySubmission(item, quantityController),
                      onSubmitted: (_) =>
                          _applyQuantitySubmission(item, quantityController),
                    ),
                  ],
                ),
              ),
              SizedBox(width: fieldSpacing),
              // Total Price
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'misc.pos_total'.tr(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: fieldPadding,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: Text(
                        _formatCurrency(totalPrice),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: fieldSpacing),
              // Delete icon
              IconButton(
                onPressed: () => _removeFromCart(item.product!.id!),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFEF4444),
                  size: 18,
                ),
                tooltip: 'common.remove'.tr(),
                splashRadius: 18,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 6 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: qtyExceedsStock
              ? const Color(0xFFEF4444)
              : const Color(0xFFE2E8F0),
          width: qtyExceedsStock ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 8 : 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name
            Text(
              _safeGetProductName(item.product!),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isCompact ? 13 : 14,
                color: Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: sectionSpacing),
            // Fields row: Stock, Amount (hidden for PCS/PC), Sale Price, Qty, Total Price
            Row(
              children: [
                // Stock (non-editable)
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stock',
                        style: TextStyle(
                          fontSize: isCompact ? 8.5 : 10,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: isCompact ? 2 : 4),
                      Container(
                        padding: fieldPadding,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          '${_formatQuantityDisplay(stock)} ${item.product!.unit}',
                          style: TextStyle(
                            fontSize: isCompact ? 10.5 : 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isPieceUnit) ...[
                  SizedBox(width: fieldSpacing),
                  // Amount (editable - cost/purchase price)
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sale amount',
                          style: TextStyle(
                            fontSize: isCompact ? 8.5 : 10,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: isCompact ? 2 : 4),
                        TextField(
                          controller: amountController,
                          focusNode: amountFocus,
                          style: TextStyle(
                            fontSize: isCompact ? 11 : 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: fieldPadding,
                            prefixText: '${currency.symbol} ',
                            prefixStyle: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: isCompact ? 9.5 : 11,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                color: Color(0xFF3B82F6),
                                width: 1.5,
                              ),
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            DecimalInputFormatter(maxDecimalPlaces: 2),
                          ],
                          onChanged: (value) {
                            _storeCartAmountFromText(item, value);
                            if (isWeightBased) {
                              _handleAmountInputForWeightBased(item, value);
                            }
                          },
                          onEditingComplete: () =>
                              _applyAmountSubmission(item, amountController),
                          onSubmitted: (_) =>
                              _applyAmountSubmission(item, amountController),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(width: fieldSpacing),
                // Sale Price (editable)
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sale Price',
                        style: TextStyle(
                          fontSize: isCompact ? 8.5 : 10,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: isCompact ? 2 : 4),
                      TextField(
                        controller: priceController,
                        focusNode: priceFocus,
                        style: TextStyle(
                          fontSize: isCompact ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3B82F6),
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: fieldPadding,
                          prefixText: '${currency.symbol} ',
                          prefixStyle: TextStyle(
                            color: Color(0xFF3B82F6),
                            fontSize: isCompact ? 9.5 : 11,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFF3B82F6),
                              width: 1.5,
                            ),
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          DecimalInputFormatter(maxDecimalPlaces: 2),
                        ],
                        onChanged: (value) {
                          // Update _itemPrices immediately for real-time calculation
                          final key = _cartItemKey(item);
                          // Remove currency symbol and parse
                          final priceText = value
                              .trim()
                              .replaceAll(currency.symbol, '')
                              .trim()
                              .replaceAll(RegExp(r'[^\d.]'), '');
                          final parsed = double.tryParse(priceText);
                          if (parsed != null && parsed.isFinite && parsed > 0) {
                            setState(() {
                              _itemPrices[key] = parsed;
                            });
                          }
                        },
                        onEditingComplete: () =>
                            _applyPriceSubmission(item, priceController),
                        onSubmitted: (_) =>
                            _applyPriceSubmission(item, priceController),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: fieldSpacing),
                // Qty (editable)
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'pos.qty_short'.tr(),
                        style: TextStyle(
                          fontSize: isCompact ? 8.5 : 10,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: isCompact ? 2 : 4),
                      TextField(
                        controller: quantityController,
                        focusNode: quantityFocus,
                        style: TextStyle(
                          fontSize: isCompact ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          color: qtyExceedsStock
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF1E293B),
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: fieldPadding,
                          suffixText: item.product!.unit,
                          suffixStyle: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                              color: qtyExceedsStock
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                              color: qtyExceedsStock
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                              color: qtyExceedsStock
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF3B82F6),
                              width: 1.5,
                            ),
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        inputFormatters: [
                          DecimalInputFormatter(
                            maxDecimalPlaces: 2,
                            allowNegative: true,
                          ),
                        ],
                        onChanged: (value) {
                          // Update quantity immediately for real-time calculation
                          // Allow negative values - remove unit and parse with sign
                          final qtyText = value
                              .trim()
                              .replaceAll(item.product!.unit, '')
                              .trim()
                              .replaceAll(RegExp(r'[^\d.\-]'), '');
                          final parsed = double.tryParse(qtyText);
                          if (parsed != null &&
                              parsed.isFinite &&
                              parsed != 0) {
                            double finalQty;
                            if (parsed > 0) {
                              // Positive: validate against stock
                              final stock = item.product!.stock;
                              finalQty = parsed > stock ? stock : parsed;
                            } else {
                              // Negative: allow it (represents returns/adjustments)
                              finalQty = parsed;
                            }
                            // Only update if different to avoid infinite loops
                            if ((finalQty - item.quantity).abs() > 0.001) {
                              setState(() {
                                _updateQuantity(item.product!.id!, finalQty);
                              });
                            }
                          }
                        },
                        onEditingComplete: () =>
                            _applyQuantitySubmission(item, quantityController),
                        onSubmitted: (_) =>
                            _applyQuantitySubmission(item, quantityController),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: fieldSpacing),
                // Total Price (auto-calculated)
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Price',
                        style: TextStyle(
                          fontSize: isCompact ? 8.5 : 10,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: isCompact ? 2 : 4),
                      Container(
                        padding: fieldPadding,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF10B981)),
                        ),
                        child: Text(
                          _formatCurrency(totalPrice),
                          style: TextStyle(
                            fontSize: isCompact ? 11 : 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: fieldSpacing),
                // Item removal only. Discounts are applied once at cart level.
                IconButton(
                  onPressed: () => _removeFromCart(item.product!.id!),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFEF4444),
                    size: 18,
                  ),
                  tooltip: 'common.remove'.tr(),
                  splashRadius: 18,
                ),
              ],
            ),
            // Show custom price info if applied
            if (item.product != null &&
                _itemPrices.containsKey(item.product!.id.toString())) ...[
              SizedBox(height: isCompact ? 3 : 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Custom Price',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSingleLineDesktopCartItem({
    required CartItem item,
    required bool qtyExceedsStock,
    required TextEditingController priceController,
    required FocusNode priceFocus,
    required TextEditingController quantityController,
    required FocusNode quantityFocus,
    required TextEditingController amountController,
    required FocusNode amountFocus,
    required bool isWeightBased,
    required double totalPrice,
  }) {
    final product = item.product!;
    final productId = product.id!;
    const border = AppColors.borderColor;

    InputDecoration compactInputDecoration() => InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          filled: true,
          fillColor: AppColors.backgroundLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide:
                const BorderSide(color: AppColors.primaryColor, width: 1.5),
          ),
        );

    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: qtyExceedsStock ? const Color(0xFFFCA5A5) : border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: _safeGetProductName(product),
              child: Text(
                _safeGetProductName(product),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: _cartNameColumnGap),
          SizedBox(
            width: _cartPriceColumnWidth,
            height: 32,
            child: Tooltip(
              message: 'Edit unit price',
              child: TextField(
                controller: priceController,
                focusNode: priceFocus,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryColor,
                ),
                decoration: compactInputDecoration(),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                inputFormatters: [DecimalInputFormatter(maxDecimalPlaces: 2)],
                onTap: () {
                  priceController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: priceController.text.length,
                  );
                },
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  if (parsed != null && parsed.isFinite && parsed > 0) {
                    setState(() => _itemPrices[_cartItemKey(item)] = parsed);
                  }
                },
                onEditingComplete: () =>
                    _applyPriceSubmission(item, priceController),
                onSubmitted: (_) {
                  _applyPriceSubmission(item, priceController);
                  quantityFocus.requestFocus();
                },
              ),
            ),
          ),
          const SizedBox(width: _cartColumnGap),
          Container(
            width: _cartQuantityColumnWidth,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: qtyExceedsStock ? const Color(0xFFFCA5A5) : border,
              ),
            ),
            child: TextField(
              controller: quantityController,
              focusNode: quantityFocus,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: qtyExceedsStock
                    ? AppColors.errorColor
                    : AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [
                DecimalInputFormatter(maxDecimalPlaces: 6, allowNegative: true),
              ],
              onEditingComplete: () =>
                  _applyQuantitySubmission(item, quantityController),
              onSubmitted: (_) =>
                  _applyQuantitySubmission(item, quantityController),
            ),
          ),
          const SizedBox(width: _cartColumnGap),
          SizedBox(
            width: _cartTotalColumnWidth,
            height: 32,
            child: isWeightBased
                ? Tooltip(
                    message: 'Enter sale amount to calculate quantity',
                    child: TextField(
                      controller: amountController,
                      focusNode: amountFocus,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryColor,
                      ),
                      decoration: compactInputDecoration(),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        DecimalInputFormatter(maxDecimalPlaces: 2),
                      ],
                      onChanged: (value) {
                        _storeCartAmountFromText(item, value);
                        _handleAmountInputForWeightBased(item, value);
                      },
                      onEditingComplete: () =>
                          _applyAmountSubmission(item, amountController),
                      onSubmitted: (_) =>
                          _applyAmountSubmission(item, amountController),
                    ),
                  )
                : Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _formatCurrency(MoneyMath.round(totalPrice)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
          ),
          SizedBox(
            width: _cartRemoveColumnWidth,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'Remove item',
              onPressed: () => _removeFromCart(productId),
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.errorColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsistentDesktopCartItem({
    required CartItem item,
    required bool isCompact,
    required bool qtyExceedsStock,
    required bool isWeightBased,
    required TextEditingController amountController,
    required FocusNode amountFocus,
    required TextEditingController priceController,
    required FocusNode priceFocus,
    required TextEditingController quantityController,
    required FocusNode quantityFocus,
    required Currency currency,
    required double totalPrice,
  }) {
    final product = item.product!;
    final productId = product.id!;
    const border = Color(0xFFDCE3EC);
    const labelColor = Color(0xFF64748B);
    const primaryText = Color(0xFF0F172A);

    InputDecoration fieldDecoration({String? prefix, String? suffix}) {
      return InputDecoration(
        isDense: true,
        prefixText: prefix,
        suffixText: suffix,
        prefixStyle: const TextStyle(fontSize: 11, color: labelColor),
        suffixStyle: const TextStyle(fontSize: 10, color: labelColor),
        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
      );
    }

    Widget labeledField(String label, Widget child, {int flex = 1}) {
      return Expanded(
        flex: flex,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                height: 1,
                letterSpacing: .45,
                fontWeight: FontWeight.w700,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(height: 38, child: child),
          ],
        ),
      );
    }

    void changeQuantity(double delta) {
      final candidate = item.quantity + delta;
      if (candidate <= 0) return;
      final next = candidate > product.stock ? product.stock : candidate;
      _updateQuantity(productId, next);
      final text = _formatQuantityDisplay(next);
      quantityController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }

    Widget quantityButton(IconData icon, double delta, String tooltip) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            onTap: () => changeQuantity(delta),
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              width: 34,
              height: 38,
              child: Icon(icon, size: 17, color: const Color(0xFF2563EB)),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 7 : 9),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: qtyExceedsStock ? const Color(0xFFFCA5A5) : border,
          width: qtyExceedsStock ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 7,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _safeGetProductName(product),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: primaryText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: qtyExceedsStock
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Stock ${_formatQuantityDisplay(product.stock)} ${product.unit}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color:
                        qtyExceedsStock ? const Color(0xFFDC2626) : labelColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Remove item',
                  onPressed: () => _removeFromCart(productId),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isWeightBased) ...[
                labeledField(
                  'Amount',
                  TextField(
                    controller: amountController,
                    focusNode: amountFocus,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: fieldDecoration(prefix: '${currency.symbol} '),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      DecimalInputFormatter(maxDecimalPlaces: 2),
                    ],
                    onChanged: (value) {
                      _storeCartAmountFromText(item, value);
                      _handleAmountInputForWeightBased(item, value);
                    },
                    onEditingComplete: () =>
                        _applyAmountSubmission(item, amountController),
                    onSubmitted: (_) =>
                        _applyAmountSubmission(item, amountController),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              labeledField(
                'Price',
                TextField(
                  controller: priceController,
                  focusNode: priceFocus,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: fieldDecoration(prefix: '${currency.symbol} '),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [DecimalInputFormatter(maxDecimalPlaces: 2)],
                  onChanged: (value) {
                    final parsed = double.tryParse(value);
                    if (parsed != null && parsed.isFinite && parsed > 0) {
                      setState(() => _itemPrices[_cartItemKey(item)] = parsed);
                    }
                  },
                  onEditingComplete: () =>
                      _applyPriceSubmission(item, priceController),
                  onSubmitted: (_) =>
                      _applyPriceSubmission(item, priceController),
                ),
              ),
              const SizedBox(width: 8),
              labeledField(
                'Quantity',
                Row(
                  children: [
                    quantityButton(
                      Icons.remove_rounded,
                      isWeightBased ? -0.001 : -1,
                      'Decrease quantity',
                    ),
                    Expanded(
                      child: TextField(
                        controller: quantityController,
                        focusNode: quantityFocus,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: qtyExceedsStock
                              ? const Color(0xFFDC2626)
                              : primaryText,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                          border: InputBorder.none,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        inputFormatters: [
                          DecimalInputFormatter(
                            maxDecimalPlaces: 6,
                            allowNegative: true,
                          ),
                        ],
                        onEditingComplete: () =>
                            _applyQuantitySubmission(item, quantityController),
                        onSubmitted: (_) =>
                            _applyQuantitySubmission(item, quantityController),
                      ),
                    ),
                    quantityButton(
                      Icons.add_rounded,
                      isWeightBased ? 0.001 : 1,
                      'Increase quantity',
                    ),
                  ],
                ),
                flex: 2,
              ),
              const SizedBox(width: 8),
              labeledField(
                'Total',
                Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    _formatCurrency(MoneyMath.round(totalPrice)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF047857),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceStyleCartItem({
    required CartItem item,
    required bool isCompact,
    required bool qtyExceedsStock,
    required bool isWeightBased,
    required TextEditingController amountController,
    required FocusNode amountFocus,
    required TextEditingController priceController,
    required FocusNode priceFocus,
    required TextEditingController quantityController,
    required FocusNode quantityFocus,
    required Currency currency,
    required double totalPrice,
  }) {
    final product = item.product!;
    final productId = product.id!;
    final stockColor =
        qtyExceedsStock ? const Color(0xFFDC2626) : const Color(0xFF64748B);

    void changeQuantity(double delta) {
      final candidate = item.quantity + delta;
      if (candidate <= 0) {
        _removeFromCart(productId);
        return;
      }
      final next = candidate > product.stock ? product.stock : candidate;
      _updateQuantity(productId, next);
      final text = _formatQuantityDisplay(next);
      quantityController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }

    InputDecoration compactFieldDecoration({String? prefix, String? suffix}) {
      return InputDecoration(
        isDense: true,
        prefixText: prefix,
        suffixText: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: Color(0xFFDCE3EC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: Color(0xFFDCE3EC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
      );
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          10,
          isCompact ? 7 : 9,
          6,
          isCompact ? 7 : 9,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: qtyExceedsStock
                ? const Color(0xFFFCA5A5)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .025),
              blurRadius: 5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _safeGetProductName(product),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (isWeightBased)
                    SizedBox(
                      height: 34,
                      child: TextField(
                        controller: amountController,
                        focusNode: amountFocus,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: compactFieldDecoration(
                          prefix: '${currency.symbol} ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          DecimalInputFormatter(maxDecimalPlaces: 2),
                        ],
                        onChanged: (value) {
                          _storeCartAmountFromText(item, value);
                          _handleAmountInputForWeightBased(item, value);
                        },
                        onEditingComplete: () =>
                            _applyAmountSubmission(item, amountController),
                      ),
                    )
                  else
                    Text(
                      'Stock ${_formatQuantityDisplay(product.stock)} ${product.unit}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: stockColor,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 104,
              child: Row(
                children: [
                  _cartQuantityButton(
                    icon: Icons.remove,
                    tooltip: 'Decrease quantity',
                    onPressed: () =>
                        changeQuantity(isWeightBased ? -0.001 : -1),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        controller: quantityController,
                        focusNode: quantityFocus,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: qtyExceedsStock
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF1E293B),
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 9),
                          border: InputBorder.none,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          DecimalInputFormatter(maxDecimalPlaces: 6),
                        ],
                        onEditingComplete: () =>
                            _applyQuantitySubmission(item, quantityController),
                        onSubmitted: (_) =>
                            _applyQuantitySubmission(item, quantityController),
                      ),
                    ),
                  ),
                  _cartQuantityButton(
                    icon: Icons.add,
                    tooltip: 'Increase quantity',
                    onPressed: () => changeQuantity(isWeightBased ? 0.001 : 1),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            SizedBox(
              width: 74,
              height: 36,
              child: TextField(
                controller: priceController,
                focusNode: priceFocus,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
                decoration: compactFieldDecoration(),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [DecimalInputFormatter(maxDecimalPlaces: 2)],
                onChanged: (value) {
                  final parsed = double.tryParse(
                    value.replaceAll(RegExp(r'[^\d.]'), ''),
                  );
                  if (parsed != null && parsed > 0 && parsed.isFinite) {
                    setState(() => _itemPrices[_cartItemKey(item)] = parsed);
                  }
                },
                onEditingComplete: () =>
                    _applyPriceSubmission(item, priceController),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 82,
              child: Text(
                _formatCurrency(MoneyMath.round(totalPrice)),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            SizedBox(
              width: 36,
              height: 40,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'Remove item',
                onPressed: () => _removeFromCart(productId),
                icon: const Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartQuantityButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            width: 32,
            height: 36,
            child: Icon(icon, size: 17, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildBundleCartItem(CartItem item, {required bool isCompact}) {
    if (item.bundle == null) return const SizedBox.shrink();
    final bundle = item.bundle!;
    final currency = ref.read(currentCurrencyProvider);
    final quantityController = _getCartQuantityController(item);
    final quantityFocus = _getCartQuantityFocusNode(item);

    final qtyText = quantityController.text.trim().replaceAll(
          RegExp(r'[^\d.]'),
          '',
        );
    final currentQuantity =
        (qtyText.isNotEmpty && double.tryParse(qtyText) != null)
            ? double.parse(qtyText)
            : item.quantity;

    final safeQuantity = currentQuantity.isNaN || currentQuantity.isInfinite
        ? 0.0
        : currentQuantity;
    final safePrice =
        bundle.price.isNaN || bundle.price.isInfinite ? 0.0 : bundle.price;
    final totalPrice = safePrice * safeQuantity;
    final bool isDesktop = MediaQuery.of(context).size.width >= 1024;

    if (isDesktop) {
      return Container(
        margin: EdgeInsets.only(bottom: isCompact ? 6 : 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Bundle Name
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory_2, size: 16, color: Colors.orange),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            bundle.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${bundle.items.length} items',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Price
              Expanded(
                flex: 1,
                child: Text(
                  '${currency.symbol}${safePrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Quantity
              Expanded(
                flex: 1,
                child: TextField(
                  controller: quantityController,
                  focusNode: quantityFocus,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(
                        color: Color(0xFF3B82F6),
                        width: 1.5,
                      ),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [DecimalInputFormatter(maxDecimalPlaces: 2)],
                  onChanged: (value) {
                    final qty = double.tryParse(value) ?? 0.0;
                    if (bundle.id != null) {
                      ref
                          .read(cartProvider.notifier)
                          .updateBundleQuantity(bundle.id!, qty);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Total
              Expanded(
                flex: 1,
                child: Text(
                  '${currency.symbol}${totalPrice.toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Remove button
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Color(0xFFEF4444),
                ),
                onPressed: () {
                  if (bundle.id != null) {
                    ref.read(cartProvider.notifier).removeBundle(bundle.id!);
                  }
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      );
    } else {
      // Mobile layout
      return Container(
        margin: EdgeInsets.only(bottom: isCompact ? 6 : 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.inventory_2, size: 18, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bundle.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Color(0xFFEF4444),
                    ),
                    onPressed: () {
                      if (bundle.id != null) {
                        ref
                            .read(cartProvider.notifier)
                            .removeBundle(bundle.id!);
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Price: ${currency.symbol}${safePrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Qty:',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: quantityController,
                      focusNode: quantityFocus,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: Color(0xFF3B82F6),
                            width: 1.5,
                          ),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        DecimalInputFormatter(maxDecimalPlaces: 2),
                      ],
                      onChanged: (value) {
                        final qty = double.tryParse(value) ?? 0.0;
                        if (bundle.id != null) {
                          ref
                              .read(cartProvider.notifier)
                              .updateBundleQuantity(bundle.id!, qty);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${bundle.items.length} items',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    'Total: ${currency.symbol}${totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }

  /// Cart financial breakdown — shared by cart summary and payment modal.
  ({
    double safeOriginalSubtotal,
    double itemDiscountTotal,
    double safeOrderDiscount,
    double safeTaxAmount,
    double safeTotal,
  }) _computeCartFinancialTotals(List<CartItem> cart, double taxRate) {
    final subtotal = cart.fold(0.0, (sum, item) {
      try {
        if (item.isBundle && item.bundle != null) {
          final safePrice =
              item.bundle!.price.isNaN || item.bundle!.price.isInfinite
                  ? 0.0
                  : item.bundle!.price;
          final safeQuantity = item.quantity.isNaN || item.quantity.isInfinite
              ? 0.0
              : item.quantity;
          return MoneyMath.round(
            sum + MoneyMath.lineTotal(safePrice, safeQuantity),
          );
        }
        final productId = item.product?.id?.toString() ?? '';
        final basePrice = _itemPrices[productId] ?? _safeGetItemPrice(item);
        final safePrice =
            basePrice.isNaN || basePrice.isInfinite ? 0.0 : basePrice;
        final safeQuantity = item.quantity.isNaN || item.quantity.isInfinite
            ? 0.0
            : item.quantity;
        final itemTotal = MoneyMath.lineTotal(safePrice, safeQuantity);
        final safeItemTotal =
            itemTotal.isNaN || itemTotal.isInfinite ? 0.0 : itemTotal;

        final result = MoneyMath.round(sum + safeItemTotal);
        return result.isNaN || result.isInfinite ? sum : result;
      } catch (e) {
        return sum;
      }
    });

    final originalSubtotal = cart.fold(0.0, (sum, item) {
      try {
        final basePrice = _safeGetItemPrice(item);
        final safePrice =
            basePrice.isNaN || basePrice.isInfinite ? 0.0 : basePrice;
        final safeQuantity = item.quantity.isNaN || item.quantity.isInfinite
            ? 0.0
            : item.quantity;
        final itemSubtotal = MoneyMath.lineTotal(safePrice, safeQuantity);
        if (itemSubtotal.isNaN || itemSubtotal.isInfinite) {
          return sum;
        }
        final result = MoneyMath.round(sum + itemSubtotal);
        return result.isNaN || result.isInfinite ? sum : result;
      } catch (e) {
        return sum;
      }
    });

    final safeSubtotal = subtotal.isNaN || subtotal.isInfinite ? 0.0 : subtotal;
    final safeOriginalSubtotal =
        originalSubtotal.isNaN || originalSubtotal.isInfinite
            ? 0.0
            : originalSubtotal;
    final itemDiscountTotal = MoneyMath.round(
      safeOriginalSubtotal - safeSubtotal,
    );

    final safeDiscount =
        _discount.isNaN || _discount.isInfinite ? 0.0 : _discount;
    final orderDiscountAmount = _discountType == 'percentage'
        ? MoneyMath.percentage(safeSubtotal, safeDiscount)
        : safeDiscount;
    final finiteOrderDiscount =
        orderDiscountAmount.isNaN || orderDiscountAmount.isInfinite
            ? 0.0
            : orderDiscountAmount;
    final safeOrderDiscount = MoneyMath.round(
      finiteOrderDiscount.clamp(0.0, safeSubtotal).toDouble(),
    );
    final subtotalAfterDiscount = MoneyMath.round(
      safeSubtotal - safeOrderDiscount,
    );
    final safeSubtotalAfterDiscount =
        subtotalAfterDiscount.isNaN || subtotalAfterDiscount.isInfinite
            ? 0.0
            : subtotalAfterDiscount;

    final taxAmount = TaxCalculator.calculateTax(
      safeSubtotalAfterDiscount,
      taxRate,
    );
    final safeTaxAmount = taxAmount.isNaN || taxAmount.isInfinite
        ? 0.0
        : MoneyMath.round(taxAmount);

    final total = MoneyMath.round(safeSubtotalAfterDiscount + safeTaxAmount);
    final safeTotal = total.isNaN || total.isInfinite ? 0.0 : total;

    return (
      safeOriginalSubtotal: safeOriginalSubtotal,
      itemDiscountTotal: itemDiscountTotal,
      safeOrderDiscount: safeOrderDiscount,
      safeTaxAmount: safeTaxAmount,
      safeTotal: safeTotal,
    );
  }

  Widget _buildModernCartSummary(
    List<CartItem> cart, {
    bool isCompactMode = false,
  }) {
    final taxRate = ref.watch(currentTaxRateProvider);
    final fin = _computeCartFinancialTotals(cart, taxRate);
    final safeTotal = fin.safeTotal;
    final currency = ref.watch(currentCurrencyProvider);
    final bool compactSummary = isCompactMode || cart.length >= 6;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10,
        vertical: compactSummary ? 7 : 8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // One cart-level discount field; item-level discount controls are
          // intentionally omitted from the POS workflow.
          if (ref.watch(discountSettingsProvider).overallDiscountEnabled) ...[
            Row(
              children: [
                const SizedBox(
                  width: 76,
                  child: Text(
                    'Discount',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    focusNode: _discountFocusNode,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                      prefixText: '${currency.symbol} ',
                      prefixStyle: const TextStyle(
                        color: AppColors.primaryColor,
                        fontSize: 14,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.borderColor,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.borderColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.primaryColor,
                          width: 1.5,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      DecimalInputFormatter(maxDecimalPlaces: 2),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _discount = double.tryParse(value) ?? 0;
                        _discountType = 'fixed';
                      });
                    },
                    onSubmitted: (_) => _discountFocusNode.unfocus(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.darkNavy,
              borderRadius: BorderRadius.circular(9),
            ),
            child: _buildCartSummaryLine(
              'Grand total',
              '${currency.symbol}${safeTotal.toStringAsFixed(2)}',
              emphasize: true,
              inverse: true,
            ),
          ),
          const SizedBox(height: 6),

          _buildTotalsAndActionsPanel(cart: cart, safeTotal: safeTotal),
        ],
      ),
    );
  }

  Widget _buildCartSummaryLine(
    String label,
    String value, {
    bool emphasize = false,
    bool inverse = false,
  }) {
    final color = inverse ? Colors.white : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: emphasize ? 15 : 13,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 16 : 13,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Cart sidebar: Find / New Bill / Print / Pay (amount only on Pay button).
  /// Remarks and line breakdown stay in the payment dialog / sheet only.
  Widget _buildTotalsAndActionsPanel({
    required List<CartItem> cart,
    required double safeTotal,
  }) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final findButton = OutlinedButton.icon(
                onPressed: _showFindSaleDialog,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  foregroundColor: AppColors.primaryColor,
                  side: const BorderSide(
                    color: AppColors.primaryColor,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.search, size: 18),
                label: const Text(
                  'Find',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              );

              final newBillButton = OutlinedButton.icon(
                onPressed: _clearCart,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  foregroundColor: AppColors.errorColor,
                  side: const BorderSide(
                    color: AppColors.errorColor,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text(
                  'New Bill',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              );

              final printButton = OutlinedButton.icon(
                onPressed:
                    (cart.isEmpty || _isPrinting) ? null : _printAndRemove,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  foregroundColor: AppColors.successColor,
                  side: const BorderSide(
                    color: AppColors.successColor,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _isPrinting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print, size: 18),
                label: Text(
                  _isPrinting ? 'Printing...' : 'Print',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );

              return Row(
                children: [
                  Expanded(child: findButton),
                  const SizedBox(width: 6),
                  Expanded(child: newBillButton),
                  const SizedBox(width: 6),
                  Expanded(child: printButton),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: _buildPayButton(
                      cart,
                      safeTotal,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsBreakdownCard({
    required double safeOriginalSubtotal,
    required double itemDiscountTotal,
    required double safeOrderDiscount,
    required double taxRate,
    required double safeTaxAmount,
    required double safeTotal,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'misc.pos_subtotal'.tr(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                _formatCurrency(safeOriginalSubtotal),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (itemDiscountTotal > 0 || safeOrderDiscount > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'misc.pos_discounts'.tr(),
                  style: const TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontSize: 12,
                  ),
                ),
                Text(
                  '-${_formatCurrency(itemDiscountTotal + safeOrderDiscount)}',
                  style: const TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          if (taxRate > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'misc.pos_tax_percent'.tr(
                    namedArgs: {'rate': taxRate.toStringAsFixed(1)},
                  ),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                Text(
                  _formatCurrency(safeTaxAmount),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          const Divider(color: Color(0xFF475569), height: 16, thickness: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'misc.pos_total'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatCurrency(safeTotal),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton(
    List<CartItem> cart,
    double safeTotal, {
    EdgeInsetsGeometry? padding,
  }) {
    return Builder(
      builder: (context) {
        final isButtonEnabled =
            cart.isNotEmpty && !_payLocked && !_isProcessingPayment;
        final disabledColor = Colors.grey.shade600;

        return ElevatedButton(
          onPressed: isButtonEnabled
              ? () => unawaited(_openPaymentCheckout(cart))
              : null,
          style: ElevatedButton.styleFrom(
            padding: padding ?? const EdgeInsets.symmetric(vertical: 12),
            backgroundColor:
                isButtonEnabled ? AppColors.primaryColor : Colors.grey.shade400,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: isButtonEnabled ? 2 : 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.payment,
                size: 18,
                color: isButtonEnabled ? Colors.white : disabledColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Pay ${_formatCurrency(safeTotal)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isButtonEnabled ? Colors.white : disabledColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickPaymentButtons(
    double total,
    bool compactSummary, [
    StateSetter? setSheetState,
    TextEditingController? cashController,
  ]) {
    final currency = ref.read(currentCurrencyProvider);
    final amounts = [50.0, 100.0, 500.0, 1000.0];
    final currentAmount = _currentPaymentAmount();

    void applyAmount(double amount) {
      HapticFeedbackUtil.light();
      if (setSheetState != null) {
        setSheetState(() {
          _setCurrentPaymentAmount(amount);
          cashController?.text = amount.toStringAsFixed(2);
        });
      } else {
        setState(() {
          _setCurrentPaymentAmount(amount);
        });
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: compactSummary ? 6 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Amount',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...amounts.map((amount) {
                final isSelected = (currentAmount - amount).abs() < 0.01;
                return GestureDetector(
                  onTap: () => applyAmount(amount),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? const Color(0xFF3B82F6) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFFE2E8F0),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      '${currency.symbol}${amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                );
              }),
              // Exact Amount Button
              GestureDetector(
                onTap: () => applyAmount(total),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: (currentAmount - total).abs() < 0.01
                        ? const Color(0xFF10B981)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (currentAmount - total).abs() < 0.01
                          ? const Color(0xFF10B981)
                          : const Color(0xFFE2E8F0),
                      width: (currentAmount - total).abs() < 0.01 ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: (currentAmount - total).abs() < 0.01
                            ? Colors.white
                            : const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Exact',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: (currentAmount - total).abs() < 0.01
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSplitPaymentField(
    String label,
    FocusNode focusNode,
    double amount,
    Color color,
    Function(String) onChanged,
  ) {
    return TextField(
      key: ValueKey('${label}_$_paymentType$_paymentFieldVersion'),
      focusNode: focusNode,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        prefixText: '${ref.read(currentCurrencyProvider).symbol} ',
        prefixStyle: TextStyle(color: color, fontSize: 13),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [DecimalInputFormatter(maxDecimalPlaces: 2)],
      onChanged: onChanged,
      onSubmitted: (_) => focusNode.unfocus(),
    );
  }

  Widget _buildCompactPaymentButton(String type, IconData icon, String label) {
    final isSelected = _paymentType == type;
    return GestureDetector(
      onTap: () {
        if (_selectedCustomer == null && type != 'cash') {
          return;
        }
        if (mounted) {
          setState(() {
            _paymentType = type;
            _itemPrices.clear();
            _itemAmounts.clear();
            // Clear due date when switching away from credit
            if (type != 'credit') {
              _dueDate = null;
              _creditAmount = 0;
            } else if (_dueDate == null) {
              // Set default due date to 30 days from now for credit
              _dueDate = DateTime.now().add(const Duration(days: 30));
            }
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
              size: 14,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSummary(List<CartItem> cart) {
    // Calculate subtotal using _safeGetItemPrice to account for payment type
    final subtotal = cart.fold(0.0, (sum, item) {
      try {
        final basePrice = _safeGetItemPrice(item);
        final safePrice =
            basePrice.isNaN || basePrice.isInfinite ? 0.0 : basePrice;
        final safeQuantity = item.quantity.isNaN || item.quantity.isInfinite
            ? 0.0
            : item.quantity;
        final itemSubtotal = safePrice * safeQuantity;
        final safeItemSubtotal =
            itemSubtotal.isNaN || itemSubtotal.isInfinite ? 0.0 : itemSubtotal;
        return sum + safeItemSubtotal;
      } catch (e) {
        return sum;
      }
    });
    final safeSubtotal = subtotal.isNaN || subtotal.isInfinite ? 0.0 : subtotal;
    final discountValue =
        _discount.isNaN || _discount.isInfinite ? 0.0 : _discount;
    final computedDiscount = _discountType == 'percentage'
        ? safeSubtotal * discountValue / 100
        : discountValue;
    final safeDiscountAmount =
        computedDiscount.isNaN || computedDiscount.isInfinite
            ? 0.0
            : computedDiscount;
    final subtotalAfterDiscount = safeSubtotal - safeDiscountAmount;
    final taxRate = ref.watch(currentTaxRateProvider);
    final taxAmount = TaxCalculator.calculateTax(
      subtotalAfterDiscount,
      taxRate,
    );
    final safeTaxAmount =
        taxAmount.isNaN || taxAmount.isInfinite ? 0.0 : taxAmount;
    final total = subtotalAfterDiscount + safeTaxAmount;
    final safeTotal = total.isNaN || total.isInfinite ? 0.0 : total;

    final singlePaymentMode = !_isSplitPayment;
    final singlePaymentLabel = _currentPaymentFieldLabel();
    final singlePaymentColor = _currentPaymentFieldColor();
    final singlePaymentValue = _currentPaymentAmount();
    final safeSinglePayment =
        singlePaymentValue.isNaN || singlePaymentValue.isInfinite
            ? 0.0
            : singlePaymentValue;
    final remainingAmount = (safeTotal - safeSinglePayment).clamp(
      0.0,
      double.infinity,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          if (ref.watch(discountSettingsProvider).overallDiscountEnabled) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.discount,
                        size: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'pos.discount_field_label'.tr(),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'pos.hint_enter_discount'.tr(),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            DecimalInputFormatter(maxDecimalPlaces: 2),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _discount = double.tryParse(value) ?? 0.0;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _discountType,
                        items: [
                          DropdownMenuItem(
                            value: 'percentage',
                            child: Text('pos.percent_symbol'.tr()),
                          ),
                          DropdownMenuItem(
                            value: 'fixed',
                            child: Text(
                              ref.read(currentCurrencyProvider).symbol,
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _discountType = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'misc.pos_subtotal_colon'.tr(),
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      _formatCurrency(safeSubtotal),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                if (safeDiscountAmount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'misc.pos_discount_with_detail'.tr(
                          namedArgs: {
                            'detail': _discountType == 'percentage'
                                ? '${discountValue.toStringAsFixed(0)}%'
                                : _formatCurrency(discountValue),
                          },
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        '-${_formatCurrency(safeDiscountAmount)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
                if (safeTaxAmount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'misc.pos_tax_percent'.tr(
                          namedArgs: {'rate': taxRate.toStringAsFixed(1)},
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                      Text(
                        _formatCurrency(safeTaxAmount),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'misc.pos_total_colon'.tr(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      _formatCurrency(safeTotal),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.payment,
                      size: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Payment',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (singlePaymentMode) ...[
                  if (_selectedCustomer != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildPaymentButton(
                            'cash',
                            Icons.money,
                            'pos.pay_cash'.tr(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPaymentButton(
                            'card',
                            Icons.credit_card,
                            'pos.pay_card'.tr(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPaymentButton(
                            'credit',
                            Icons.receipt_long,
                            'pos.pay_khata'.tr(),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        'pos.walk_in_auto_cash'.tr(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                  if (_selectedCustomer != null &&
                      _paymentType == 'credit') ...[
                    const SizedBox(height: 12),
                    _buildDueDatePicker(),
                  ],
                  if (_selectedCustomer == null) ...[
                    const SizedBox(height: 12),
                    _buildSplitPaymentField(
                      singlePaymentLabel,
                      _cashAmountFocusNode,
                      safeSinglePayment,
                      singlePaymentColor,
                      (value) => setState(() {
                        _setCurrentPaymentAmount(double.tryParse(value) ?? 0.0);
                      }),
                    ),
                    const SizedBox(height: 6),
                    Builder(
                      builder: (context) {
                        // Show warning if cash received exceeds total due (only for cash payments)
                        final showWarning = _paymentType == 'cash' &&
                            safeSinglePayment > safeTotal;

                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'pos.paid_label'.tr(
                                    namedArgs: {
                                      'amount': _formatCurrency(
                                        safeSinglePayment.clamp(0.0, safeTotal),
                                      ),
                                    },
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  'pos.due_label'.tr(
                                    namedArgs: {
                                      'amount': _formatCurrency(
                                        remainingAmount,
                                      ),
                                    },
                                  ),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: remainingAmount > 0
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                            if (showWarning) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFEF4444,
                                    ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      size: 12,
                                      color: Color(0xFFEF4444),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'pos.cash_exceeds_due'.tr(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFFEF4444),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                  if (_selectedCustomer == null && _paymentType == 'cash') ...[
                    Builder(
                      builder: (context) {
                        final rawCash =
                            _cashAmount.isNaN || _cashAmount.isInfinite
                                ? 0.0
                                : _cashAmount;
                        if (rawCash <= safeTotal)
                          return const SizedBox.shrink();
                        final changeAmount = rawCash - safeTotal;
                        return Column(
                          children: [
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF10B981).withOpacity(0.15),
                                    const Color(0xFF10B981).withOpacity(0.25),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF10B981),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF10B981,
                                    ).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.money,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'pos.change_to_give'.tr(),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF059669),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatCurrency(changeAmount),
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'pos.cash_received'.tr(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                      Text(
                                        _formatCurrency(rawCash),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Cash Amount',
                            prefixText:
                                '${ref.read(currentCurrencyProvider).symbol} ',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            DecimalInputFormatter(maxDecimalPlaces: 2),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _cashAmount = double.tryParse(value) ?? 0;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Card Amount',
                            prefixText:
                                '${ref.read(currentCurrencyProvider).symbol} ',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            DecimalInputFormatter(maxDecimalPlaces: 2),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _cardAmount = double.tryParse(value) ?? 0;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Paid: ${_formatCurrency(_cashAmount + _cardAmount)}',
                      ),
                      Text(
                        'Remaining: ${_formatCurrency(safeTotal - (_cashAmount + _cardAmount))}',
                        style: TextStyle(
                          color: (safeTotal - (_cashAmount + _cardAmount)) > 0
                              ? Colors.red
                              : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              // Calculate due amount based on payment type
              double dueAmount = 0.0;
              bool isButtonEnabled = false;

              // If total is negative, enable button without requiring cash payment
              if (safeTotal < 0) {
                // Negative total: enable button without cash requirement
                dueAmount = safeTotal;
                isButtonEnabled = true;
              } else if (_isSplitPayment) {
                // Split payment: due = total - (cash + card)
                final safeCash = _cashAmount.isNaN || _cashAmount.isInfinite
                    ? 0.0
                    : _cashAmount;
                final safeCard = _cardAmount.isNaN || _cardAmount.isInfinite
                    ? 0.0
                    : _cardAmount;
                final totalPaid = safeCash + safeCard;
                dueAmount = (safeTotal - totalPaid).clamp(0.0, double.infinity);
                // Enable if at least some payment is entered
                isButtonEnabled = totalPaid > 0;
              } else {
                // Single payment mode
                switch (_paymentType) {
                  case 'credit':
                    // Credit: always enabled (can be 0 or partial payment)
                    final safeCredit =
                        _creditAmount.isNaN || _creditAmount.isInfinite
                            ? 0.0
                            : _creditAmount;
                    dueAmount = (safeTotal - safeCredit).clamp(
                      0.0,
                      double.infinity,
                    );
                    isButtonEnabled = true; // Credit always enabled
                    break;
                  case 'card':
                    // Card: always enabled (not dependent on due amount)
                    final safeCard = _cardAmount.isNaN || _cardAmount.isInfinite
                        ? 0.0
                        : _cardAmount;
                    dueAmount = (safeTotal - safeCard).clamp(
                      0.0,
                      double.infinity,
                    );
                    isButtonEnabled = true; // Card always enabled
                    break;
                  case 'cash':
                  default:
                    // Cash: enable if amount > 0 (for walk-in) or always enabled if customer selected
                    if (_selectedCustomer == null) {
                      // Walk-in: need payment amount
                      final safeCash =
                          _cashAmount.isNaN || _cashAmount.isInfinite
                              ? 0.0
                              : _cashAmount;
                      dueAmount = (safeTotal - safeCash).clamp(
                        0.0,
                        double.infinity,
                      );
                      isButtonEnabled = safeCash > 0;
                    } else {
                      // Customer selected: always enabled (can be credit)
                      dueAmount = safeTotal;
                      isButtonEnabled = true;
                    }
                    break;
                }
              }

              // Final checks
              isButtonEnabled = isButtonEnabled &&
                  cart.isNotEmpty &&
                  !_payLocked &&
                  !_isProcessingPayment;

              return SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isButtonEnabled ? _processPayment : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: isButtonEnabled
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: isButtonEnabled ? 2 : 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.payment,
                        size: 20,
                        color: isButtonEnabled
                            ? Colors.white
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pay ${_formatCurrency(safeTotal)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isButtonEnabled
                              ? Colors.white
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Professional helper methods for safe cart operations
  String _safeGetProductId(ProductModel product) {
    return product.id?.toString() ?? '';
  }

  double _safeGetItemPrice(CartItem item) {
    try {
      // Handle bundles
      if (item.isBundle && item.bundle != null) {
        return item.bundle!.price.isNaN || item.bundle!.price.isInfinite
            ? 0.0
            : item.bundle!.price;
      }

      if (item.product == null) return 0.0;

      final productId = _safeGetProductId(item.product!);
      final customPrice = _itemPrices[productId];

      // If custom price is set, use it
      if (customPrice != null) {
        return customPrice.isNaN || customPrice.isInfinite ? 0.0 : customPrice;
      }

      return _safeGetBaseItemPrice(item);
    } catch (e) {
      debugPrint('Error getting item price: $e');
      return 0.0;
    }
  }

  /// Returns the configured product price without any temporary cart override.
  /// Price editing must compare against this value; comparing against
  /// [_safeGetItemPrice] would compare the input with itself while typing.
  double _safeGetBaseItemPrice(CartItem item) {
    try {
      if (item.isBundle && item.bundle != null) {
        return item.bundle!.price.isFinite ? item.bundle!.price : 0.0;
      }
      if (item.product == null) return 0.0;

      // Determine base price based on wholesale mode and payment type
      double basePrice;
      if (_isWholesaleMode) {
        // Wholesale mode: use wholesale cash or credit price based on payment type
        if (_paymentType == 'credit') {
          basePrice = item.product!.wholesaleCredit ?? item.product!.price;
        } else {
          basePrice = item.product!.wholesaleCash ?? item.product!.price;
        }
      } else {
        // Retail mode: use retail cash or credit price based on payment type
        if (_paymentType == 'credit') {
          basePrice = item.product!.retailCredit ?? item.product!.price;
        } else {
          basePrice = item.product!.price;
        }
      }

      return basePrice.isNaN || basePrice.isInfinite ? 0.0 : basePrice;
    } catch (e) {
      debugPrint('Error getting base item price: $e');
      return 0.0;
    }
  }

  double _safeGetItemDiscount(CartItem item) {
    // POS discounts are intentionally cart-level only.
    return 0.0;
  }

  double _safeCalculateSubtotal(CartItem item) {
    try {
      final price = _safeGetItemPrice(item);
      final discount = _safeGetItemDiscount(item);
      final quantity =
          item.quantity.isNaN || item.quantity.isInfinite ? 0.0 : item.quantity;

      final discountedPrice = price - discount;
      final safeDiscountedPrice =
          discountedPrice.isNaN || discountedPrice.isInfinite
              ? 0.0
              : discountedPrice;
      final subtotal = safeDiscountedPrice * quantity;

      return subtotal.isNaN || subtotal.isInfinite ? 0.0 : subtotal;
    } catch (e) {
      debugPrint('Error calculating subtotal: $e');
      return 0.0;
    }
  }

  String _safeGetProductName(ProductModel product) {
    try {
      return product.name.isEmpty ? 'Unknown Product' : product.name;
    } catch (e) {
      return 'Unknown Product';
    }
  }

  /// Check if a product is a phone - Retail only, always false
  bool _isPhoneProduct(ProductModel product, bool isMobileShop) {
    return false;
  }

  /// Validate phone IMEIs before checkout to prevent missing/duplicate/sold IMEIs.
  Future<bool> _validatePhoneIMEIsOnCheckout(List<CartItem> cart) async {
    // IMEI validation only applies to mobile shop (removed)
    return true;

    final seenImeis = <String>{};
    final databaseService = ref.read(databaseServiceProvider);

    for (final item in cart) {
      final product = item.product;
      if (product == null) continue;
      final isPhoneProduct = _isPhoneProduct(product, true);
      if (!isPhoneProduct) continue;

      final imei = item.imei?.trim() ?? '';
      if (imei.isEmpty) {
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text(
                'pos.imei_required_for'.tr(
                  namedArgs: {'name': _safeGetProductName(product)},
                ),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      if (!seenImeis.add(imei)) {
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text(
                'pos.imei_duplicate_in_cart'.tr(namedArgs: {'imei': imei}),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      try {
        final existing = await databaseService.getIMEIByNumber(imei);
        if (existing != null) {
          // If already sold or linked to another sale, block
          if (existing.status.toLowerCase() == 'sold' ||
              existing.saleId != null) {
            if (mounted) {
              AppSnackBar.show(
                context,
                SnackBar(
                  content: Text(
                    'pos.imei_already_sold'.tr(namedArgs: {'imei': imei}),
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return false;
          }
          // If IMEI belongs to another product, block to avoid mismatch
          if (product.id != null && existing.productId != product.id) {
            if (mounted) {
              AppSnackBar.show(
                context,
                SnackBar(
                  content: Text(
                    'pos.imei_wrong_product'.tr(namedArgs: {'imei': imei}),
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return false;
          }
        }
      } catch (e) {
        debugPrint('IMEI validation error: $e');
      }
    }

    return true;
  }

  bool _addToCart(ProductModel product) {
    // Prevent adding items if sale is complete - user must start new bill first
    if (_isSaleComplete) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('pos.add_bill_before_items'.tr()),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return false;
    }

    // Null safety check
    if (product.id == null) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              'pos.err_with_message'.tr(
                namedArgs: {'error': 'pos.err_product_id_missing'.tr()},
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    // Positive sales cannot begin with unavailable stock. Returns and stock
    // adjustments still support negative quantities through their own flow.
    if (product.stock <= 0) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              'pos.product_out_of_stock'.tr(
                namedArgs: {'name': _safeGetProductName(product)},
              ),
            ),
            backgroundColor: AppColors.errorColor,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    final existingQuantity = ref
        .read(cartProvider)
        .where((item) => !item.isBundle && item.product?.id == product.id)
        .fold<double>(0, (sum, item) => sum + item.quantity);
    if (existingQuantity >= product.stock) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              'Quantity cannot exceed stock (${_formatQuantityDisplay(product.stock)} ${product.unit})',
            ),
            backgroundColor: AppColors.errorColor,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    // Add directly to cart
    _addProductToCart(product);
    return true;
  }

  // Accessory suggestions removed - retail only
  Future<void> _showAccessorySuggestions(ProductModel phone) async {
    // Not applicable in retail mode
  }

  void _addProductToCart(ProductModel product, {String? imei}) {
    try {
      // IMEI workflow removed: always add product without IMEI linkage.
      ref.read(cartProvider.notifier).addProduct(product, imei: null);
      if (mounted) {
        setState(() {
          _payLocked = false; // unlock pay when cart changes
        });
      }

      // Play beep sound when adding item to cart
      final audioSettings = ref.read(audioSettingsProvider);
      if (audioSettings.cartBeepEnabled) {
        final audioService = ref.read(audioServiceProvider);
        audioService.playCartBeep();
      }

      // Haptic feedback
      _triggerHapticFeedback(HapticFeedbackType.success);
    } catch (e, stackTrace) {
      debugPrint('Error adding product to cart: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              'Error adding product to cart: ${_safeGetProductName(product)}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addBundleToCart(ProductBundleModel bundle) {
    try {
      // Add bundle as a single item to cart
      ref.read(cartProvider.notifier).addBundle(bundle);

      if (mounted) {
        setState(() {
          _payLocked = false;
        });
      }

      // Play beep sound
      final audioSettings = ref.read(audioSettingsProvider);
      if (audioSettings.cartBeepEnabled) {
        final audioService = ref.read(audioServiceProvider);
        audioService.playCartBeep();
      }

      // Haptic feedback
      _triggerHapticFeedback(HapticFeedbackType.success);

      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              'pos.bundle_added_cart'.tr(namedArgs: {'name': bundle.name}),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error adding bundle to cart: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              'pos.err_add_bundle'.tr(namedArgs: {'name': bundle.name}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showIMEIDialog(ProductModel product) async {
    final imeiController = TextEditingController();
    final searchController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final databaseService = ref.read(databaseServiceProvider);
    final cart = ref.read(cartProvider);
    final existingCartIMEIs = cart
        .where((c) => c.imei != null && c.imei!.isNotEmpty)
        .map((c) => c.imei!)
        .toSet();

    List<ProductIMEI> availableImeis = [];
    try {
      if (product.id != null) {
        final imeis = await databaseService.getIMEIsByProduct(product.id!);
        availableImeis =
            imeis.where((i) => i.status.toLowerCase() == 'available').toList();
      }
    } catch (_) {
      // If fetching IMEIs fails, fall back to manual entry only
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.phone_android, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('pos.assign_imei'.tr()),
                  if (product.brand != null || product.modelName != null)
                    Text(
                      '${product.brand ?? ''} ${product.modelName ?? ''}'
                          .trim(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setState) {
            final filteredImeis = searchController.text.isEmpty
                ? availableImeis
                : availableImeis
                    .where(
                      (i) =>
                          i.imei.contains(searchController.text.trim()) ||
                          (i.notes ?? '').toLowerCase().contains(
                                searchController.text.trim().toLowerCase(),
                              ),
                    )
                    .toList();
            return Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (availableImeis.isNotEmpty) ...[
                    TextFormField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: 'Search available IMEIs',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredImeis.length,
                        itemBuilder: (context, index) {
                          final imeiItem = filteredImeis[index];
                          final isSelected =
                              imeiController.text == imeiItem.imei;
                          final alreadyInCart = existingCartIMEIs.contains(
                            imeiItem.imei,
                          );
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              leading: Icon(
                                Icons.qr_code,
                                color:
                                    alreadyInCart ? Colors.orange : Colors.blue,
                              ),
                              title: Text(imeiItem.imei),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (imeiItem.notes != null &&
                                      imeiItem.notes!.isNotEmpty)
                                    Text(imeiItem.notes!),
                                  Text(
                                    'pos.status_label'.tr(
                                      namedArgs: {'status': imeiItem.status},
                                    ),
                                  ),
                                ],
                              ),
                              trailing: alreadyInCart
                                  ? Chip(
                                      label: Text('pos.in_cart'.tr()),
                                      backgroundColor: Colors.orangeAccent,
                                    )
                                  : isSelected
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                        )
                                      : null,
                              onTap: alreadyInCart
                                  ? null
                                  : () {
                                      setState(() {
                                        imeiController.text = imeiItem.imei;
                                      });
                                    },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: imeiController,
                    decoration: InputDecoration(
                      labelText: 'IMEI Number',
                      hintText: 'pos.hint_imei'.tr(),
                      prefixIcon: const Icon(Icons.phone_android),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      helperText: 'IMEI is required for phone sales',
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 15,
                    autofocus: availableImeis.isEmpty,
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.isEmpty) return 'IMEI is required';
                      if (trimmed.length != 15) return 'IMEI must be 15 digits';
                      if (!RegExp(r'^\\d{15}\$').hasMatch(trimmed)) {
                        return 'IMEI must contain only numbers';
                      }
                      if (existingCartIMEIs.contains(trimmed)) {
                        return 'This IMEI is already in the cart';
                      }
                      return null;
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(15),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final imei = imeiController.text.trim();
                Navigator.pop(context);
                _addProductToCart(product, imei: imei);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text('pos.add_to_cart'.tr()),
          ),
        ],
      ),
    );
  }

  void _triggerHapticFeedback(HapticFeedbackType type) async {
    try {
      // Skip vibration on Windows - it's not supported and can cause crashes
      if (Platform.isWindows) {
        // Use Flutter's built-in haptic feedback instead
        switch (type) {
          case HapticFeedbackType.success:
          case HapticFeedbackType.light:
            HapticFeedback.lightImpact();
            break;
          case HapticFeedbackType.error:
          case HapticFeedbackType.medium:
            HapticFeedback.mediumImpact();
            break;
          case HapticFeedbackType.heavy:
            HapticFeedback.heavyImpact();
            break;
        }
        return;
      }

      // For mobile platforms, use vibration if available
      if (await Vibration.hasVibrator() == true) {
        switch (type) {
          case HapticFeedbackType.success:
            Vibration.vibrate(duration: 100);
            break;
          case HapticFeedbackType.error:
            Vibration.vibrate(duration: 200, amplitude: 255);
            break;
          case HapticFeedbackType.light:
            HapticFeedback.lightImpact();
            break;
          case HapticFeedbackType.medium:
            HapticFeedback.mediumImpact();
            break;
          case HapticFeedbackType.heavy:
            HapticFeedback.heavyImpact();
            break;
        }
      }
    } catch (e) {
      // Silently fail - haptic feedback is not critical
      debugPrint('Haptic feedback error: $e');
    }
  }

  void _showCurrencyNotesDialog() {
    final currency = ref.read(currentCurrencyProvider);
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width >= 1024;
    final isTablet = screenSize.width >= 768 && screenSize.width < 1024;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isDesktop
              ? 80
              : isTablet
                  ? 40
                  : 16,
          vertical: isDesktop ? 40 : 20,
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isDesktop
                  ? 900
                  : isTablet
                      ? 700
                      : double.infinity,
              maxHeight: screenSize.height * 0.9,
            ),
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            child: CurrencyCounterWidget(
              currency: currency,
              onTotalCalculated: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  void _openPrinterSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReceiptSettingsScreen()),
    );
  }

  Future<void> _openBarcodeScanner() async {
    try {
      final canOpen = await _ensureBarcodeScannerAvailable();
      if (!canOpen || !mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
      );
    } catch (e) {
      debugPrint('Failed to open barcode scanner: $e');
    }
  }

  void _showBarcodeInputDialog() {
    final TextEditingController barcodeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('pos.enter_barcode'.tr()),
        content: TextField(
          controller: barcodeController,
          decoration: InputDecoration(
            hintText: 'pos.hint_barcode_number'.tr(),
            prefixIcon: const Icon(Icons.qr_code),
          ),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              final barcode = barcodeController.text.trim();
              if (barcode.isNotEmpty) {
                Navigator.pop(context);
                await _handleBarcodeInput(barcode);
              }
            },
            child: Text('pos.add_product'.tr()),
          ),
        ],
      ),
    );
  }

  Future<bool> _ensureBarcodeScannerAvailable() async {
    if (!Platform.isWindows) return true;

    final isConnected = await _isWindowsBarcodeDeviceConnected();
    if (!isConnected) {
      Fluttertoast.showToast(
        msg:
            'No camera barcode scanner found. If you are using a USB barcode scanner, it should still work from the search box.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              'No camera barcode scanner found. USB barcode scanners still work via the product search box.',
            ),
          ),
        );
      }
    }
    return isConnected;
  }

  Future<bool> _isWindowsBarcodeDeviceConnected() async {
    final controller = MobileScannerController(autoStart: false);
    bool started = false;
    bool hasScanner = false;

    try {
      final args = await controller.start();
      started = args != null;
      final cameraCount = args?.numberOfCameras ?? 0;
      hasScanner = cameraCount > 0;
    } catch (e) {
      debugPrint('Barcode availability check failed: $e');
      hasScanner = false;
    } finally {
      if (started) {
        try {
          await controller.stop();
        } catch (_) {}
      }
      controller.dispose();
    }

    return hasScanner;
  }

  Future<void> _handleBarcodeInput(String barcode) async {
    try {
      // Look up product by barcode
      final databaseService = ref.read(databaseServiceProvider);
      final product = await databaseService.getProductByBarcode(barcode);

      if (product != null) {
        // Add product to cart
        final wasAdded = _addToCart(product);

        // Show success feedback
        if (wasAdded && mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text(
                'pos.added_to_cart_name'.tr(namedArgs: {'name': product.name}),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // _addToCart owns success sound and haptic feedback, keeping barcode
        // and product-card entry behavior identical.
      } else {
        // Product not found
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text(
                'pos.product_not_found_barcode'.tr(
                  namedArgs: {'barcode': barcode},
                ),
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              'pos.err_barcode_lookup'.tr(namedArgs: {'error': '$e'}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _cartItemKey(CartItem item) {
    if (item.isBundle && item.bundle != null) {
      return 'bundle_${item.bundle!.id ?? 'temp_${item.hashCode}'}';
    }
    return item.product?.id?.toString() ?? 'temp_${item.hashCode}';
  }

  // Handle Tab navigation between cart item fields
  bool _handleTabNavigation(bool isShiftPressed) {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return false;

    // Find which field currently has focus
    CartItem? currentItem;
    String? currentField; // 'quantity', 'price', 'amount'

    for (final item in cart) {
      final quantityFocus = _getCartQuantityFocusNode(item);
      final priceFocus = _getCartPriceFocusNode(item);
      final amountFocus = _getCartAmountFocusNode(item);

      if (quantityFocus.hasFocus) {
        currentItem = item;
        currentField = 'quantity';
        break;
      } else if (priceFocus.hasFocus) {
        currentItem = item;
        currentField = 'price';
        break;
      } else if (amountFocus.hasFocus) {
        currentItem = item;
        currentField = 'amount';
        break;
      }
    }

    if (currentItem == null) return false;

    final currentIndex = cart.indexOf(currentItem);
    final currentProduct = currentItem.product;
    final unitLower = currentProduct?.unit?.toLowerCase() ?? '';
    final isPieceUnit = unitLower == 'pcs' || unitLower == 'pc';

    // Determine next field based on direction
    String? nextField;
    CartItem? nextItem = currentItem;
    int nextIndex = currentIndex;

    if (isShiftPressed) {
      // Shift+Tab: Navigate backwards
      switch (currentField) {
        case 'quantity':
          // Go to previous item's amount field, or price if no amount
          if (currentIndex > 0) {
            nextIndex = currentIndex - 1;
            nextItem = cart[nextIndex];
            final prevProduct = nextItem.product;
            final prevUnitLower = prevProduct?.unit?.toLowerCase() ?? '';
            final prevIsPieceUnit =
                prevUnitLower == 'pcs' || prevUnitLower == 'pc';
            nextField = prevIsPieceUnit ? 'price' : 'amount';
          } else {
            // Stay on quantity (first field)
            return false;
          }
          break;
        case 'price':
          nextField = 'quantity';
          break;
        case 'amount':
          nextField = 'price';
          break;
      }
    } else {
      // Tab: Navigate forwards
      switch (currentField) {
        case 'quantity':
          nextField = 'price';
          break;
        case 'price':
          if (isPieceUnit) {
            // If piece unit, go to next item's quantity
            if (currentIndex < cart.length - 1) {
              nextIndex = currentIndex + 1;
              nextItem = cart[nextIndex];
              nextField = 'quantity';
            } else {
              // Last item, go to discount field
              FocusScope.of(context).requestFocus(_discountFocusNode);
              return true;
            }
          } else {
            nextField = 'amount';
          }
          break;
        case 'amount':
          // Go to next item's quantity
          if (currentIndex < cart.length - 1) {
            nextIndex = currentIndex + 1;
            nextItem = cart[nextIndex];
            nextField = 'quantity';
          } else {
            // Last item, go to discount field
            FocusScope.of(context).requestFocus(_discountFocusNode);
            return true;
          }
          break;
      }
    }

    // Focus the next field
    if (nextItem != null && nextField != null) {
      final nextProduct = nextItem.product;
      final nextUnitLower = nextProduct?.unit?.toLowerCase() ?? '';
      final nextIsPieceUnit = nextUnitLower == 'pcs' || nextUnitLower == 'pc';

      switch (nextField) {
        case 'quantity':
          FocusScope.of(
            context,
          ).requestFocus(_getCartQuantityFocusNode(nextItem));
          return true;
        case 'price':
          FocusScope.of(context).requestFocus(_getCartPriceFocusNode(nextItem));
          return true;
        case 'amount':
          if (!nextIsPieceUnit) {
            FocusScope.of(
              context,
            ).requestFocus(_getCartAmountFocusNode(nextItem));
            return true;
          }
          break;
      }
    }

    return false;
  }

  // Handle numpad + and - for quantity adjustments
  bool _handleNumpadQuantityAdjustment(int delta) {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return false;

    // Find which cart item field has focus
    for (final item in cart) {
      final quantityFocus = _getCartQuantityFocusNode(item);
      final priceFocus = _getCartPriceFocusNode(item);
      final amountFocus = _getCartAmountFocusNode(item);

      if (quantityFocus.hasFocus ||
          priceFocus.hasFocus ||
          amountFocus.hasFocus) {
        // Adjust quantity
        final currentQty = item.quantity;
        final newQty = (currentQty + delta).clamp(0.0, double.maxFinite);

        if (newQty != currentQty) {
          // Update quantity
          ref
              .read(cartProvider.notifier)
              .updateQuantity(item.product!.id!, newQty);

          // Update quantity controller
          final quantityController = _getCartQuantityController(item);
          final formattedQty = _formatQuantityDisplay(newQty);
          quantityController.value = TextEditingValue(
            text: formattedQty,
            selection: TextSelection.collapsed(offset: formattedQty.length),
          );

          setState(() {});
          return true;
        }
        return true; // Handled even if no change
      }
    }

    return false;
  }

  FocusNode _getCartQuantityFocusNode(CartItem item) {
    final key = _cartItemKey(item);
    return _cartQuantityFocusNodes.putIfAbsent(key, () => FocusNode());
  }

  FocusNode _getCartPriceFocusNode(CartItem item) {
    final key = _cartItemKey(item);
    return _cartPriceFocusNodes.putIfAbsent(key, () => FocusNode());
  }

  FocusNode _getCartAmountFocusNode(CartItem item) {
    final key = _cartItemKey(item);
    return _cartAmountFocusNodes.putIfAbsent(key, () => FocusNode());
  }

  TextEditingController _getCartQuantityController(CartItem item) {
    final key = _cartItemKey(item);
    final formatted = _formatQuantityDisplay(item.quantity);
    final controller = _cartQuantityControllers.putIfAbsent(
      key,
      () => TextEditingController(text: formatted),
    );
    final focusNode = _getCartQuantityFocusNode(item);
    if (!focusNode.hasFocus && controller.text != formatted) {
      controller.value = controller.value.copyWith(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    return controller;
  }

  TextEditingController _getCartPriceController(CartItem item) {
    final key = _cartItemKey(item);
    // Sale Price: Show unit price (can be customized)
    final price = _itemPrices[key] ?? _safeGetItemPrice(item);
    final formatted = _formatPriceDisplay(price);
    final controller = _cartPriceControllers.putIfAbsent(
      key,
      () => TextEditingController(text: formatted),
    );
    final focusNode = _getCartPriceFocusNode(item);
    if (!focusNode.hasFocus && controller.text != formatted) {
      controller.value = controller.value.copyWith(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    return controller;
  }

  TextEditingController _getCartAmountController(CartItem item) {
    final key = _cartItemKey(item);
    final unitPrice = _itemPrices[key] ?? _safeGetItemPrice(item);
    final amount =
        _itemAmounts[key] ?? MoneyMath.lineTotal(unitPrice, item.quantity);
    final formatted = _formatPriceDisplay(amount);
    final controller = _cartAmountControllers.putIfAbsent(
      key,
      () => TextEditingController(text: formatted),
    );
    final focusNode = _getCartAmountFocusNode(item);
    if (!focusNode.hasFocus && controller.text != formatted) {
      controller.value = controller.value.copyWith(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    return controller;
  }

  void _storeCartAmountFromText(CartItem item, String value) {
    final key = _cartItemKey(item);
    final sanitized = value.trim();
    if (sanitized.isEmpty) {
      _itemAmounts[key] = 0.0;
      return;
    }
    final parsed = double.tryParse(sanitized);
    if (parsed == null || !parsed.isFinite) {
      return;
    }
    _storeCartAmountValue(item, parsed);
  }

  void _storeCartAmountValue(CartItem item, double value) {
    final key = _cartItemKey(item);
    final sanitized = value.isNaN || value.isInfinite ? 0.0 : value;
    _itemAmounts[key] = sanitized < 0 ? 0.0 : sanitized;
  }

  String _formatQuantityDisplay(double quantity) {
    if (quantity.isNaN || quantity.isInfinite) return '0';
    final intPart = quantity.truncate();
    if ((quantity - intPart).abs() < 0.0001) {
      return intPart.toString();
    }
    final formatted = quantity.toStringAsFixed(3);
    return formatted
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _formatPriceDisplay(double price) {
    if (price.isNaN || price.isInfinite) return '0.00';
    return price.toStringAsFixed(2);
  }

  /// True for units where a general-store cashier types a Rupee amount
  /// (e.g. "100" for atta, "150" for cheeni, "80" for cooking oil) and the
  /// cart auto-calculates quantity = amount / price-per-unit. Covers both
  /// weight (kg/g/lb) and volume (litre/ml) units.
  bool _isWeightBasedUnit(String? unit) {
    if (unit == null) return false;
    final normalized = unit.trim().toLowerCase();
    return normalized == 'kg' ||
        normalized == 'kgs' ||
        normalized == 'kilogram' ||
        normalized == 'kilograms' ||
        normalized == 'g' ||
        normalized == 'gm' ||
        normalized == 'gms' ||
        normalized == 'gram' ||
        normalized == 'grams' ||
        normalized == 'lb' ||
        normalized == 'lbs' ||
        normalized == 'pound' ||
        normalized == 'pounds' ||
        normalized == 'l' ||
        normalized == 'ltr' ||
        normalized == 'ltrs' ||
        normalized == 'liter' ||
        normalized == 'liters' ||
        normalized == 'litre' ||
        normalized == 'litres' ||
        normalized == 'ml' ||
        normalized == 'millilitre' ||
        normalized == 'millilitres' ||
        normalized == 'milliliter' ||
        normalized == 'milliliters';
  }

  double? _handleQuantityInput(CartItem item, String value) {
    if (item.isBundle || item.product == null) return null;
    final productId = item.product!.id;
    if (productId == null) return null;
    final sanitized = value.trim();
    if (sanitized.isEmpty) return null;
    final parsed = double.tryParse(sanitized);
    if (parsed == null || !parsed.isFinite) return null;

    // A transient zero is common while a cashier replaces the selected text.
    // Never turn text entry into a destructive cart action; items are removed
    // only with the explicit remove control.
    if (parsed == 0) {
      return null;
    }

    // For positive quantities, validate against stock
    // For negative quantities, skip stock validation (they represent returns/adjustments)
    final stock = item.product!.stock;
    double finalQty;
    if (parsed > 0) {
      // Positive quantity: validate against stock
      finalQty = parsed > stock ? stock : parsed;

      if (finalQty != parsed && mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              'Quantity cannot exceed stock (${_formatQuantityDisplay(stock)} ${item.product!.unit})',
            ),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      // Negative quantity: allow it (represents returns/adjustments)
      finalQty = parsed;
    }

    _updateQuantity(productId, finalQty);
    return finalQty;
  }

  double? _handlePriceInput(CartItem item, String value) {
    if (item.isBundle || item.product == null) return null;
    final productId = item.product!.id;
    if (productId == null) return null;
    final sanitized = value.trim();
    if (sanitized.isEmpty) return null;
    final parsed = double.tryParse(sanitized);
    if (parsed == null || !parsed.isFinite || parsed <= 0) return null;

    final key = productId.toString();
    final original = _safeGetBaseItemPrice(item);
    final closeToOriginal = (parsed - original).abs() < 0.0001;

    // Update sale price (unit price)
    setState(() {
      if (closeToOriginal) {
        // If price is close to original, remove custom price
        _itemPrices.remove(key);
      } else {
        // Store the new per-unit price
        _itemPrices[key] = parsed;
      }
    });
    // Return the per-unit price
    return closeToOriginal ? original : parsed;
  }

  void _applyQuantitySubmission(
    CartItem item,
    TextEditingController controller,
  ) {
    final result = _handleQuantityInput(item, controller.text);
    if (result == null) {
      final fallback = _formatQuantityDisplay(item.quantity);
      controller.value = TextEditingValue(
        text: fallback,
        selection: TextSelection.collapsed(offset: fallback.length),
      );
    } else if (result != 0) {
      // Quantity is now the cashier's source of truth; allow the amount field
      // to follow the recalculated line total.
      _itemAmounts.remove(_cartItemKey(item));
      // Format both positive and negative quantities
      final formatted = _formatQuantityDisplay(result);
      controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  void _applyPriceSubmission(CartItem item, TextEditingController controller) {
    final result = _handlePriceInput(item, controller.text);
    if (result == null) {
      final fallback = _formatPriceDisplay(_safeGetItemPrice(item));
      controller.value = TextEditingValue(
        text: fallback,
        selection: TextSelection.collapsed(offset: fallback.length),
      );
    } else {
      // A changed unit price should immediately recalculate the line amount.
      _itemAmounts.remove(_cartItemKey(item));
      final formatted = _formatPriceDisplay(result);
      controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      setState(() {}); // Update total price
    }
  }

  void _handleAmountInputForWeightBased(CartItem item, String value) {
    if (item.isBundle || item.product == null) return;
    final productId = item.product!.id;
    if (productId == null) return;

    final sanitized = value.trim();
    if (sanitized.isEmpty) return;

    final enteredAmount = double.tryParse(sanitized);
    if (enteredAmount == null || !enteredAmount.isFinite || enteredAmount <= 0)
      return;

    _storeCartAmountValue(item, enteredAmount);

    // Get current sale price
    final key = productId.toString();
    final salePrice = _itemPrices[key] ?? _safeGetItemPrice(item);
    if (salePrice <= 0 || salePrice.isNaN || salePrice.isInfinite) return;

    // Calculate quantity: qty = enteredAmount / salePrice
    final normalizedQty = MoneyMath.quantityForAmount(enteredAmount, salePrice);

    // Check stock limit
    if (item.product == null) return null;
    final stock = item.product!.stock;
    final finalQty = normalizedQty > stock ? stock : normalizedQty;

    // If stock caps the request, display and remember the amount that can
    // actually be fulfilled instead of leaving a misleading requested total.
    if (finalQty != normalizedQty) {
      final fulfilledAmount = MoneyMath.lineTotal(salePrice, finalQty);
      _storeCartAmountValue(item, fulfilledAmount);
      final amountController = _getCartAmountController(item);
      final formattedAmount = _formatPriceDisplay(fulfilledAmount);
      amountController.value = TextEditingValue(
        text: formattedAmount,
        selection: TextSelection.collapsed(offset: formattedAmount.length),
      );
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              'Only ${_formatQuantityDisplay(stock)} ${item.product!.unit} is available',
            ),
            backgroundColor: AppColors.warningColor,
          ),
        );
      }
    }

    // Update quantity
    _updateQuantity(productId, finalQty);

    // Update quantity controller
    final quantityController = _getCartQuantityController(item);
    final formattedQty = _formatQuantityDisplay(finalQty);
    quantityController.value = TextEditingValue(
      text: formattedQty,
      selection: TextSelection.collapsed(offset: formattedQty.length),
    );

    setState(() {}); // Update total price
  }

  void _applyAmountSubmission(CartItem item, TextEditingController controller) {
    final sanitized = controller.text.trim();
    if (sanitized.isEmpty) {
      _storeCartAmountValue(item, 0.0);
      final fallback = _formatPriceDisplay(0.0);
      controller.value = TextEditingValue(
        text: fallback,
        selection: TextSelection.collapsed(offset: fallback.length),
      );
      return;
    }

    final parsed = double.tryParse(sanitized);
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      _storeCartAmountValue(item, 0.0);
      final fallback = _formatPriceDisplay(0.0);
      controller.value = TextEditingValue(
        text: fallback,
        selection: TextSelection.collapsed(offset: fallback.length),
      );
      return;
    }

    _storeCartAmountValue(item, parsed);

    // For weight-based items, auto-calculate quantity
    if (item.product != null && _isWeightBasedUnit(item.product!.unit)) {
      _handleAmountInputForWeightBased(item, sanitized);
    }

    final formatted = _formatPriceDisplay(parsed);
    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _currentPaymentFieldLabel() {
    switch (_paymentType) {
      case 'card':
        return 'pos.payment_received'.tr();
      case 'credit':
        return 'pos.payment_received'.tr();
      default:
        return 'pos.cash_received'.tr();
    }
  }

  Color _currentPaymentFieldColor() {
    switch (_paymentType) {
      case 'card':
        return const Color(0xFF3B82F6);
      case 'credit':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF10B981);
    }
  }

  double _currentPaymentAmount() {
    switch (_paymentType) {
      case 'card':
        return _cardAmount;
      case 'credit':
        return _creditAmount;
      default:
        return _cashAmount;
    }
  }

  void _setCurrentPaymentAmount(double value) {
    final sanitized = value.isNaN || value.isInfinite ? 0.0 : value;
    switch (_paymentType) {
      case 'card':
        _cardAmount = sanitized;
        break;
      case 'credit':
        _creditAmount = sanitized;
        break;
      default:
        _cashAmount = sanitized;
        break;
    }
  }

  void _updateQuantity(int productId, double quantity) {
    ref.read(cartProvider.notifier).updateQuantity(productId, quantity);
    if (mounted) {
      setState(() {
        _payLocked = false; // unlock pay when cart changes
      });
    }
  }

  /// Expand cart items (including bundles) into sale items
  List<SaleItemModel> _expandCartItemsToSaleItems(List<CartItem> cart) {
    final List<SaleItemModel> saleItems = [];

    for (final item in cart) {
      if (item.isBundle && item.bundle != null) {
        // Expand bundle into individual items
        final bundle = item.bundle!;
        final bundleQuantity = item.quantity.isNaN || item.quantity.isInfinite
            ? 0.0
            : item.quantity;

        // Allocate the actual bundle selling price proportionally across the
        // component lines. The stored line totals must reconcile exactly with
        // the sale header, even when the bundle is discounted.
        final totalBundlePrice = MoneyMath.lineTotal(
          bundle.price,
          bundleQuantity,
        );
        final totalComponentValue = bundle.items.fold<double>(0.0, (
          sum,
          bundleItem,
        ) {
          final componentPrice = bundleItem.price ?? bundleItem.product.price;
          return sum + (componentPrice * bundleItem.quantity);
        });

        var allocatedMinor = 0;
        final targetMinor = MoneyMath.toMinor(totalBundlePrice);
        for (var index = 0; index < bundle.items.length; index++) {
          final bundleItem = bundle.items[index];
          if (bundleItem.product.id != null) {
            final itemQuantity = bundleItem.quantity * bundleQuantity;
            final componentPrice = bundleItem.price ?? bundleItem.product.price;
            final componentValue = componentPrice * bundleItem.quantity;
            final itemMinor = index == bundle.items.length - 1
                ? targetMinor - allocatedMinor
                : MoneyMath.toMinor(
                    totalComponentValue > 0
                        ? totalBundlePrice *
                            (componentValue / totalComponentValue)
                        : 0.0,
                  );
            allocatedMinor += itemMinor;
            final itemSubtotal = MoneyMath.fromMinor(itemMinor);
            final itemPrice =
                itemQuantity > 0 ? itemSubtotal / itemQuantity : 0.0;

            saleItems.add(
              SaleItemModel(
                saleId: 0,
                productId: bundleItem.product.id!,
                qty: itemQuantity,
                price: itemPrice,
                subtotal: itemSubtotal,
                discount: 0.0,
                costAtSale: bundleItem.product.cost,
                unit: bundleItem.product.unit,
                imei: null,
                createdAt: _selectedSaleDate,
                product: bundleItem.product,
              ),
            );
          }
        }
      } else if (item.product != null && item.product!.id != null) {
        // Regular product item
        final quantity = item.quantity.isFinite ? item.quantity : 0.0;
        final price = _itemPrices[item.product!.id!.toString()] ??
            _safeGetItemPrice(item);
        saleItems.add(
          SaleItemModel(
            saleId: 0,
            productId: item.product!.id!,
            qty: quantity,
            price: price,
            subtotal: MoneyMath.lineTotal(price, quantity),
            discount: 0.0,
            costAtSale: item.product!.cost,
            unit: item.product!.unit,
            imei: item.imei,
            createdAt: _selectedSaleDate,
            product: item.product!,
          ),
        );
      }
    }

    if (saleItems.isEmpty) return saleItems;

    final taxRate = ref.read(currentTaxRateProvider);
    final financials = _computeCartFinancialTotals(cart, taxRate);
    final subtotalMinor = saleItems.fold<int>(
      0,
      (sum, line) => sum + MoneyMath.toMinor(line.subtotal),
    );
    final discountTarget = MoneyMath.toMinor(financials.safeOrderDiscount);
    final taxTarget = MoneyMath.toMinor(financials.safeTaxAmount);
    var allocatedDiscount = 0;
    var allocatedTax = 0;

    for (var index = 0; index < saleItems.length; index++) {
      final line = saleItems[index];
      final isLast = index == saleItems.length - 1;
      final ratio = subtotalMinor == 0
          ? 0.0
          : MoneyMath.toMinor(line.subtotal) / subtotalMinor;
      final discountMinor = isLast
          ? discountTarget - allocatedDiscount
          : (discountTarget * ratio).round();
      final taxMinor =
          isLast ? taxTarget - allocatedTax : (taxTarget * ratio).round();
      allocatedDiscount += discountMinor;
      allocatedTax += taxMinor;
      saleItems[index] = line.copyWith(
        orderDiscountAllocation: MoneyMath.fromMinor(discountMinor),
        taxRate: taxRate,
        taxAmount: MoneyMath.fromMinor(taxMinor),
      );
    }

    return saleItems;
  }

  void _removeFromCart(int productId) {
    // Clean up controllers
    final key = productId.toString();
    _itemPrices.remove(key);
    _itemDiscounts.remove(key);
    _itemAmounts.remove(key);
    // Dispose amount controllers
    _cartAmountControllers[key]?.dispose();
    _cartAmountControllers.remove(key);
    _cartAmountFocusNodes[key]?.dispose();
    _cartAmountFocusNodes.remove(key);
    ref.read(cartProvider.notifier).removeProduct(productId);
    // Clear custom price and discount when item is removed
    setState(() {
      _itemPrices.remove(productId.toString());
      _itemDiscounts.remove(productId.toString());
      _itemAmounts.remove(productId.toString());
      _cartQuantityControllers.remove(productId.toString())?.dispose();
      _cartPriceControllers.remove(productId.toString())?.dispose();
      _cartQuantityFocusNodes.remove(productId.toString())?.dispose();
      _cartPriceFocusNodes.remove(productId.toString())?.dispose();
      _payLocked = false; // unlock pay when cart changes
    });
  }

  Widget _buildPaymentButton(String type, IconData icon, String label) {
    final isSelected = _paymentType == type;
    return GestureDetector(
      onTap: () {
        if (_selectedCustomer == null && type != 'cash') {
          return;
        }
        if (mounted) {
          setState(() {
            _paymentType = type;
            // Clear due date when switching away from credit
            if (type != 'credit') {
              _dueDate = null;
              _creditAmount = 0;
            } else if (_dueDate == null) {
              // Set default due date to 30 days from now for credit
              _dueDate = DateTime.now().add(const Duration(days: 30));
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 16,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDueDatePicker() {
    return InkWell(
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          helpText: 'Select Due Date',
          cancelText: 'Cancel',
          confirmText: 'Set',
        );
        if (pickedDate != null) {
          setState(() {
            _dueDate = pickedDate;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _dueDate == null
                    ? 'Set Due Date'
                    : 'Due: ${_formatDate(_dueDate!)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade900,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.blue.shade700),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _disposeCartTextControllers() {
    for (final controller in _cartQuantityControllers.values) {
      controller.dispose();
    }
    _cartQuantityControllers.clear();
    for (final controller in _cartPriceControllers.values) {
      controller.dispose();
    }
    _cartPriceControllers.clear();
    for (final node in _cartQuantityFocusNodes.values) {
      node.dispose();
    }
    _cartQuantityFocusNodes.clear();
    for (final node in _cartPriceFocusNodes.values) {
      node.dispose();
    }
    _cartPriceFocusNodes.clear();
  }

  Widget _buildRemarksActionRow() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _showRemarksDialog,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF475569),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.note_alt_outlined, size: 16),
            label: const Text(
              'Remarks',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _remarks.isNotEmpty ? _remarks : 'No remarks added',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: _remarks.isNotEmpty
                    ? const Color(0xFF334155)
                    : const Color(0xFF94A3B8),
                fontWeight:
                    _remarks.isNotEmpty ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          if (_remarks.isNotEmpty)
            IconButton(
              tooltip: 'Clear remarks',
              onPressed: () {
                setState(() {
                  _remarks = '';
                  _remarksController.clear();
                });
              },
              icon: const Icon(Icons.clear, size: 16, color: Color(0xFF64748B)),
            ),
        ],
      ),
    );
  }

  Future<void> _showRemarksDialog() async {
    final tempController = TextEditingController(text: _remarks);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Order Remarks'),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: tempController,
              maxLines: 4,
              maxLength: 200,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'pos.hint_sale_remarks'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _remarks = tempController.text.trim();
                  _remarksController.text = _remarks;
                });
                Navigator.of(dialogContext).pop();
              },
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Save'),
            ),
          ],
        );
      },
    );

    tempController.dispose();
  }

  void _clearCart() {
    ref.read(cartProvider.notifier).clear();
    setState(() {
      _selectedCustomer = null;
      _discount = 0;
      _paymentType = 'cash';
      _orderType = 'dine_in';
      // Clear restaurant fields
      _tableNumber = null;
      _serviceCharge = 0;
      _tip = 0;
      _numberOfGuests = null;
      _cashAmount = 0;
      _cardAmount = 0;
      _creditAmount = 0;
      _isSplitPayment = false;
      _remarks = ''; // Clear remarks when cart is cleared
      _remarksController.clear(); // Clear the controller text
      _dueDate = null; // Clear due date
      _itemDiscounts.clear(); // Clear item discounts
      _itemPrices.clear(); // Clear custom prices
      _itemAmounts.clear();
      _paymentFieldVersion++; // Force payment field widgets to rebuild/clear text
      // Clear amount controllers
      for (final controller in _cartAmountControllers.values) {
        controller.dispose();
      }
      _cartAmountControllers.clear();
      for (final focusNode in _cartAmountFocusNodes.values) {
        focusNode.dispose();
      }
      _cartAmountFocusNodes.clear();
      _disposeCartTextControllers();
      _selectedSaleDate = DateTime.now();
      // Don't reset wholesale mode - let cashier decide
      _isSaleComplete = false; // Allow adding items again for new bill
      _payLocked = false; // Reset pay lock as well
      _lastCompletedSaleForReceipt = null;
    });
  }

  bool _isPrinting = false;

  Future<void> _printAndRemove() async {
    // Prevent double-tap
    if (_isPrinting) return;

    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    // Set printing state
    setState(() => _isPrinting = true);

    if (!mounted) {
      setState(() => _isPrinting = false);
      return;
    }

    // Use the same calculation path as the cart and payment dialog so the
    // persisted invoice cannot disagree with what the cashier approved.
    final taxRate = ref.watch(currentTaxRateProvider);
    final financials = _computeCartFinancialTotals(cart, taxRate);
    final discountAmount = financials.safeOrderDiscount;
    final total = financials.safeTotal;

    try {
      final SaleModel saleToPrint;
      if (_isSaleComplete && _lastCompletedSaleForReceipt != null) {
        // Paid bill: use persisted sale so receipt shows real order/sale id (not temp 0).
        saleToPrint = _lastCompletedSaleForReceipt!;
      } else {
        // Preview / unpaid cart: draft receipt (no DB id yet).
        saleToPrint = SaleModel(
          date: _selectedSaleDate,
          total: total,
          discount: discountAmount,
          paid: 0,
          due: 0,
          customerId: _selectedCustomer?.id,
          cashierId: null,
          paymentType: PaymentType.cash,
          status: SaleStatus.paid,
          dueDate: null,
          isWholesale: _isWholesaleMode,
          items: _expandCartItemsToSaleItems(cart),
          customer: _selectedCustomer,
          createdAt: _selectedSaleDate,
        );
      }

      final printed = await _printSaleDirectThermal(saleToPrint);

      // Reset loading flag
      if (mounted) {
        setState(() => _isPrinting = false);
      }
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              printed
                  ? 'pos.receipt_printed'.tr()
                  : 'pos.print_fail_check_printer'.tr(),
            ),
            backgroundColor: printed ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Reset loading flag on error
      if (mounted) {
        setState(() => _isPrinting = false);

        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              'pos.err_print_receipt'.tr(namedArgs: {'error': '$e'}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _printSaleDirectThermal(SaleModel sale) async {
    final databaseService = ref.read(databaseServiceProvider);

    // On Windows, print generated PDF directly (no app dialog/preview popup)
    if (Platform.isWindows) {
      try {
        final success = await WindowsPdfPrintService.printReceiptDirectly(
          sale,
          databaseService: databaseService,
        );
        return success;
      } catch (e) {
        debugPrint('Error printing PDF directly: $e');
        // Fallback to direct printing if preview fails
        return await _printDirectlyWithoutPreview(sale, databaseService);
      }
    }

    // On other platforms, use direct thermal printing
    return await _printDirectlyWithoutPreview(sale, databaseService);
  }

  Future<bool> _printDirectlyWithoutPreview(
    SaleModel sale,
    DatabaseService databaseService,
  ) async {
    final savedSettings = await PrintSettingsService.getDefaultSettings();

    // Get printer settings from database
    final dbPrinterIp = (await databaseService.getSetting(
      'printer_ip',
    ))
        ?.trim();
    final dbPrinterPortRaw = (await databaseService.getSetting(
      'printer_port',
    ))
        ?.trim();
    final dbPrinterPort = int.tryParse(dbPrinterPortRaw ?? '');
    final dbPrinterName = (await databaseService.getSetting(
      'printer_name',
    ))
        ?.trim();

    final savedIp = (savedSettings.printerIp ?? '').trim();
    final effectiveIp = savedIp.isNotEmpty ? savedIp : (dbPrinterIp ?? '');
    final hasPrinterIp = effectiveIp.isNotEmpty;
    final hasWindowsPrinter = dbPrinterName != null && dbPrinterName.isNotEmpty;
    final hasBluetoothPrinter =
        await BluetoothPrinterService.verifyConnection();

    // Check if we have any printer configured (Bluetooth, Windows or network).
    if (!hasBluetoothPrinter && !hasPrinterIp && !hasWindowsPrinter) {
      debugPrint(
        'POS print blocked: No printer configured (no IP or Windows printer name)',
      );
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: const Text(
              'No printer configured. Please connect a printer in Settings.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return false;
    }

    // Determine printer type and create appropriate settings
    PrintSettings printSettings;
    final thermalPaperSize = savedSettings.paperSize == PaperSize.thermal58mm
        ? PaperSize.thermal58mm
        : PaperSize.thermal80mm;

    if (hasBluetoothPrinter) {
      debugPrint('POS: Using connected Bluetooth thermal printer');
      printSettings = savedSettings.copyWith(
        printerType: PrinterType.bluetooth,
        copies: 1,
        paperSize: thermalPaperSize,
        orientation: PrintOrientation.portrait,
      );
    } else if (hasWindowsPrinter) {
      // Use Windows printer
      debugPrint('POS: Using Windows printer: $dbPrinterName');
      printSettings = savedSettings.copyWith(
        printerType: PrinterType.thermal,
        printerName: dbPrinterName,
        copies: 1,
        paperSize: thermalPaperSize,
        orientation: PrintOrientation.portrait,
      );
    } else {
      // Use network thermal printer
      debugPrint('POS: Using network thermal printer: $effectiveIp');
      printSettings = savedSettings.copyWith(
        printerType: PrinterType.networkThermal,
        printerIp: effectiveIp,
        printerPort: dbPrinterPort ?? savedSettings.printerPort,
        copies: 1,
        paperSize: thermalPaperSize,
        orientation: PrintOrientation.portrait,
      );
    }

    return UnifiedPrintService.printReceipt(
      sale,
      settings: printSettings,
      databaseService: databaseService,
    ).timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        debugPrint('POS print timeout');
        return false;
      },
    );
  }

  Future<void> _processPayment() async {
    // Re-entrancy guard: a rapid double-tap/double-Enter before the button's
    // _payLocked-based rebuild lands could otherwise re-enter this function
    // and insert a duplicate sale + double-deduct stock.
    if (_isProcessingPayment) return;
    _isProcessingPayment = true;
    try {
      await _processPaymentInternal();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      } else {
        _isProcessingPayment = false;
      }
    }
  }

  Future<void> _processPaymentInternal() async {
    // Unfocus all fields to prevent keyboard issues
    _unfocusAllFields();

    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    // Check stock availability for all items in cart before processing payment
    final databaseService = ref.read(databaseServiceProvider);
    for (final item in cart) {
      if (item.isBundle && item.bundle != null) {
        // Check stock for all items in bundle
        for (final bundleItem in item.bundle!.items) {
          if (bundleItem.product.id != null) {
            final product = await databaseService.getProductById(
              bundleItem.product.id!,
            );
            if (product != null) {
              final requiredQty = bundleItem.quantity * item.quantity;
              if (requiredQty > 0 && product.stock < requiredQty) {
                final productName = _safeGetProductName(product);
                if (mounted) {
                  AppSnackBar.show(
                    context,
                    SnackBar(
                      content: Text(
                        'pos.bundle_stock_short'.tr(
                          namedArgs: {
                            'product': productName,
                            'bundle': item.bundle!.name,
                            'required': requiredQty.toStringAsFixed(2),
                            'available': product.stock.toStringAsFixed(2),
                          },
                        ),
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
                return;
              }
            }
          }
        }
      } else if (item.product != null && item.product!.id != null) {
        // Get latest product data from database to ensure accurate stock
        final product = await databaseService.getProductById(item.product!.id!);
        if (product != null) {
          // Check if product is out of stock (only for positive quantities)
          // Negative quantities represent returns/adjustments and should be allowed
          if (item.quantity > 0 && product.stock <= 0) {
            final productName = _safeGetProductName(product);
            if (mounted) {
              AppSnackBar.show(
                context,
                SnackBar(
                  content: Text(
                    'pos.product_out_of_stock'.tr(
                      namedArgs: {'name': productName},
                    ),
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            }
            return; // Exit early, don't process payment
          }

          // Check if requested quantity exceeds available stock (only for positive quantities)
          // Negative quantities represent returns/adjustments and should be allowed
          if (item.quantity > 0 && item.quantity > product.stock) {
            final productName = _safeGetProductName(product);
            if (mounted) {
              AppSnackBar.show(
                context,
                SnackBar(
                  content: Text(
                    'pos.product_out_of_stock'.tr(
                      namedArgs: {'name': productName},
                    ),
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            }
            return; // Exit early, don't process payment
          }
        }
      }
    }

    // IMEI guardrails for phone products (mobile shop only)
    final imeiOk = await _validatePhoneIMEIsOnCheckout(cart);
    if (!imeiOk) {
      return;
    }

    // Calculate subtotal using _safeGetItemPrice to account for payment type
    final subtotal = cart.fold(0.0, (sum, item) {
      try {
        final basePrice = _safeGetItemPrice(item);
        final safePrice =
            basePrice.isNaN || basePrice.isInfinite ? 0.0 : basePrice;
        final safeQuantity = item.quantity.isNaN || item.quantity.isInfinite
            ? 0.0
            : item.quantity;
        return sum + (safePrice * safeQuantity);
      } catch (e) {
        return sum;
      }
    });
    final discountAmount = _discountType == 'percentage'
        ? (subtotal * _discount / 100)
        : _discount;
    final subtotalAfterDiscount = subtotal - discountAmount;

    // Get tax rate and calculate tax
    final taxRate = ref.watch(currentTaxRateProvider);
    final taxAmount = TaxCalculator.calculateTax(
      subtotalAfterDiscount,
      taxRate,
    );
    final total = subtotalAfterDiscount + taxAmount;

    // Calculate payment amount - allow partial payments
    double paid;
    if (_isSplitPayment) {
      final safeCash =
          _cashAmount.isNaN || _cashAmount.isInfinite ? 0.0 : _cashAmount;
      final safeCard =
          _cardAmount.isNaN || _cardAmount.isInfinite ? 0.0 : _cardAmount;
      paid = _clampPaymentToTotal(safeCash + safeCard, total);
    } else {
      switch (_paymentType) {
        case 'card':
          final safeCard =
              _cardAmount.isNaN || _cardAmount.isInfinite ? 0.0 : _cardAmount;
          paid = safeCard > 0 ? _clampPaymentToTotal(safeCard, total) : total;
          break;
        case 'credit':
          final safeCredit = _creditAmount.isNaN || _creditAmount.isInfinite
              ? 0.0
              : _creditAmount;
          paid = safeCredit;
          break;
        case 'cash':
          final safeCash =
              _cashAmount.isNaN || _cashAmount.isInfinite ? 0.0 : _cashAmount;
          paid = safeCash > 0 ? _clampPaymentToTotal(safeCash, total) : total;
          break;
        default:
          paid = total;
          break;
      }
    }

    final due = total - paid;

    // Check credit limit if payment type is credit (khata credit)
    if (_paymentType == 'credit' && _selectedCustomer != null) {
      final customer = _selectedCustomer!;
      // Only check if customer has a credit limit set
      if (customer.creditLimit > 0) {
        // Calculate new total due after this order
        final newTotalDue = customer.totalDue + due;

        // Check if new total due exceeds credit limit
        if (newTotalDue > customer.creditLimit) {
          // Play error sound
          final audioSettings = ref.read(audioSettingsProvider);
          if (audioSettings.errorSoundEnabled) {
            final audioService = ref.read(audioServiceProvider);
            audioService.playErrorSound();
          }

          // Show toast message
          if (mounted) {
            AppSnackBar.show(
              context,
              SnackBar(
                content: Text(
                  'Order can\'t be punch due to credit limit exceed on khata credit',
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return; // Exit early, don't process the payment
        }
      }
    }

    // For partial payments (when paid < total but not credit), update status to 'partial'
    final saleStatus = due > 0
        ? (_paymentType == 'credit' ? SaleStatus.unpaid : SaleStatus.partial)
        : SaleStatus.paid;

    try {
      // Get current user for cashier tracking
      final authState = ref.read(authProvider);
      final currentUser = authState.currentUser;

      final sale = SaleModel(
        date: _selectedSaleDate,
        total: total,
        discount: discountAmount,
        paid: paid,
        due: due,
        customerId: _selectedCustomer?.id,
        cashierId: currentUser?.id, // Track who made the sale
        paymentType: _isSplitPayment
            ? PaymentType
                .cash // For split payments, we'll handle this differently
            : PaymentType.values.firstWhere(
                (e) => e.name == _paymentType,
                orElse: () => PaymentType.cash,
              ),
        status: saleStatus,
        dueDate: _paymentType == 'credit'
            ? _dueDate
            : null, // Set due date for credit sales
        isWholesale: _isWholesaleMode, // Track wholesale mode
        tableNumber: null,
        orderType: null,
        serviceCharge: null,
        tip: null,
        numberOfGuests: null,
        notes:
            _remarks.isNotEmpty ? _remarks : null, // Add remarks/notes to sale
        items: _expandCartItemsToSaleItems(cart),
        customer: _selectedCustomer,
        createdAt: _selectedSaleDate,
      );

      final saleNotifier = ref.read(saleNotifierProvider.notifier);
      final saleId = await saleNotifier.addSale(sale);
      final recordedSale = sale.copyWith(id: saleId);

      _lastCompletedSaleForReceipt = recordedSale;

      // Refresh the sale notifier state
      saleNotifier.refresh();

      // Invalidate all sales-related providers to refresh reports
      ref.invalidate(salesProvider);
      ref.invalidate(salesByDateRangeProvider);
      ref.invalidate(salesSummaryProvider);
      ref.invalidate(saleNotifierProvider);

      // Invalidate customer providers if this is a credit sale
      if (recordedSale.customerId != null) {
        final customerId = recordedSale.customerId!;
        ref.invalidate(customersProvider);
        ref.invalidate(customerNotifierProvider);
        ref.invalidate(customersWithDueProvider);
        ref.invalidate(customerByIdProvider(customerId));
        ref.invalidate(customerLedgerProvider(customerId));
        ref.invalidate(customerSalesProvider(customerId));
        ref.invalidate(customerPaymentsProvider(customerId));

        // Refresh customer in background - don't block payment processing
        Future.microtask(() async {
          try {
            final updatedCustomer = await ref.read(
              customerByIdProvider(customerId).future,
            );
            if (mounted &&
                updatedCustomer != null &&
                _selectedCustomer?.id == customerId) {
              setState(() {
                _selectedCustomer = updatedCustomer;
              });
            }
          } catch (e) {
            debugPrint('Failed to refresh customer after sale: $e');
            // Don't throw - this is non-critical
          }
        });
      }

      // Refresh product providers to update stock levels immediately
      ref.read(productNotifierProvider.notifier).refresh();

      // Play success sound
      final audioSettings = ref.read(audioSettingsProvider);
      if (audioSettings.successSoundEnabled) {
        final audioService = ref.read(audioServiceProvider);
        audioService.playSuccessSound();
      }

      if (mounted) {
        String paymentMessage = '';
        if (_isSplitPayment) {
          final safeCash =
              _cashAmount.isNaN || _cashAmount.isInfinite ? 0.0 : _cashAmount;
          final safeCard =
              _cardAmount.isNaN || _cardAmount.isInfinite ? 0.0 : _cardAmount;
          paymentMessage =
              'Cash: ${_formatCurrency(safeCash)}, Card: ${_formatCurrency(safeCard)}';
        } else {
          switch (_paymentType) {
            case 'card':
              paymentMessage = 'Card: ${_formatCurrency(paid)}';
              break;
            case 'credit':
              paymentMessage = paid > 0
                  ? 'Khata payment recorded: ${_formatCurrency(paid)}'
                  : 'Order recorded on Khata';
              break;
            default:
              paymentMessage = 'Cash: ${_formatCurrency(paid)}';
              break;
          }
        }

        // No auto-print and no auto-clear. Keep cart as-is after payment.
        // User can manually print or clear using the action buttons.
        setState(() {
          _payLocked = true; // lock pay until cart changes
          _isSaleComplete =
              true; // Prevent adding items until new bill is started
        });

        AppSnackBar.show(
          context,
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Payment Successful! $paymentMessage',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        );
      }
    } catch (e) {
      // Play error sound
      final audioSettings = ref.read(audioSettingsProvider);
      if (audioSettings.errorSoundEnabled) {
        final audioService = ref.read(audioServiceProvider);
        audioService.playErrorSound();
      }

      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              'pos.err_with_message'.tr(namedArgs: {'error': '$e'}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showReceiptPrintPrompt() async {
    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              const Icon(Icons.print, color: Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              Text('pos.print_receipt_q'.tr()),
            ],
          ),
          content: const Text(
            'Do you want to print the receipt?',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('common.no'.tr()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
              ),
              child: Text('common.yes'.tr()),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// Show split bill dialog to divide cart into multiple bills
  Future<void> _showSplitBillDialog(
    List<CartItem> cart,
    double total,
    Currency currency,
  ) async {
    if (cart.length < 2) {
      AppSnackBar.show(
        context,
        SnackBar(
          content: Text('pos.split_need_two'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Track which items are selected for each bill
    final selectedItemsForBill1 = <int>{};

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.call_split, color: Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              Text('pos.split_bill_title'.tr()),
            ],
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select items for Bill 1 (remaining items will go to Bill 2)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: cart.length,
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      final isSelected = selectedItemsForBill1.contains(index);
                      final itemTotal = item.subtotal;

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              selectedItemsForBill1.add(index);
                            } else {
                              selectedItemsForBill1.remove(index);
                            }
                          });
                        },
                        title: Text(
                          item.isBundle && item.bundle != null
                              ? item.bundle!.name
                              : (item.product?.name ?? 'Unknown'),
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          item.isBundle && item.bundle != null
                              ? '${_formatQuantityDisplay(item.quantity)} × ${_formatCurrency(item.bundle!.price)} = ${_formatCurrency(itemTotal)}'
                              : '${_formatQuantityDisplay(item.quantity)} × ${_formatCurrency(item.product?.price ?? 0.0)} = ${_formatCurrency(itemTotal)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                // Show totals preview
                Builder(
                  builder: (context) {
                    double bill1Total = 0;
                    double bill2Total = 0;

                    for (var i = 0; i < cart.length; i++) {
                      // Use _safeGetItemPrice to account for payment type
                      final basePrice = _safeGetItemPrice(cart[i]);
                      final safePrice = basePrice.isNaN || basePrice.isInfinite
                          ? 0.0
                          : basePrice;
                      final safeQuantity =
                          cart[i].quantity.isNaN || cart[i].quantity.isInfinite
                              ? 0.0
                              : cart[i].quantity;
                      final itemTotal = safePrice * safeQuantity;
                      if (selectedItemsForBill1.contains(i)) {
                        bill1Total += itemTotal;
                      } else {
                        bill2Total += itemTotal;
                      }
                    }

                    // Apply discount proportionally
                    final discountAmount = _discountType == 'percentage'
                        ? (total * _discount / 100)
                        : _discount;
                    final subtotalAfterDiscount = total - discountAmount;
                    final bill1Proportion =
                        bill1Total > 0 ? (bill1Total / total) : 0;
                    final bill1Discount = discountAmount * bill1Proportion;
                    final bill1SubtotalAfterDiscount =
                        bill1Total - bill1Discount;

                    // Get tax rate
                    final taxRate = ref.read(currentTaxRateProvider);
                    final bill1Tax = TaxCalculator.calculateTax(
                      bill1SubtotalAfterDiscount,
                      taxRate,
                    );
                    final bill1Final = bill1SubtotalAfterDiscount + bill1Tax;

                    final bill2Discount =
                        discountAmount * (1 - bill1Proportion);
                    final bill2SubtotalAfterDiscount =
                        bill2Total - bill2Discount;
                    final bill2Tax = TaxCalculator.calculateTax(
                      bill2SubtotalAfterDiscount,
                      taxRate,
                    );
                    final bill2Final = bill2SubtotalAfterDiscount + bill2Tax;

                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'pos.bill1_total'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _formatCurrency(bill1Final),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'pos.bill2_total'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _formatCurrency(bill2Final),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: selectedItemsForBill1.isEmpty ||
                      selectedItemsForBill1.length == cart.length
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _processSplitBills(
                        cart,
                        selectedItemsForBill1,
                        total,
                        currency,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
              ),
              child: Text('pos.split_process'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  /// Process split bills - create two separate sales
  Future<void> _processSplitBills(
    List<CartItem> cart,
    Set<int> bill1Indices,
    double originalTotal,
    Currency currency,
  ) async {
    try {
      // Separate items into two bills
      final bill1Items = <CartItem>[];
      final bill2Items = <CartItem>[];

      for (var i = 0; i < cart.length; i++) {
        if (bill1Indices.contains(i)) {
          bill1Items.add(cart[i]);
        } else {
          bill2Items.add(cart[i]);
        }
      }

      // Calculate totals for each bill
      double calculateBillTotal(List<CartItem> items) {
        final subtotal = items.fold(0.0, (sum, item) => sum + item.subtotal);
        final discountAmount = _discountType == 'percentage'
            ? (originalTotal * _discount / 100 * (subtotal / originalTotal))
            : (_discount * (subtotal / originalTotal));
        final subtotalAfterDiscount = subtotal - discountAmount;
        final taxRate = ref.read(currentTaxRateProvider);
        final taxAmount = TaxCalculator.calculateTax(
          subtotalAfterDiscount,
          taxRate,
        );
        return subtotalAfterDiscount + taxAmount;
      }

      final bill1Total = calculateBillTotal(bill1Items);
      final bill2Total = calculateBillTotal(bill2Items);

      // Get current user
      final authState = ref.read(authProvider);
      final currentUser = authState.currentUser;

      // Process Bill 1
      final sale1 = SaleModel(
        date: _selectedSaleDate,
        total: bill1Total,
        discount: _discountType == 'percentage'
            ? (originalTotal * _discount / 100 * (bill1Total / originalTotal))
            : (_discount * (bill1Total / originalTotal)),
        paid: bill1Total,
        due: 0,
        customerId: _selectedCustomer?.id,
        cashierId: currentUser?.id,
        paymentType: PaymentType.values.firstWhere(
          (e) => e.name == _paymentType,
          orElse: () => PaymentType.cash,
        ),
        status: SaleStatus.paid,
        isWholesale: _isWholesaleMode,
        notes: 'Split Bill - Part 1 of 2',
        items: _expandCartItemsToSaleItems(bill1Items),
        customer: _selectedCustomer,
        createdAt: _selectedSaleDate,
      );

      // Process Bill 2
      final sale2 = SaleModel(
        date: _selectedSaleDate,
        total: bill2Total,
        discount: _discountType == 'percentage'
            ? (originalTotal * _discount / 100 * (bill2Total / originalTotal))
            : (_discount * (bill2Total / originalTotal)),
        paid: bill2Total,
        due: 0,
        customerId: _selectedCustomer?.id,
        cashierId: currentUser?.id,
        paymentType: PaymentType.values.firstWhere(
          (e) => e.name == _paymentType,
          orElse: () => PaymentType.cash,
        ),
        status: SaleStatus.paid,
        isWholesale: _isWholesaleMode,
        notes: 'Split Bill - Part 2 of 2',
        items: _expandCartItemsToSaleItems(bill2Items),
        customer: _selectedCustomer,
        createdAt: _selectedSaleDate,
      );

      // Save both sales
      final saleNotifier = ref.read(saleNotifierProvider.notifier);
      final sale1Id = await saleNotifier.addSale(sale1);
      final sale2Id = await saleNotifier.addSale(sale2);

      // Refresh the sale notifier state
      saleNotifier.refresh();

      // Refresh providers
      ref.invalidate(salesProvider);
      ref.invalidate(salesByDateRangeProvider);
      ref.invalidate(salesSummaryProvider);
      ref.invalidate(saleNotifierProvider);
      ref.read(productNotifierProvider.notifier).refresh();

      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              'Bills split successfully! Bill 1: ${_formatCurrency(bill1Total)}, Bill 2: ${_formatCurrency(bill2Total)}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        // Don't clear cart - user must tap "New Bill" button to clear
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('pos.err_split_bills'.tr(namedArgs: {'error': '$e'})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle thermal printing with better user feedback
  Future<void> _handleThermalPrinting(SaleModel sale) async {
    try {
      final databaseService = ref.read(databaseServiceProvider);
      // Check printer status first using UnifiedPrintService
      final printerStatus = await UnifiedPrintService.getPrinterStatus(
        databaseService: databaseService,
      );

      if (printerStatus == PrinterConnectionStatus.notConfigured) {
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('pos.printer_skip_no_config'.tr()),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      if (printerStatus == PrinterConnectionStatus.disconnected) {
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('pos.printer_skip_disconnected'.tr()),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      if (printerStatus == PrinterConnectionStatus.error) {
        // Error checking printer - show toast
        debugPrint('Printer check error - skipping print');
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('pos.printer_skip_err'.tr()),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Printer is connected, proceed with printing
      await _autoPrintThermalReceipt(sale);
    } catch (e) {
      // Silently handle printer errors - don't crash the app
      debugPrint('Printer error (non-critical): $e');
      // Payment already completed, so we just skip printing
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              '⚠️ Printer error - receipt not printed. Payment completed successfully.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Show dialog when no printer is configured
  void _showNoPrinterDialog() {}

  /// Show dialog when printer is disconnected
  void _showPrinterDisconnectedDialog() {}

  /// Show dialog when printer fails during printing
  void _showPrinterFailedDialog(SaleModel sale, String? errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.print_disabled, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('pos.print_failed'.tr()),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment completed successfully, but receipt printing failed.',
              style: TextStyle(fontSize: 16),
            ),
            if (errorMessage != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Error: ${errorMessage.length > 100 ? errorMessage.substring(0, 100) + "..." : errorMessage}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            ],
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Order saved successfully. You can print the receipt later from Sales screen.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.ok'.tr()),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _retryPrintReceipt(sale);
            },
            icon: Icon(Icons.refresh),
            label: Text('pos.retry_print'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Retry printing receipt
  Future<void> _retryPrintReceipt(SaleModel sale) async {
    try {
      final databaseService = ref.read(databaseServiceProvider);
      // Check printer status first using UnifiedPrintService
      final printerStatus = await UnifiedPrintService.getPrinterStatus(
        databaseService: databaseService,
      );

      if (printerStatus != PrinterConnectionStatus.connected) {
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text(
                '⚠️ Printer is not connected. Please check printer settings.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Try printing again
      await _autoPrintThermalReceipt(sale);
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('pos.retry_failed'.tr(namedArgs: {'error': '$e'})),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Automatically print thermal receipt after payment
  Future<void> _autoPrintThermalReceipt(SaleModel sale) async {
    try {
      final databaseService = ref.read(databaseServiceProvider);

      // Try to print with unified service (with timeout to prevent hanging)
      bool success = false;
      String? errorMessage;
      try {
        // Use unified print service with auto-detection
        final settings = PrintSettings.getDefault().copyWith(
          printerType: PrinterType.auto,
          copies: 1,
          autoCut: true,
        );

        success = await UnifiedPrintService.printReceipt(
          sale,
          settings: settings,
          databaseService: databaseService,
        ).timeout(
          const Duration(
            seconds: 20,
          ), // Increased timeout for slow printers
          onTimeout: () {
            debugPrint(
              'Printer timeout - printing operation took too long',
            );
            errorMessage =
                'Printer connection timeout. Please check printer connection.';
            return false;
          },
        );
      } catch (printError) {
        debugPrint('Printer error: $printError');
        errorMessage = printError.toString();
        success = false;
      }

      if (success) {
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('pos.receipt_auto_printed'.tr()),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Printer failed - show dialog with retry option
        if (mounted) {
          _showPrinterFailedDialog(sale, errorMessage);
        }
      }
    } catch (e) {
      // Silently handle printer errors - payment already completed
      debugPrint('Auto print receipt error (non-critical): $e');
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              '⚠️ Receipt printing failed - but payment completed successfully',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showFindSaleDialog() {
    String searchQuery = '';
    final TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.65,
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    // Header with gradient
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.receipt_long,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Find & Search Sales',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Search through all your sales',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Search Field
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: TextField(
                                controller: searchController,
                                autofocus: true,
                                decoration: InputDecoration(
                                  hintText:
                                      'Search by Sale ID or Customer Name...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade500,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: Color(0xFF8B5CF6),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                onChanged: (value) {
                                  setDialogState(() {
                                    searchQuery = value.toLowerCase();
                                  });
                                },
                                onSubmitted: (value) {
                                  final async = ref.read(salesProvider);
                                  final data = async.hasValue
                                      ? (async.value ?? [])
                                      : <SaleModel>[];
                                  final q = value.toLowerCase();
                                  final numeric =
                                      RegExp(r'\d+').stringMatch(q) ?? '';
                                  final firstMatch = data.firstWhere(
                                    (sale) =>
                                        sale.id.toString().contains(q) ||
                                        ('sinvo-${sale.id}')
                                            .toLowerCase()
                                            .contains(q) ||
                                        (numeric.isNotEmpty &&
                                            sale.id.toString() == numeric) ||
                                        ((sale.customer?.name.toLowerCase() ??
                                                '')
                                            .contains(q)),
                                    orElse: () => null as dynamic,
                                  );
                                  if (firstMatch is SaleModel) {
                                    Navigator.pop(dialogContext);
                                    _showSaleDetailsFromFind(
                                      firstMatch,
                                      dialogContext,
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Sales List
                            Expanded(
                              child: Consumer(
                                builder: (context, ref, _) {
                                  return ref.watch(salesProvider).when(
                                        data: (sales) {
                                          final filtered = searchQuery.isEmpty
                                              ? List<SaleModel>.from(sales)
                                              : sales.where((sale) {
                                                  final q = searchQuery;
                                                  final invoice =
                                                      'sinvo-${sale.id}'
                                                          .toLowerCase();
                                                  final name = (sale
                                                          .customer?.name
                                                          .toLowerCase() ??
                                                      '');
                                                  final idStr =
                                                      sale.id.toString();
                                                  return idStr.contains(q) ||
                                                      invoice.contains(q) ||
                                                      name.contains(q);
                                                }).toList();

                                          // Sort by sale number (ID) in descending order (highest first)
                                          filtered.sort(
                                            (a, b) => (b.id ?? 0).compareTo(
                                              a.id ?? 0,
                                            ),
                                          );

                                          if (filtered.isEmpty) {
                                            return Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.receipt_long_outlined,
                                                    size: 64,
                                                    color: Colors.grey.shade300,
                                                  ),
                                                  const SizedBox(height: 16),
                                                  Text(
                                                    'No sales found',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }

                                          return ListView.builder(
                                            itemCount: filtered.length,
                                            itemBuilder: (context, index) {
                                              final sale = filtered[index];
                                              final isAdmin = ref
                                                      .read(authProvider)
                                                      .currentUser
                                                      ?.role ==
                                                  EmployeeRole.admin;
                                              return Container(
                                                margin: const EdgeInsets.only(
                                                  bottom: 12,
                                                ),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.grey.shade200,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.02),
                                                      blurRadius: 8,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: Material(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: InkWell(
                                                    onTap: () {
                                                      _showSaleDetailsFromFind(
                                                        sale,
                                                        dialogContext,
                                                      );
                                                    },
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      12,
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                        16,
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          // Sale ID Avatar
                                                          Container(
                                                            width: 56,
                                                            height: 56,
                                                            decoration:
                                                                BoxDecoration(
                                                              gradient:
                                                                  const LinearGradient(
                                                                colors: [
                                                                  Color(
                                                                    0xFF6366F1,
                                                                  ),
                                                                  Color(
                                                                    0xFF8B5CF6,
                                                                  ),
                                                                ],
                                                                begin: Alignment
                                                                    .topLeft,
                                                                end: Alignment
                                                                    .bottomRight,
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                12,
                                                              ),
                                                            ),
                                                            child: Center(
                                                              child: Text(
                                                                '${sale.id}',
                                                                style:
                                                                    const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 18,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 16,
                                                          ),
                                                          // Sale Info
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Row(
                                                                  children: [
                                                                    Text(
                                                                      'Sale #${sale.id}',
                                                                      style:
                                                                          const TextStyle(
                                                                        fontSize:
                                                                            16,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color:
                                                                            Color(
                                                                          0xFF1E293B,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 12,
                                                                    ),
                                                                    Container(
                                                                      padding:
                                                                          const EdgeInsets
                                                                              .symmetric(
                                                                        horizontal:
                                                                            8,
                                                                        vertical:
                                                                            4,
                                                                      ),
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        color: Colors
                                                                            .green
                                                                            .shade50,
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                          6,
                                                                        ),
                                                                        border:
                                                                            Border.all(
                                                                          color: Colors
                                                                              .green
                                                                              .shade200,
                                                                        ),
                                                                      ),
                                                                      child:
                                                                          Row(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        children: [
                                                                          Container(
                                                                            width:
                                                                                6,
                                                                            height:
                                                                                6,
                                                                            decoration:
                                                                                BoxDecoration(
                                                                              color: Colors.green.shade500,
                                                                              shape: BoxShape.circle,
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                4,
                                                                          ),
                                                                          Text(
                                                                            sale.status.name.toUpperCase(),
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 11,
                                                                              fontWeight: FontWeight.w600,
                                                                              color: Colors.green.shade700,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(
                                                                  height: 6,
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .person,
                                                                      size: 14,
                                                                      color: Colors
                                                                          .grey
                                                                          .shade600,
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 4,
                                                                    ),
                                                                    Text(
                                                                      sale.customer
                                                                              ?.name ??
                                                                          'pos.walk_in'
                                                                              .tr(),
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            14,
                                                                        color: Colors
                                                                            .grey
                                                                            .shade700,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(
                                                                  height: 4,
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .access_time,
                                                                      size: 14,
                                                                      color: Colors
                                                                          .grey
                                                                          .shade600,
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 4,
                                                                    ),
                                                                    Text(
                                                                      DateFormat(
                                                                        'dd MMM yyyy • hh:mm a',
                                                                      ).format(
                                                                        sale.date,
                                                                      ),
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            13,
                                                                        color: Colors
                                                                            .grey
                                                                            .shade600,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          // Actions
                                                          Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .end,
                                                                children: [
                                                                  Text(
                                                                    _formatCurrency(
                                                                      sale.total,
                                                                    ),
                                                                    style:
                                                                        const TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          16,
                                                                      color:
                                                                          Color(
                                                                        0xFF1E293B,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    sale.paymentType
                                                                        .name
                                                                        .toUpperCase(),
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      color: Colors
                                                                          .grey
                                                                          .shade500,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(
                                                                width: 12,
                                                              ),
                                                              _buildActionButton(
                                                                icon: Icons
                                                                    .repeat,
                                                                color: AppColors
                                                                    .primaryColor,
                                                                onPressed: () {
                                                                  Navigator.pop(
                                                                    dialogContext,
                                                                  );
                                                                  // Use a small delay to ensure dialog is fully closed and context is ready
                                                                  Future
                                                                      .delayed(
                                                                    const Duration(
                                                                      milliseconds:
                                                                          100,
                                                                    ),
                                                                    () {
                                                                      if (mounted) {
                                                                        _reorderSaleFromFind(
                                                                          sale,
                                                                        );
                                                                      }
                                                                    },
                                                                  );
                                                                },
                                                              ),
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                              if (isAdmin) ...[
                                                                _buildActionButton(
                                                                  icon: Icons
                                                                      .edit,
                                                                  color:
                                                                      const Color(
                                                                    0xFFF59E0B,
                                                                  ),
                                                                  onPressed:
                                                                      () async {
                                                                    // Store the sale reference before closing dialog
                                                                    final saleToEdit =
                                                                        sale;
                                                                    // Close the dialog first
                                                                    Navigator
                                                                        .pop(
                                                                      dialogContext,
                                                                    );
                                                                    // Wait for dialog to fully close
                                                                    await Future
                                                                        .delayed(
                                                                      const Duration(
                                                                        milliseconds:
                                                                            300,
                                                                      ),
                                                                    );
                                                                    if (mounted) {
                                                                      await _editSale(
                                                                        saleToEdit,
                                                                      );
                                                                    }
                                                                  },
                                                                ),
                                                                const SizedBox(
                                                                  width: 8,
                                                                ),
                                                              ],
                                                              _buildActionButton(
                                                                icon:
                                                                    Icons.print,
                                                                color:
                                                                    const Color(
                                                                  0xFF10B981,
                                                                ),
                                                                onPressed: () {
                                                                  Navigator.pop(
                                                                    dialogContext,
                                                                  );
                                                                  // Use a small delay to ensure dialog is fully closed and context is ready
                                                                  Future
                                                                      .delayed(
                                                                    const Duration(
                                                                      milliseconds:
                                                                          100,
                                                                    ),
                                                                    () {
                                                                      if (mounted) {
                                                                        _reprintSale(
                                                                          sale,
                                                                        );
                                                                      }
                                                                    },
                                                                  );
                                                                },
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                        loading: () => const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                        error: (error, stack) => Center(
                                          child: Text(
                                            'pos.err_with_message'.tr(
                                              namedArgs: {'error': '$error'},
                                            ),
                                          ),
                                        ),
                                      );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
      ),
    );
  }

  Future<void> _reprintSale(SaleModel sale) async {
    try {
      final printed = await _printSaleDirectThermal(sale);
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              printed
                  ? 'pos.receipt_printed'.tr()
                  : 'pos.print_fail_check_printer'.tr(),
            ),
            backgroundColor: printed ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              'pos.err_print_receipt'.tr(namedArgs: {'error': '$e'}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSaleDetailsFromFind(
    SaleModel sale,
    BuildContext findDialogContext,
  ) {
    final currency = ref.read(currentCurrencyProvider);

    // Load cashier if missing but cashierId exists
    Future<EmployeeModel?> loadCashier() async {
      if (sale.cashier != null) {
        return sale.cashier;
      }
      if (sale.cashierId != null) {
        final databaseService = ref.read(databaseServiceProvider);
        return await databaseService.getEmployeeById(sale.cashierId!);
      }
      return null;
    }

    showDialog(
      context: context,
      builder: (context) => FutureBuilder<EmployeeModel?>(
        future: loadCashier(),
        builder: (context, cashierSnapshot) {
          final cashier = cashierSnapshot.data ?? sale.cashier;
          final createdByName = _formatEmployeeName(cashier, sale.cashierId);
          final createdByRole = _formatEmployeeRoleLabel(cashier?.role);

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.5,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        color: Color(0xFF3B82F6),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sale #${sale.id}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'dd/MM/yyyy hh:mm a',
                              ).format(sale.date),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Created By Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.badge,
                          color: Color(0xFF6366F1),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Created By',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                createdByRole.isNotEmpty
                                    ? '$createdByName • $createdByRole'
                                    : createdByName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Customer Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person,
                          color: Color(0xFF3B82F6),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sale.customer?.name ?? 'pos.walk_in'.tr(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Items List
                  const Text(
                    'Items',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: sale.items.length,
                      itemBuilder: (context, index) {
                        final item = sale.items[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          item.product?.name ??
                                              'Unknown Product',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: (item.product?.isActive ==
                                                    false)
                                                ? Colors.grey
                                                : null,
                                          ),
                                        ),
                                      ),
                                      if (item.product?.isActive == false) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                            border: Border.all(
                                              color: Colors.red,
                                              width: 0.5,
                                            ),
                                          ),
                                          child: const Text(
                                            'Deleted',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Qty: ${item.qty.toStringAsFixed(2)}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    // Use the stored sale price, not the product's current price
                                    '${currency.symbol}${item.price.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    // Calculate subtotal from stored price: price * qty - discount
                                    // This ensures we use the actual sale price, not product's current price
                                    '${currency.symbol}${((item.price * item.qty) - item.discount).toStringAsFixed(2)}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Summary
                  const Divider(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow(
                          'Subtotal:',
                          sale.total - sale.discount,
                          currency,
                          false,
                        ),
                        if (sale.discount > 0)
                          _buildSummaryRow(
                            'Discount:',
                            -sale.discount,
                            currency,
                            true,
                          ),
                        _buildSummaryRow('Total:', sale.total, currency, false),
                      ],
                    ),
                  ),

                  // Remarks Section
                  if (sale.notes != null && sale.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.note,
                            color: Colors.amber.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Remarks',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  sale.notes!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Action Buttons
                  Builder(
                    builder: (context) {
                      final isAdmin =
                          ref.read(authProvider).currentUser?.role ==
                              EmployeeRole.admin;
                      return Row(
                        children: [
                          if (isAdmin) ...[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  // Store the sale reference before closing dialogs
                                  final saleToEdit = sale;

                                  // Close details dialog first
                                  Navigator.pop(context);

                                  // Close find dialog if still open
                                  if (findDialogContext.mounted) {
                                    Navigator.pop(findDialogContext);
                                  }

                                  // Wait for dialogs to fully close
                                  await Future.delayed(
                                    const Duration(milliseconds: 300),
                                  );

                                  // Now open edit dialog
                                  if (mounted) {
                                    await _editSale(saleToEdit);
                                  }
                                },
                                icon: const Icon(Icons.edit, size: 18),
                                label: Text('common.edit'.tr()),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFF59E0B),
                                  side: const BorderSide(
                                    color: Color(0xFFF59E0B),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pop(findDialogContext);
                                // Use a small delay to ensure dialogs are fully closed and context is ready
                                Future.delayed(
                                  const Duration(milliseconds: 100),
                                  () {
                                    if (mounted) {
                                      _reprintSale(sale);
                                    }
                                  },
                                );
                              },
                              icon: const Icon(Icons.print, size: 18),
                              label: Text('pos.reprint'.tr()),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF10B981),
                                side: const BorderSide(
                                  color: Color(0xFF10B981),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pop(findDialogContext);
                                // Use a small delay to ensure dialogs are fully closed and context is ready
                                Future.delayed(
                                  const Duration(milliseconds: 100),
                                  () {
                                    if (mounted) {
                                      _reorderSaleFromFind(sale);
                                    }
                                  },
                                );
                              },
                              icon: const Icon(Icons.repeat, size: 18),
                              label: Text('pos.reorder'.tr()),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryColor,
                                side: BorderSide(color: AppColors.primaryColor),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pop(findDialogContext);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B82F6),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: Text('common.close'.tr()),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double value,
    Currency currency,
    bool isDiscount,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          Text(
            '${currency.symbol}${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDiscount
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editSale(SaleModel sale) async {
    // Check if widget is still mounted before proceeding
    if (!mounted) return;

    // Load full sale with items first
    final saleAsync = ref.read(saleByIdProvider(sale.id!));

    // Wait for data to be available
    SaleModel? loadedSale;
    if (saleAsync.isLoading) {
      // Wait for data to load
      await Future.delayed(const Duration(milliseconds: 200));
      final refreshed = ref.read(saleByIdProvider(sale.id!));
      loadedSale = await refreshed.when(
        data: (sale) => sale,
        loading: () => null,
        error: (_, __) => null,
      );
    } else {
      loadedSale = await saleAsync.when(
        data: (sale) => sale,
        loading: () => null,
        error: (_, __) => null,
      );
    }

    // Wait a bit more to ensure previous dialog is fully closed
    await Future.delayed(const Duration(milliseconds: 100));

    if (loadedSale != null && mounted) {
      _showEditSaleDialog(loadedSale);
    } else if (mounted) {
      AppSnackBar.show(
        context,
        SnackBar(
          content: Text('pos.err_sale_details_load'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditSaleDialog(SaleModel sale) {
    // Check if widget is still mounted
    if (!mounted) return;

    final currency = ref.read(currentCurrencyProvider);
    Map<String, TextEditingController> priceControllers = {};
    Map<String, TextEditingController> quantityControllers = {};

    // Create a mutable copy of items
    List<SaleItemModel> editableItems = List.from(sale.items);

    // Initialize controllers for each item
    for (var item in editableItems) {
      final key = '${item.productId}_${item.id}';
      priceControllers[key] = TextEditingController(
        text: item.price.toStringAsFixed(2),
      );
      quantityControllers[key] = TextEditingController(
        text: item.qty.toStringAsFixed(2),
      );
    }

    // Show dialog directly - timing is handled by the caller
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(
                          Icons.edit,
                          color: Color(0xFFF59E0B),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Sale #${sale.id}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'dd/MM/yyyy hh:mm a',
                                ).format(sale.date),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Add Item Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showAddItemDialog(
                            sale,
                            editableItems,
                            priceControllers,
                            quantityControllers,
                            setDialogState,
                          );
                        },
                        icon: const Icon(Icons.add, size: 20),
                        label: Text('pos.add_item'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Items List
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: editableItems.length,
                        itemBuilder: (context, index) {
                          final item = editableItems[index];
                          final key = '${item.productId}_${item.id}';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          item.product?.name ??
                                              'Unknown Product',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          setDialogState(() {
                                            // Remove controllers
                                            priceControllers[key]?.dispose();
                                            quantityControllers[key]?.dispose();
                                            priceControllers.remove(key);
                                            quantityControllers.remove(key);
                                            // Remove item from the list
                                            editableItems.removeAt(index);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: quantityControllers[key],
                                          decoration: InputDecoration(
                                            labelText: 'Quantity',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                          ),
                                          keyboardType: const TextInputType
                                              .numberWithOptions(
                                            decimal: true,
                                          ),
                                          inputFormatters: [
                                            DecimalInputFormatter(
                                              maxDecimalPlaces: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextField(
                                          controller: priceControllers[key],
                                          decoration: InputDecoration(
                                            labelText: 'Price',
                                            prefixText: '${currency.symbol} ',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                          ),
                                          keyboardType: const TextInputType
                                              .numberWithOptions(
                                            decimal: true,
                                          ),
                                          inputFormatters: [
                                            DecimalInputFormatter(
                                              maxDecimalPlaces: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Action Buttons
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _deleteSale(sale);
                              Navigator.pop(dialogContext);
                            },
                            icon: const Icon(Icons.delete, size: 18),
                            label: Text('pos.delete_sale'.tr()),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // Save changes logic
                              await _saveSaleChanges(
                                sale,
                                editableItems,
                                priceControllers,
                                quantityControllers,
                                dialogContext,
                              );
                            },
                            icon: const Icon(Icons.save, size: 18),
                            label: Text('pos.save_changes'.tr()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showAddItemDialog(
    SaleModel sale,
    List<SaleItemModel> editableItems,
    Map<String, TextEditingController> priceControllers,
    Map<String, TextEditingController> quantityControllers,
    StateSetter setDialogState,
  ) {
    String searchQuery = '';

    // Use post-frame callback to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (productDialogContext) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.5,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              padding: const EdgeInsets.all(20),
              child: StatefulBuilder(
                builder: (context, setProductDialogState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          const Icon(
                            Icons.add_shopping_cart,
                            color: Color(0xFF3B82F6),
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Add Item to Sale',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                Navigator.pop(productDialogContext),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      // Search Field
                      TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'pos.hint_search_products'.tr(),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF3B82F6),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (value) {
                          setProductDialogState(() {
                            searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Products List
                      Expanded(
                        child: ref.watch(productsProvider).when(
                              data: (products) {
                                final filtered = searchQuery.isEmpty
                                    ? products
                                        .where(
                                          (p) =>
                                              p.id != null && p.price >= p.cost,
                                        )
                                        .toList()
                                    : products
                                        .where(
                                          (p) =>
                                              p.id != null &&
                                              p.price >= p.cost &&
                                              p.name.toLowerCase().contains(
                                                    searchQuery,
                                                  ),
                                        )
                                        .toList();

                                if (filtered.isEmpty) {
                                  return Center(
                                    child: Text('pos.no_products_found'.tr()),
                                  );
                                }

                                return ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final product = filtered[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: const Color(
                                            0xFF3B82F6,
                                          ).withOpacity(0.1),
                                          child: Text(
                                            product.name[0].toUpperCase(),
                                            style: const TextStyle(
                                              color: Color(0xFF3B82F6),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        title: Text(product.name),
                                        subtitle: Text(
                                          '${ref.read(currentCurrencyProvider).symbol}${product.price.toStringAsFixed(2)}',
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(
                                            Icons.add,
                                            color: Color(0xFF3B82F6),
                                          ),
                                          onPressed: () {
                                            // Add product to sale
                                            final newItem = SaleItemModel(
                                              id: null, // Will be assigned by database
                                              saleId: sale.id!,
                                              productId: product.id!,
                                              qty: 1,
                                              price: product.price,
                                              subtotal: product.price,
                                              discount: 0,
                                              createdAt: DateTime.now(),
                                              product: product,
                                            );

                                            final key =
                                                '${newItem.productId}_${DateTime.now().millisecondsSinceEpoch}';
                                            priceControllers[key] =
                                                TextEditingController(
                                              text: newItem.price
                                                  .toStringAsFixed(2),
                                            );
                                            quantityControllers[key] =
                                                TextEditingController(
                                              text: newItem.qty
                                                  .toStringAsFixed(2),
                                            );

                                            setDialogState(() {
                                              editableItems.add(newItem);
                                            });

                                            Navigator.pop(productDialogContext);
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (error, stack) => Center(
                                child: Text(
                                  'pos.err_with_message'.tr(
                                    namedArgs: {'error': '$error'},
                                  ),
                                ),
                              ),
                            ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      );
    });
  }

  Future<void> _saveSaleChanges(
    SaleModel sale,
    List<SaleItemModel> editableItems,
    Map<String, TextEditingController> priceControllers,
    Map<String, TextEditingController> quantityControllers,
    BuildContext dialogContext,
  ) async {
    try {
      // Build updated items
      List<SaleItemModel> updatedItems = [];
      double newTotal = 0;

      for (var item in editableItems) {
        final key = '${item.productId}_${item.id}';
        final newPrice =
            double.tryParse(priceControllers[key]?.text ?? '') ?? item.price;
        final newQty =
            double.tryParse(quantityControllers[key]?.text ?? '') ?? item.qty;
        final newSubtotal = newPrice * newQty;

        updatedItems.add(
          item.copyWith(qty: newQty, price: newPrice, subtotal: newSubtotal),
        );

        newTotal += newSubtotal;
      }

      // Apply discount if any
      final discountAmount = sale.discount;
      final finalTotal = newTotal - discountAmount;

      // Update sale
      final updatedSale = sale.copyWith(total: finalTotal, items: updatedItems);

      final saleNotifier = ref.read(saleNotifierProvider.notifier);
      await saleNotifier.updateSale(updatedSale);

      // Refresh the sale notifier state
      saleNotifier.refresh();

      // Refresh sales
      ref.invalidate(salesProvider);
      ref.invalidate(salesByDateRangeProvider);
      ref.invalidate(salesSummaryProvider);
      ref.invalidate(saleNotifierProvider);
      ref.invalidate(saleByIdProvider(sale.id!));
      ref.read(productNotifierProvider.notifier).refresh();
      ref.invalidate(productsProvider);

      Navigator.pop(dialogContext);

      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('pos.sale_updated_ok'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('pos.err_sale_update'.tr(namedArgs: {'error': '$e'})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSale(SaleModel sale) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Text('pos.delete_sale_q'.tr()),
          ],
        ),
        content: Text(
          'Are you sure you want to delete Sale #${sale.id}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final saleNotifier = ref.read(saleNotifierProvider.notifier);
        await saleNotifier.deleteSale(sale.id!);

        // Refresh the sale notifier state
        saleNotifier.refresh();

        // Refresh sales
        ref.invalidate(salesProvider);
        ref.invalidate(salesByDateRangeProvider);
        ref.invalidate(salesSummaryProvider);
        ref.invalidate(saleNotifierProvider);

        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text(
                'pos.sale_deleted_ok'.tr(namedArgs: {'id': '${sale.id}'}),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text(
                'pos.err_sale_delete'.tr(namedArgs: {'error': '$e'}),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _printReceipt(SaleModel sale) async {
    if (_isReceiptPrinting) {
      return;
    }
    setState(() {
      _isReceiptPrinting = true;
    });

    // Show loading dialog
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Printing receipt...',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please wait',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );

    try {
      final success = await _printSaleDirectThermal(sale);

      // Close loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (mounted) {
        if (success) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('pos.receipt_printed'.tr()),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('pos.print_fail_check_printer'.tr()),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              'pos.err_print_receipt'.tr(namedArgs: {'error': e.toString()}),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      debugPrint('Print error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isReceiptPrinting = false;
        });
      } else {
        _isReceiptPrinting = false;
      }
    }
  }

  Future<void> _shareReceipt(SaleModel sale) async {
    try {
      final databaseService = ref.read(databaseServiceProvider);
      await PdfService.generateAndShareReceipt(sale, databaseService);
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              'pos.err_share_receipt'.tr(namedArgs: {'error': '$e'}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reorderSaleFromFind(SaleModel sale) async {
    try {
      // Clear the current cart first
      ref.read(cartProvider.notifier).clear();

      final databaseService = ref.read(databaseServiceProvider);
      int addedCount = 0;
      int failedCount = 0;

      // Add each item from the sale to the cart
      for (final item in sale.items) {
        try {
          // Get the product - first check if product is already loaded in the item
          ProductModel? product;
          if (item.product != null) {
            product = item.product;
          } else {
            // Fetch product by ID
            product = await databaseService.getProductById(item.productId);
          }

          if (product != null && product.id != null) {
            // Add product to cart with the same quantity from the sale
            ref
                .read(cartProvider.notifier)
                .addProduct(product, quantity: item.qty);
            addedCount++;
          } else {
            failedCount++;
          }
        } catch (e) {
          failedCount++;
          debugPrint('Error adding product ${item.productId} to cart: $e');
        }
      }

      if (mounted) {
        // Show success message
        String message =
            'Added $addedCount item${addedCount != 1 ? 's' : ''} to cart';
        if (failedCount > 0) {
          message +=
              '. $failedCount item${failedCount != 1 ? 's' : ''} could not be added';
        }

        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(message),
            backgroundColor: failedCount > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              'pos.err_reorder'.tr(namedArgs: {'error': e.toString()}),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showThermalPrintOptions(SaleModel sale) async {
    try {
      // Show loading dialog with better design
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.search, color: Colors.blue),
              SizedBox(width: 12),
              Text('pos.finding_printers'.tr()),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Scanning for thermal printers...',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'This may take a few seconds',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );

      // Get available printers using UnifiedPrintService
      final printers = await UnifiedPrintService.getAvailableNetworkPrinters();

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (printers.isEmpty) {
        // Show manual IP input with helpful message
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text(
                'No printers found automatically. If your printer is connected via LAN (Ethernet) while you\'re on WiFi, they should work together if on the same network. Please enter the printer IP address manually.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 6),
            ),
          );
        }
        _showManualPrinterInput(sale);
      } else {
        // Show printer selection
        _showPrinterSelection(sale, printers);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              'pos.err_scan_printers'.tr(namedArgs: {'error': '$e'}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPrinterSelection(SaleModel sale, List<String> printers) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('pos.select_thermal'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('pos.available_printers'.tr()),
            const SizedBox(height: 16),
            ...printers.map(
              (printer) => ListTile(
                title: Text(printer),
                onTap: () {
                  Navigator.pop(context);
                  _printToThermalPrinter(sale, printer);
                },
              ),
            ),
            const Divider(),
            ListTile(
              title: Text('pos.enter_ip'.tr()),
              leading: const Icon(Icons.edit),
              onTap: () {
                Navigator.pop(context);
                _showManualPrinterInput(sale);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showManualPrinterInput(SaleModel sale) {
    final ipController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('pos.enter_printer_ip'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your printer\'s IP address. WiFi and LAN connections on the same network can communicate with each other.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            FutureBuilder<String?>(
              future: () async {
                try {
                  final networkInfo = NetworkInfo();
                  return await networkInfo.getWifiIP();
                } catch (e) {
                  return null;
                }
              }(),
              builder: (context, snapshot) {
                final deviceIP = snapshot.data ?? 'Unknown';
                final subnet = deviceIP.contains('.')
                    ? deviceIP.split('.').take(3).join('.')
                    : deviceIP;
                return Text(
                  'pos.device_ip_instructions'.tr(
                    namedArgs: {'deviceIp': deviceIP, 'subnet': subnet},
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ipController,
              decoration: InputDecoration(
                labelText: 'pos.printer_ip_field_label'.tr(),
                hintText: 'pos.hint_printer_ip_example'.tr(),
                border: const OutlineInputBorder(),
                helperText: 'pos.printer_ip_helper_line'.tr(),
                prefixIcon: const Icon(Icons.print),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              final ip = ipController.text.trim();
              if (ip.isNotEmpty) {
                Navigator.pop(context);
                _printToThermalPrinter(sale, ip);
              }
            },
            child: Text('common.print'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _printToThermalPrinter(SaleModel sale, String printerIp) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text('pos.printing_receipt'.tr()),
            ],
          ),
        ),
      );

      // Print receipt using UnifiedPrintService (business settings are automatically loaded)
      final databaseService = ref.read(databaseServiceProvider);
      final settings = PrintSettings.getDefault().copyWith(
        printerType: PrinterType.networkThermal,
        printerIp: printerIp,
        printerPort: 9100, // Default thermal printer port
        copies: 1,
      );
      final success = await UnifiedPrintService.printReceipt(
        sale,
        settings: settings,
        databaseService: databaseService,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (success) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('pos.receipt_printed_excl'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('pos.print_fail_short'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
              'pos.err_print_receipt'.tr(namedArgs: {'error': '$e'}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class CurrencyCounterWidget extends ConsumerStatefulWidget {
  final Currency currency;
  final Function(double)? onTotalCalculated;

  const CurrencyCounterWidget({
    super.key,
    required this.currency,
    this.onTotalCalculated,
  });

  @override
  ConsumerState<CurrencyCounterWidget> createState() =>
      _CurrencyCounterWidgetState();
}

class _CurrencyCounterWidgetState extends ConsumerState<CurrencyCounterWidget> {
  // Default denominations for common currencies (can be customized)
  final Map<double, TextEditingController> _banknoteControllers = {};
  final Map<double, FocusNode> _banknoteFocusNodes = {};

  // Common banknote denominations - optimized for grid layout
  // Desktop: 4 columns = 2 rows, Mobile: 2 columns = 4 rows
  final List<double> _banknoteDenominations = [
    5000,
    1000,
    500,
    100,
    50,
    20,
    10,
  ];

  @override
  void initState() {
    super.initState();
    // Initialize controllers for banknotes
    for (final denom in _banknoteDenominations) {
      _banknoteControllers[denom] = TextEditingController(text: '0');
      _banknoteFocusNodes[denom] = FocusNode(debugLabel: 'banknote_$denom');
    }
  }

  @override
  void dispose() {
    for (final controller in _banknoteControllers.values) {
      controller.dispose();
    }
    for (final node in _banknoteFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _updateQuantity(double denomination, int delta) {
    final controller = _banknoteControllers[denomination];
    if (controller != null) {
      final currentValue = int.tryParse(controller.text) ?? 0;
      final newValue = (currentValue + delta).clamp(0, 999999);
      controller.text = newValue.toString();
      setState(() {});
    }
  }

  double _calculateTotal() {
    double total = 0.0;
    _banknoteControllers.forEach((denomination, controller) {
      final quantity = int.tryParse(controller.text) ?? 0;
      total += denomination * quantity;
    });
    return total;
  }

  double get grandTotal => _calculateTotal();

  void _focusNextField(double denomination) {
    final denominations = _banknoteDenominations;
    final nodes = _banknoteFocusNodes;
    final currentIndex = denominations.indexOf(denomination);
    if (currentIndex == -1) return;
    final nextIndex = (currentIndex + 1) % denominations.length;
    final nextDenom = denominations[nextIndex];
    nodes[nextDenom]?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.currency;
    final grandTotal = _calculateTotal();
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width >= 1024;
    final isTablet = screenSize.width >= 768 && screenSize.width < 1024;
    final isMobile = screenSize.width < 768;

    // Responsive grid columns - adjust to fit without scroll
    final crossAxisCount = isDesktop
        ? 4
        : isTablet
            ? 3
            : 2;
    final spacing = isDesktop ? 12.0 : 8.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Compact header with total
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Currency Counter',
              style: TextStyle(
                fontSize: isDesktop ? 22 : 20,
                fontWeight: FontWeight.w700,
                color: Colors.grey[900],
              ),
            ),
            Row(
              children: [
                Text(
                  'Total: ',
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '${currency.symbol}${grandTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: isDesktop ? 20 : 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF059669),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Currency notes grid - no scroll, fits all
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: isDesktop ? 1.2 : 1.0,
          ),
          itemCount: _banknoteDenominations.length,
          itemBuilder: (context, index) {
            final denomination = _banknoteDenominations[index];
            return _buildDenominationCard(
              denomination: denomination,
              controller: _banknoteControllers[denomination]!,
              currency: currency,
              isDesktop: isDesktop,
            );
          },
        ),
        const SizedBox(height: 12),
        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                for (final controller in _banknoteControllers.values) {
                  controller.text = '0';
                }
                setState(() {});
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('common.reset'.tr()),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 20 : 16,
                  vertical: isDesktop ? 12 : 10,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context, grandTotal);
              },
              icon: const Icon(Icons.check, size: 18),
              label: Text(
                'pos.pay_use_total'.tr(
                  namedArgs: {
                    'amount':
                        '${currency.symbol}${grandTotal.toStringAsFixed(2)}',
                  },
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 24 : 20,
                  vertical: isDesktop ? 12 : 10,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDenominationCard({
    required double denomination,
    required TextEditingController controller,
    required Currency currency,
    required bool isDesktop,
  }) {
    final quantity = int.tryParse(controller.text) ?? 0;
    final total = denomination * quantity;
    final hasValue = quantity > 0;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 12 : 10),
      decoration: BoxDecoration(
        color: hasValue ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasValue ? const Color(0xFF34D399) : Colors.grey[300]!,
          width: hasValue ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Denomination label
          Text(
            '${currency.symbol}${denomination.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.w800,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 8),
          // Quantity controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Minus button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _updateQuantity(denomination, -1),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: isDesktop ? 40 : 36,
                    height: isDesktop ? 40 : 36,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.remove,
                      color: Color(0xFFDC2626),
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Quantity input
              SizedBox(
                width: isDesktop ? 70 : 60,
                child: TextField(
                  controller: controller,
                  focusNode: _banknoteFocusNodes[denomination],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(
                    fontSize: isDesktop ? 18 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: isDesktop ? 10 : 8,
                      horizontal: 4,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF34D399),
                        width: 2,
                      ),
                    ),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _focusNextField(denomination),
                ),
              ),
              const SizedBox(width: 8),
              // Plus button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _updateQuantity(denomination, 1),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: isDesktop ? 40 : 36,
                    height: isDesktop ? 40 : 36,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Color(0xFF059669),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Subtotal
          Text(
            '${currency.symbol}${total.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isDesktop ? 14 : 12,
              fontWeight: FontWeight.w600,
              color: hasValue ? const Color(0xFF065F46) : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF0369A1)),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
}

class CalculatorWidget extends StatefulWidget {
  const CalculatorWidget({super.key});

  @override
  _CalculatorWidgetState createState() => _CalculatorWidgetState();
}

class _CalculatorWidgetState extends State<CalculatorWidget> {
  String _display = '0';
  String _operation = '';
  double _firstNumber = 0;
  double _secondNumber = 0;
  bool _waitingForOperand = false;

  void _onButtonPressed(String buttonText) {
    setState(() {
      if (buttonText == 'C') {
        _display = '0';
        _operation = '';
        _firstNumber = 0;
        _secondNumber = 0;
        _waitingForOperand = false;
      } else if (buttonText == '⌫') {
        if (_display.length > 1) {
          _display = _display.substring(0, _display.length - 1);
        } else {
          _display = '0';
        }
      } else if (buttonText == '=') {
        if (_operation != '' && !_waitingForOperand) {
          _secondNumber = double.parse(_display);
          _display = _calculate().toString();
          _operation = '';
          _waitingForOperand = true;
        }
      } else if (['+', '-', '×', '÷'].contains(buttonText)) {
        if (_operation != '' && !_waitingForOperand) {
          _secondNumber = double.parse(_display);
          _display = _calculate().toString();
        }
        _firstNumber = double.parse(_display);
        _operation = buttonText;
        _waitingForOperand = true;
      } else {
        if (_waitingForOperand) {
          _display = buttonText;
          _waitingForOperand = false;
        } else {
          _display = _display == '0' ? buttonText : _display + buttonText;
        }
      }
    });
  }

  double _calculate() {
    switch (_operation) {
      case '+':
        return _firstNumber + _secondNumber;
      case '-':
        return _firstNumber - _secondNumber;
      case '×':
        return _firstNumber * _secondNumber;
      case '÷':
        return _secondNumber != 0 ? _firstNumber / _secondNumber : 0;
      default:
        return _secondNumber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _display,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              'C',
              '⌫',
              '÷',
              '×',
              '7',
              '8',
              '9',
              '-',
              '4',
              '5',
              '6',
              '+',
              '1',
              '2',
              '3',
              '=',
              '0',
              '0',
              '.',
              '=',
            ].map((buttonText) {
              return ElevatedButton(
                onPressed: () => _onButtonPressed(buttonText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getButtonColor(buttonText),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Color _getButtonColor(String buttonText) {
    if (['C', '⌫'].contains(buttonText)) {
      return Colors.red;
    } else if (['+', '-', '×', '÷', '='].contains(buttonText)) {
      return Colors.orange;
    } else {
      return Colors.blue;
    }
  }
}
