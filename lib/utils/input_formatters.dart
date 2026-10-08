import 'package:flutter/services.dart';

/// Input formatter that only allows typing that matches product names
/// Users can only type text that matches the start of at least one product name
class ProductKeywordInputFormatter extends TextInputFormatter {
  final Set<String> allowedCharacters;
  final List<String> productNames; // List of all product names in lowercase

  ProductKeywordInputFormatter(this.allowedCharacters, {List<String>? productNames})
      : productNames = productNames?.map((n) => n.toLowerCase()).toList() ?? [];

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Always allow deletion and backspace
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    // If allowedCharacters is empty, block input until products load
    if (allowedCharacters.isEmpty) {
      return oldValue;
    }

    final newText = newValue.text.toLowerCase().trim();
    
    // If text is empty, allow it
    if (newText.isEmpty) {
      return newValue;
    }

    // Check each character in the new text
    for (int i = 0; i < newText.length; i++) {
      final char = newText[i];
      // Only allow if character exists in product names/barcodes/categories
      if (!allowedCharacters.contains(char)) {
        // Character not in any product name, reject it
        return oldValue;
      }
    }

    // If we have product names, check if the typed text matches the start of any product name
    if (productNames.isNotEmpty) {
      // Check if the typed text matches the start of any product name
      final matchesAnyProduct = productNames.any((productName) {
        // The typed text must match the start of a product name
        return productName.startsWith(newText);
      });
      
      if (!matchesAnyProduct) {
        // The typed text doesn't match the start of any product name, reject it
        return oldValue;
      }
    }

    // All characters are valid and text matches a product name, allow the input
    return newValue;
  }
}

/// Professional decimal input formatter with comprehensive validation
/// Handles decimal numbers with optional decimal place limits
/// Prevents invalid input and edge cases (e.g., multiple decimals, letters)
class DecimalInputFormatter extends TextInputFormatter {
  final int? maxDecimalPlaces;
  final bool allowNegative;

  DecimalInputFormatter({this.maxDecimalPlaces, this.allowNegative = false});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    try {
      final text = newValue.text;

      // Allow empty string for deletion
      if (text.isEmpty) {
        return newValue;
      }

      // Professional: Check for valid decimal number pattern
      // Allow: digits, single decimal point, optional negative sign, and valid decimal format
      final decimalPattern =
          allowNegative ? RegExp(r'^-?\d*\.?\d*$') : RegExp(r'^\d*\.?\d*$');

      if (!decimalPattern.hasMatch(text)) {
        return oldValue; // Reject invalid characters
      }

      // Professional: Prevent multiple negative signs
      if (allowNegative) {
        final negativeCount = '-'.allMatches(text).length;
        if (negativeCount > 1 ||
            (negativeCount == 1 && !text.startsWith('-'))) {
          return oldValue;
        }
      }

      // Professional: Prevent multiple decimal points
      final dotCount = '.'.allMatches(text).length;
      if (dotCount > 1) {
        return oldValue;
      }

      // Professional: Prevent leading zeros in decimal part (but allow negative)
      if (text.startsWith('0') && text.length > 1 && !text.startsWith('0.')) {
        // Allow "0." but not "01" or "02"
        if (text[1] != '.') {
          return oldValue;
        }
      }
      // Handle negative zero cases
      if (text.startsWith('-0') && text.length > 2 && !text.startsWith('-0.')) {
        if (text[2] != '.') {
          return oldValue;
        }
      }

      // Professional: Limit decimal places if specified
      if (maxDecimalPlaces != null && text.contains('.')) {
        final parts = text.split('.');
        if (parts.length == 2 && parts[1].length > maxDecimalPlaces!) {
          return oldValue;
        }
      }

      // Professional: Validate numeric value for NaN/Infinity
      final parsedValue = double.tryParse(text);
      if (parsedValue != null) {
        if (parsedValue.isNaN || parsedValue.isInfinite) {
          return oldValue;
        }
      }

      return newValue;
    } catch (e) {
      // Professional: Fallback to old value on any error
      return oldValue;
    }
  }
}

/// Professional integer input formatter with validation
/// Only allows whole numbers (no decimals, no negative by default)
class IntegerInputFormatter extends TextInputFormatter {
  final bool allowNegative;

  IntegerInputFormatter({this.allowNegative = false});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    try {
      final text = newValue.text;

      // Allow empty string for deletion
      if (text.isEmpty) {
        return newValue;
      }

      // Professional: Only allow digits (and optional negative sign)
      final pattern = allowNegative ? r'^-?\d+$' : r'^\d+$';
      if (RegExp(pattern).hasMatch(text)) {
        // Professional: Prevent multiple negative signs
        if (text.startsWith('-') && text.substring(1).contains('-')) {
          return oldValue;
        }
        return newValue;
      }

      return oldValue;
    } catch (e) {
      // Professional: Fallback to old value on any error
      return oldValue;
    }
  }
}

/// Custom formatter for phone number input
/// Allows digits, spaces, dashes, parentheses, and plus sign
class PhoneNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Allow empty string
    if (text.isEmpty) {
      return newValue;
    }

    // Allow digits, spaces, dashes, parentheses, plus sign, and parentheses
    if (RegExp(r'^[\d\s\-\(\)\+]*$').hasMatch(text)) {
      return newValue;
    }

    return oldValue;
  }
}

/// Custom formatter for phone number input (numbers only, no special characters)
class NumericPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Allow empty string
    if (text.isEmpty) {
      return newValue;
    }

    // Only allow digits
    if (RegExp(r'^\d+$').hasMatch(text)) {
      return newValue;
    }

    return oldValue;
  }
}
