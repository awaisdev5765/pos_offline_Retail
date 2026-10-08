import 'package:flutter/material.dart';

class ResponsiveFormLayout extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final List<FormSection> sections;
  final List<Widget> actions;
  final bool showProgress;
  final int currentStep;
  final int totalSteps;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  final bool isLoading;
  final bool showSaveButton;
  final bool showCancelButton;
  final String? saveButtonText;
  final String? cancelButtonText;

  const ResponsiveFormLayout({
    super.key,
    this.title,
    this.subtitle,
    required this.sections,
    this.actions = const [],
    this.showProgress = false,
    this.currentStep = 0,
    this.totalSteps = 0,
    this.onSave,
    this.onCancel,
    this.isLoading = false,
    this.showSaveButton = true,
    this.showCancelButton = true,
    this.saveButtonText = 'Save',
    this.cancelButtonText = 'Cancel',
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width >= 1024;
    final isTablet = screenSize.width >= 768 && screenSize.width < 1024;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          if (title != null || subtitle != null) _buildHeader(isDesktop),

          if (showProgress && totalSteps > 0) _buildProgressIndicator(),

          const SizedBox(height: 24),

          // Form content
          Expanded(
            child: isDesktop
                ? _buildDesktopLayout()
                : isTablet
                    ? _buildTabletLayout()
                    : _buildMobileLayout(),
          ),

          // Actions
          if (actions.isNotEmpty || showSaveButton || showCancelButton)
            _buildActions(isDesktop),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title!,
              style: TextStyle(
                fontSize: isDesktop ? 28 : 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step $currentStep of $totalSteps',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                '${((currentStep / totalSteps) * 100).round()}%',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: currentStep / totalSteps,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main form content
        Expanded(
          flex: 2,
          child: _buildFormContent(),
        ),
        const SizedBox(width: 24),
        // Sidebar with additional info
        Expanded(
          flex: 1,
          child: _buildSidebar(),
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Column(
      children: [
        _buildFormContent(),
        const SizedBox(height: 24),
        _buildSidebar(),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return _buildFormContent();
  }

  Widget _buildFormContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              sections.map((section) => _buildFormSection(section)).toList(),
        ),
      ),
    );
  }

  Widget _buildFormSection(FormSection section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.title != null) ...[
            Text(
              section.title!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            if (section.description != null)
              Text(
                section.description!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
            const SizedBox(height: 16),
          ],
          _buildFormFields(section.fields),
        ],
      ),
    );
  }

  Widget _buildFormFields(List<FormField> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = MediaQuery.of(context).size;
        final isDesktop = screenSize.width >= 1024;

        if (isDesktop) {
          // Desktop: Use grid layout for better space utilization
          final crossAxisCount = constraints.maxWidth > 1200 ? 3 : 2;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 3,
            ),
            itemCount: fields.length,
            itemBuilder: (context, index) => _buildFormField(fields[index]),
          );
        } else {
          // Mobile/Tablet: Use column layout
          return Column(
            children: fields
                .map((field) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildFormField(field),
                    ))
                .toList(),
          );
        }
      },
    );
  }

  Widget _buildFormField(FormField field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (field.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  field.label!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                if (field.required)
                  const Text(
                    ' *',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        if (field.hint != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              field.hint!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        field.widget,
        if (field.helperText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              field.helperText!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Tips',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            _buildTipItem(
              icon: Icons.keyboard,
              title: 'Keyboard Shortcuts',
              description: 'Use Ctrl+K for search, Ctrl+N for new items',
            ),
            const SizedBox(height: 12),
            _buildTipItem(
              icon: Icons.save,
              title: 'Auto Save',
              description: 'Your changes are automatically saved',
            ),
            const SizedBox(height: 12),
            _buildTipItem(
              icon: Icons.help,
              title: 'Need Help?',
              description: 'Press F1 or Ctrl+H for keyboard shortcuts',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment:
            isDesktop ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween,
        children: [
          if (showCancelButton)
            OutlinedButton(
              onPressed: isLoading ? null : onCancel,
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Text(cancelButtonText ?? 'Cancel'),
            ),
          if (showCancelButton && (showSaveButton || actions.isNotEmpty))
            const SizedBox(width: 12),
          ...actions,
          if (showSaveButton) ...[
            if (actions.isNotEmpty) const SizedBox(width: 12),
            ElevatedButton(
              onPressed: isLoading ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(saveButtonText ?? 'Save'),
            ),
          ],
        ],
      ),
    );
  }
}

class FormSection {
  final String? title;
  final String? description;
  final List<FormField> fields;

  const FormSection({
    this.title,
    this.description,
    required this.fields,
  });
}

class FormField {
  final String? label;
  final String? hint;
  final String? helperText;
  final Widget widget;
  final bool required;

  const FormField({
    this.label,
    this.hint,
    this.helperText,
    required this.widget,
    this.required = false,
  });
}

// Helper widget for creating form fields
class FormFieldBuilder {
  static Widget textField({
    required TextEditingController controller,
    String? label,
    String? hint,
    String? helperText,
    bool required = false,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
      ),
    );
  }

  static Widget dropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    String? label,
    String? hint,
    String? helperText,
    bool required = false,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
      ),
    );
  }

  static Widget datePicker({
    required DateTime? value,
    required void Function(DateTime?) onChanged,
    String? label,
    String? hint,
    String? helperText,
    bool required = false,
  }) {
    return Builder(
      builder: (BuildContext context) => InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime(2100),
          );
          if (date != null) {
            onChanged(date);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFFF8FAFC),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today,
                  size: 20, color: Color(0xFF64748B)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value != null
                      ? '${value.day}/${value.month}/${value.year}'
                      : hint ?? 'Select date',
                  style: TextStyle(
                    color: value != null
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
            ],
          ),
        ),
      ),
    );
  }
}
