import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/bank_provider.dart';
import '../providers/auth_provider.dart';
import '../models/bank.dart';
import '../widgets/app_snack_bar.dart';

class AddBankScreen extends ConsumerStatefulWidget {
  final int? bankId;

  const AddBankScreen({super.key, this.bankId});

  @override
  ConsumerState<AddBankScreen> createState() => _AddBankScreenState();
}

class _AddBankScreenState extends ConsumerState<AddBankScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _accountNumberController = TextEditingController();

  // FocusNodes for Enter key navigation (Windows-style)
  final _nameFocusNode = FocusNode();
  final _codeFocusNode = FocusNode();
  final _accountNumberFocusNode = FocusNode();

  // Form state
  bool _isActive = true;
  bool _isLoading = false;
  BankModel? _existingBank;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    if (widget.bankId != null) {
      _loadBank();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _codeController.dispose();
    _accountNumberController.dispose();

    // Dispose FocusNodes
    _nameFocusNode.dispose();
    _codeFocusNode.dispose();
    _accountNumberFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadBank() async {
    if (widget.bankId == null) return;

    // Use addPostFrameCallback to defer setState until after build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final bank = await ref.read(bankByIdProvider(widget.bankId!).future);
        if (bank != null && mounted) {
          setState(() {
            _existingBank = bank;
            _nameController.text = bank.name;
            _codeController.text = bank.code;
            _accountNumberController.text = bank.accountNumber ?? '';
            _isActive = bank.isActive;
          });
        }
      } catch (error) {
        if (mounted) {
          // Use maybeOf to safely get ScaffoldMessenger
          final messenger = ScaffoldMessenger.maybeOf(context);
          if (messenger != null) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Error loading bank: $error'),
                backgroundColor: const Color(0xFFEF4444),
              ),
            );
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentUser = authState.currentUser;

    // Check permission if editing (not adding new)
    if (widget.bankId != null &&
        currentUser != null &&
        !currentUser.canManageBanks()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text(
                  'You do not have permission to edit banking. Only administrators or managers with permission can edit banking.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          context.go('/banking-system');
        }
      });
      return Scaffold(
        appBar: AppBar(
          title: Text('common.access_denied'.tr()),
        ),
        body: Center(
          child: Text('banking.no_permission_body'.tr()),
        ),
      );
    }
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverPadding(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildFormCard(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF2563EB), Color(0xFF1D4ED8)],
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
                        child: const Icon(
                          Icons.account_balance,
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
                              widget.bankId != null
                                  ? 'banking.hero_edit_bank'.tr()
                                  : 'banking.hero_add_bank'.tr(),
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
                              widget.bankId != null
                                  ? 'banking.subtitle_edit_bank'.tr()
                                  : 'banking.subtitle_add_bank'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w500,
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
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
            const Text(
              'Bank Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: 24),

            // Basic Information Section
            _buildSectionHeader('Basic Information'),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    label: 'Bank Name *',
                    hint: 'Enter bank name',
                    icon: Icons.account_balance,
                    onSubmitted: () => _codeFocusNode.requestFocus(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Bank name is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _codeController,
                    focusNode: _codeFocusNode,
                    label: 'Bank Code *',
                    hint: 'Enter bank code',
                    icon: Icons.code,
                    onSubmitted: () => _accountNumberFocusNode.requestFocus(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Bank code is required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildTextField(
              controller: _accountNumberController,
              focusNode: _accountNumberFocusNode,
              label: 'Account Number',
              hint: 'Enter account number',
              icon: Icons.credit_card,
              textInputAction: TextInputAction.done,
              onSubmitted: () => FocusScope.of(context).unfocus(),
            ),

            const SizedBox(height: 24),

            // Status Section
            _buildSectionHeader('Status'),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    title: Text(
                      'banking.switch_active'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                    subtitle: Text(
                      'banking.switch_active_sub'.tr(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    value: _isActive,
                    onChanged: (value) {
                      if (mounted) {
                        setState(() {
                          _isActive = value;
                        });
                      }
                    },
                    activeColor: const Color(0xFF10B981),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _handleCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveBank,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
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
                            widget.bankId != null ? 'Update Bank' : 'Add Bank',
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
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E293B),
        fontFamily: 'Roboto',
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    VoidCallback? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction ?? TextInputAction.next,
          onFieldSubmitted: onSubmitted != null ? (_) => onSubmitted() : null,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF3B82F6)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  void _handleCancel() {
    // Use post-frame callback to avoid setState during build errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/banking-system');
        }
      }
    });
  }

  Future<void> _saveBank() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      final bank = BankModel(
        id: widget.bankId,
        name: _nameController.text.trim(),
        code: _codeController.text.trim(),
        accountNumber: _accountNumberController.text.trim().isEmpty
            ? null
            : _accountNumberController.text.trim(),
        branch: _existingBank?.branch,
        address: null,
        phone: null,
        email: null,
        currentBalance: _existingBank?.currentBalance ?? 0.0,
        isActive: _isActive,
        createdAt: _existingBank?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.bankId != null) {
        await ref.read(bankNotifierProvider.notifier).updateBank(bank);
      } else {
        await ref.read(bankNotifierProvider.notifier).addBank(bank);
      }

      // Refresh all bank-related providers for real-time updates
      ref.invalidate(bankNotifierProvider);
      ref.invalidate(bankNotifierProvider);
      ref.invalidate(allBankPaymentsProvider);
      ref.invalidate(activeBanksProvider);

      if (mounted) {
        // Show success message before navigation
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(widget.bankId != null
                  ? 'Bank updated successfully'
                  : 'Bank added successfully'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }

        // Navigate back - don't reset loading state before navigation
        // Use post-frame callback to ensure navigation happens after SnackBar
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/banking-system');
            }
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Use maybeOf to safely get ScaffoldMessenger
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error saving bank: $error'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }
}
