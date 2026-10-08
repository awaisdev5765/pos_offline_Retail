import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/theme_provider.dart';
import '../models/supplier.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/input_formatters.dart';
import '../utils/mobile_optimization.dart';
import '../utils/touch_optimization.dart';
import '../widgets/app_snack_bar.dart';

class AddSupplierScreen extends ConsumerStatefulWidget {
  final int? supplierId;

  const AddSupplierScreen({super.key, this.supplierId});

  @override
  ConsumerState<AddSupplierScreen> createState() => _AddSupplierScreenState();
}

class _AddSupplierScreenState extends ConsumerState<AddSupplierScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _creditLimitController = TextEditingController();
  final _creditDaysController = TextEditingController();
  final _paymentTermsController = TextEditingController();
  final _notesController = TextEditingController();
  final _otherContact1Controller = TextEditingController();
  final _otherContact2Controller = TextEditingController();
  final _otherContact3Controller = TextEditingController();

  // FocusNodes for Enter key navigation (Windows-style)
  final _nameFocusNode = FocusNode();
  final _codeFocusNode = FocusNode();
  final _contactPersonFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _addressFocusNode = FocusNode();
  final _stateFocusNode = FocusNode();
  final _countryFocusNode = FocusNode();
  final _zipCodeFocusNode = FocusNode();
  final _creditLimitFocusNode = FocusNode();
  final _creditDaysFocusNode = FocusNode();
  final _paymentTermsFocusNode = FocusNode();
  final _notesFocusNode = FocusNode();
  final _otherContact1FocusNode = FocusNode();
  final _otherContact2FocusNode = FocusNode();
  final _otherContact3FocusNode = FocusNode();

  bool _isActive = true;
  bool _isLoading = false;
  bool _isInitializing = false;
  SupplierModel? _existingSupplier;

  @override
  void initState() {
    super.initState();
    print('AddSupplierScreen: initState supplierId=${widget.supplierId}');
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _codeController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _zipCodeController.dispose();
    _creditLimitController.dispose();
    _creditDaysController.dispose();
    _paymentTermsController.dispose();
    _notesController.dispose();
    _otherContact1Controller.dispose();
    _otherContact2Controller.dispose();
    _otherContact3Controller.dispose();

    // Dispose FocusNodes
    _nameFocusNode.dispose();
    _codeFocusNode.dispose();
    _contactPersonFocusNode.dispose();
    _phoneFocusNode.dispose();
    _addressFocusNode.dispose();
    _stateFocusNode.dispose();
    _countryFocusNode.dispose();
    _zipCodeFocusNode.dispose();
    _creditLimitFocusNode.dispose();
    _creditDaysFocusNode.dispose();
    _paymentTermsFocusNode.dispose();
    _notesFocusNode.dispose();
    _otherContact1FocusNode.dispose();
    _otherContact2FocusNode.dispose();
    _otherContact3FocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    if (!mounted) return;
    setState(() => _isInitializing = true);
    try {
      if (widget.supplierId != null) {
        await _loadSupplier();
      } else {
        _paymentTermsController.text = '30 days';
        await _initializeDefaultCode();
      }
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _loadSupplier() async {
    if (widget.supplierId == null) return;

    try {
      final supplier = await ref
          .read(supplierByIdProvider(widget.supplierId!).future)
          .timeout(const Duration(seconds: 10));

      if (supplier == null) {
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('Supplier not found'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _existingSupplier = supplier;
        _nameController.text = supplier.name;
        _codeController.text = supplier.code;
        _contactPersonController.text = supplier.contactPerson;
        _phoneController.text = supplier.phone;
        _addressController.text = supplier.address ?? '';
        _stateController.text = supplier.state ?? '';
        _countryController.text = supplier.country ?? '';
        _zipCodeController.text = supplier.zipCode ?? '';
        _creditLimitController.text = supplier.creditLimit.toString();
        _creditDaysController.text = supplier.creditDays.toString();
        _paymentTermsController.text = supplier.paymentTerms;
        _notesController.text = supplier.notes ?? '';
        _otherContact1Controller.text = supplier.otherContact1 ?? '';
        _otherContact2Controller.text = supplier.otherContact2 ?? '';
        _otherContact3Controller.text = supplier.otherContact3 ?? '';
        _isActive = supplier.isActive;
      });
    } catch (e) {
      debugPrint('AddSupplierScreen: supplier load failed: $e');
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error loading supplier: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _initializeDefaultCode() async {
    try {
      final code =
          await ref.read(databaseServiceProvider).generateSupplierCode();
      if (!mounted) return;
      _codeController.text = code;
    } catch (e) {
      debugPrint('AddSupplierScreen: code generation failed: $e');
      // Fall back to static code if generation fails
      final fallback = (DateTime.now().millisecondsSinceEpoch % 10000)
          .toString()
          .padLeft(4, '0');
      _codeController.text = 'SUP-$fallback';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobileDevice = MobileOptimization.isMobile(context);
    final isEditing = widget.supplierId != null;

    final isDarkMode = ref.watch(isDarkModeProvider);
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _isInitializing
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
            slivers: [
              _buildAppBar(isEditing),
              SliverPadding(
                  padding: MobileOptimization.getResponsivePadding(context),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                      _buildForm(isMobileDevice),
                  ]),
                ),
              ),
            ],
          ),
      ),
    );
  }

  Widget _buildAppBar(bool isEditing) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: isDarkMode ? AppColors.surfaceDark : Colors.white,
      elevation: 0,
      leading: MobileOptimization.mobileIconButton(
        icon: Icons.arrow_back,
        onPressed: () {
          if (mounted) {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/suppliers');
            }
          }
        },
        color: Colors.white,
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF4F46E5), Color(0xFF4338CA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          isEditing ? Icons.edit : Icons.add,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? 'Edit Supplier' : 'Add Supplier',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Roboto',
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isEditing
                                  ? 'Update supplier information'
                                  : 'Add a new supplier to your system',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withValues(alpha: 0.9),
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          onPressed: () {
                            if (mounted) {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/suppliers');
                              }
                            }
                          },
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(bool isMobile) {
    final fieldSpacing = MobileOptimization.getFormFieldSpacing(context);
    
    final isDarkMode = ref.watch(isDarkModeProvider);
    return Container(
      padding: MobileOptimization.getCardPadding(context),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic Information Section
            _buildSectionHeader('Basic Information'),
            SizedBox(height: fieldSpacing),
            // Stack fields on mobile, side-by-side on desktop
            isMobile
                ? Column(
                    children: [
                      _buildTextField(
                        controller: _codeController,
                        focusNode: _codeFocusNode,
                        label: 'Supplier Code',
                        hint: 'e.g., SUP-2312',
                        icon: Icons.tag,
                        isRequired: true,
                        onSubmitted: () => _nameFocusNode.requestFocus(),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return 'Supplier code is required';
                          }
                          if (!RegExp(r'^[A-Za-z0-9\-_]+$').hasMatch(trimmed)) {
                            return 'Use only letters, numbers, hyphen, or underscore';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: fieldSpacing),
                      _buildTextField(
                        controller: _nameController,
                        focusNode: _nameFocusNode,
                        label: 'Supplier Name',
                        hint: 'Enter supplier name',
                        icon: Icons.business,
                        onSubmitted: () => _contactPersonFocusNode.requestFocus(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Supplier name is required';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: fieldSpacing),
                      _buildTextField(
                        controller: _contactPersonController,
                        focusNode: _contactPersonFocusNode,
                        label: 'Contact Person',
                        hint: 'Enter contact person name',
                        icon: Icons.person,
                        onSubmitted: () => _phoneFocusNode.requestFocus(),
                      ),
                      SizedBox(height: fieldSpacing),
                      _buildTextField(
                        controller: _phoneController,
                        focusNode: _phoneFocusNode,
                        label: 'Phone Number',
                        hint: 'Enter phone number',
                        icon: Icons.phone,
                        keyboardType: TextInputType.number,
                        onSubmitted: () => _addressFocusNode.requestFocus(),
                        inputFormatters: [
                          NumericPhoneInputFormatter(),
                          LengthLimitingTextInputFormatter(15),
                        ],
                      ),
                    ],
                  )
                : Column(
                    children: [
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _codeController,
                    focusNode: _codeFocusNode,
                    label: 'Supplier Code',
                    hint: 'e.g., SUP-2312',
                    icon: Icons.tag,
                    isRequired: true,
                    onSubmitted: () => _nameFocusNode.requestFocus(),
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.isEmpty) {
                        return 'Supplier code is required';
                      }
                      if (!RegExp(r'^[A-Za-z0-9\-_]+$').hasMatch(trimmed)) {
                        return 'Use only letters, numbers, hyphen, or underscore';
                      }
                      return null;
                    },
                  ),
                ),
                          SizedBox(
                            width: MobileOptimization.getResponsiveSpacing(
                              context,
                              mobile: 12,
                              tablet: 16,
                              desktop: 16,
                            ),
                          ),
                Expanded(
                  child: _buildTextField(
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    label: 'Supplier Name',
                    hint: 'Enter supplier name',
                    icon: Icons.business,
                    onSubmitted: () => _contactPersonFocusNode.requestFocus(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Supplier name is required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
                      SizedBox(height: fieldSpacing),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _contactPersonController,
                    focusNode: _contactPersonFocusNode,
                    label: 'Contact Person',
                    hint: 'Enter contact person name',
                    icon: Icons.person,
                    onSubmitted: () => _phoneFocusNode.requestFocus(),
                  ),
                ),
                          SizedBox(
                            width: MobileOptimization.getResponsiveSpacing(
                              context,
                              mobile: 12,
                              tablet: 16,
                              desktop: 16,
                            ),
                          ),
                Expanded(
                  child: _buildTextField(
                    controller: _phoneController,
                    focusNode: _phoneFocusNode,
                    label: 'Phone Number',
                    hint: 'Enter phone number',
                    icon: Icons.phone,
                    keyboardType: TextInputType.number,
                    onSubmitted: () => _addressFocusNode.requestFocus(),
                    inputFormatters: [
                      NumericPhoneInputFormatter(),
                      LengthLimitingTextInputFormatter(15),
                    ],
                  ),
                ),
              ],
            ),
                    ],
                  ),
            SizedBox(height: fieldSpacing * 1.5),

            // Address Information Section
            _buildSectionHeader('Address Information'),
            SizedBox(height: fieldSpacing),
            _buildTextField(
              controller: _addressController,
              focusNode: _addressFocusNode,
              label: 'Address',
              hint: 'Enter street address',
              icon: Icons.location_on,
              onSubmitted: () => FocusScope.of(context).unfocus(),
            ),
            SizedBox(height: fieldSpacing * 1.5),
            // Business Information Section
            _buildSectionHeader('Business Information'),
            SizedBox(height: fieldSpacing),
            _buildTextField(
                    controller: _creditDaysController,
                    focusNode: _creditDaysFocusNode,
                    label: 'Credit Days',
                    hint: 'Enter credit days',
                    icon: Icons.calendar_today,
                    keyboardType: TextInputType.number,
                    onSubmitted: () => _paymentTermsFocusNode.requestFocus(),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
            SizedBox(height: fieldSpacing),
            _buildTextField(
              controller: _paymentTermsController,
              focusNode: _paymentTermsFocusNode,
              label: 'Payment Terms',
              hint: 'e.g., 30 days',
              icon: Icons.schedule,
              onSubmitted: () => _notesFocusNode.requestFocus(),
            ),
            SizedBox(height: fieldSpacing),
            _buildTextField(
              controller: _notesController,
              focusNode: _notesFocusNode,
              label: 'Notes',
              hint: 'Enter any additional notes',
              icon: Icons.note,
              maxLines: isMobile ? 3 : 2,
              onSubmitted: () => _otherContact1FocusNode.requestFocus(),
            ),
            SizedBox(height: fieldSpacing * 1.5),

            // Company Other Contacts Section
            _buildSectionHeader('Company Other Contacts'),
            SizedBox(height: fieldSpacing),
            _buildTextField(
              controller: _otherContact1Controller,
              focusNode: _otherContact1FocusNode,
              label: 'Name',
              hint: 'Enter contact name',
              icon: Icons.person,
              onSubmitted: () => _otherContact2FocusNode.requestFocus(),
            ),
            SizedBox(height: fieldSpacing),
            _buildTextField(
              controller: _otherContact2Controller,
              focusNode: _otherContact2FocusNode,
              label: 'Name',
              hint: 'Enter contact name',
              icon: Icons.person,
              onSubmitted: () => _otherContact3FocusNode.requestFocus(),
            ),
            SizedBox(height: fieldSpacing),
            _buildTextField(
              controller: _otherContact3Controller,
              focusNode: _otherContact3FocusNode,
              label: 'Name',
              hint: 'Enter contact name',
              icon: Icons.person,
              textInputAction: TextInputAction.done,
              onSubmitted: () => FocusScope.of(context).unfocus(),
            ),
            SizedBox(height: fieldSpacing * 1.5),

            // Status Section
            _buildSectionHeader('Status'),
            SizedBox(height: fieldSpacing),
            Container(
              padding: MobileOptimization.getCardPadding(context),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    _isActive ? Icons.check_circle : Icons.cancel,
                    color: _isActive
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    size: MobileOptimization.getResponsiveIconSize(
                      context,
                      mobile: 20,
                      tablet: 22,
                      desktop: 24,
                    ),
                  ),
                  SizedBox(
                    width: MobileOptimization.getResponsiveSpacing(
                      context,
                      mobile: 12,
                      tablet: 14,
                      desktop: 16,
                    ),
                  ),
                  Expanded(
                    child: Text(
                    _isActive ? 'Active Supplier' : 'Inactive Supplier',
                    style: TextStyle(
                        fontSize: MobileOptimization.getResponsiveFontSize(
                          context,
                          mobile: 15,
                          tablet: 16,
                          desktop: 16,
                        ),
                      fontWeight: FontWeight.w600,
                      color: _isActive
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                  ),
                  Switch(
                    value: _isActive,
                    onChanged: (value) {
                      if (mounted) {
                        setState(() {
                          _isActive = value;
                        });
                      }
                    },
                    activeThumbColor: const Color(0xFF10B981),
                  ),
                ],
              ),
            ),
            SizedBox(height: fieldSpacing * 2),

            // Action Buttons
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MobileOptimization.mobileButton(
                        onPressed: _isLoading ? null : _saveSupplier,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.supplierId != null
                                    ? 'Update Supplier'
                                    : 'Add Supplier',
                              ),
                        backgroundColor: const Color(0xFF6366F1),
                        isFullWidth: true,
                      ),
                      SizedBox(height: fieldSpacing),
                      OutlinedButton(
                        onPressed: _isLoading ? null : _handleCancel,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: Size(
                            double.infinity,
                            MobileOptimization.isMobile(context)
                                ? TouchOptimization.recommendedTouchTarget
                                : 40,
                          ),
                          padding: MobileOptimization.isMobile(context)
                              ? TouchOptimization.getTouchPadding()
                              : const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _handleCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                      SizedBox(
                        width: MobileOptimization.getResponsiveSpacing(
                          context,
                          mobile: 12,
                          tablet: 16,
                          desktop: 16,
                        ),
                      ),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveSupplier,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            widget.supplierId != null
                                ? 'Update Supplier'
                                : 'Add Supplier',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: MobileOptimization.getResponsiveFontSize(
          context,
          mobile: 18,
          tablet: 20,
          desktop: 22,
        ),
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1E293B),
        fontFamily: 'Roboto',
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    bool isRequired = false,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    VoidCallback? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
                fontFamily: 'Roboto',
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction ?? TextInputAction.next,
          onFieldSubmitted: onSubmitted != null ? (_) => onSubmitted() : null,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF6366F1)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: MobileOptimization.getTextFieldPadding(context),
          ),
        ),
      ],
    );
  }

  void _handleCancel() {
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/suppliers');
      }
    }
  }

  Future<void> _saveSupplier() async {
    // Check permissions
    final authState = ref.read(authProvider);
    final currentUser = authState.currentUser;
    
    if (widget.supplierId == null) {
      // Adding new supplier
      if (currentUser?.canAddSupplier() != true) {
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('You do not have permission to add suppliers.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    } else {
      // Editing existing supplier
      if (currentUser?.canEditSupplier() != true) {
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('You do not have permission to edit suppliers.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }
    
    // Removed validation to prevent errors
    // Basic check for supplier name
    if (_nameController.text.trim().isEmpty) {
      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Please enter supplier name'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final code = _codeController.text.trim();
    if (code.isEmpty) {
      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Please enter supplier code'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final now = DateTime.now();
      final supplier = SupplierModel(
        id: widget.supplierId,
        name: _nameController.text.trim(),
        code: code.toUpperCase(),
        contactPerson: _contactPersonController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        state: _stateController.text.trim().isEmpty
            ? null
            : _stateController.text.trim(),
        country: _countryController.text.trim().isEmpty
            ? null
            : _countryController.text.trim(),
        zipCode: _zipCodeController.text.trim().isEmpty
            ? null
            : _zipCodeController.text.trim(),
        creditLimit: double.tryParse(_creditLimitController.text) ?? 0.0,
        currentBalance: _existingSupplier?.currentBalance ?? 0.0,
        creditDays: int.tryParse(_creditDaysController.text) ?? 0,
        unclearCheque: _existingSupplier?.unclearCheque ?? 0.0,
        paymentTerms: _paymentTermsController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        otherContact1: _otherContact1Controller.text.trim().isEmpty
            ? null
            : _otherContact1Controller.text.trim(),
        otherContact2: _otherContact2Controller.text.trim().isEmpty
            ? null
            : _otherContact2Controller.text.trim(),
        otherContact3: _otherContact3Controller.text.trim().isEmpty
            ? null
            : _otherContact3Controller.text.trim(),
        isActive: _isActive,
        createdAt: _existingSupplier?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.supplierId != null) {
        await ref
            .read(supplierNotifierProvider.notifier)
            .updateSupplier(supplier);
        // Invalidate all supplier-related providers to refresh the UI
        ref.invalidate(supplierNotifierProvider);
        ref.invalidate(supplierByIdProvider(widget.supplierId!));
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('Supplier updated successfully'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } else {
        await ref.read(supplierNotifierProvider.notifier).addSupplier(supplier);
        // Invalidate all supplier-related providers to refresh the UI
        ref.invalidate(supplierNotifierProvider);
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('Supplier added successfully'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }

      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/suppliers');
        }
      }
    } catch (error) {
      debugPrint('AddSupplierScreen: save failed: $error');
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error saving supplier: $error'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
