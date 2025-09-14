/// X&Y Learning Platform validation utilities.
///
/// Provides common validation functions for forms and user input
/// throughout the app.
class XYValidators {
  XYValidators._(); // Private constructor to prevent instantiation

  /// Validates email format
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  /// Validates password strength
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }

    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }

    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    return null;
  }

  /// Validates that a field is not empty
  static String? required(String? value, [String fieldName = 'Field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates minimum length
  static String? minLength(String? value, int minLength, [String fieldName = 'Field']) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    if (value.length < minLength) {
      return '$fieldName must be at least $minLength characters long';
    }

    return null;
  }

  /// Validates maximum length
  static String? maxLength(String? value, int maxLength, [String fieldName = 'Field']) {
    if (value != null && value.length > maxLength) {
      return '$fieldName cannot exceed $maxLength characters';
    }
    return null;
  }

  /// Validates URL format
  static String? url(String? value) {
    if (value == null || value.isEmpty) {
      return 'URL is required';
    }

    try {
      final uri = Uri.parse(value);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        return 'Please enter a valid URL';
      }
    } catch (e) {
      return 'Please enter a valid URL';
    }

    return null;
  }

  /// Validates phone number format (basic)
  static String? phoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]+$');
    if (!phoneRegex.hasMatch(value) || value.length < 10) {
      return 'Please enter a valid phone number';
    }

    return null;
  }

  /// Validates that two values match (useful for confirm password)
  static String? match(String? value, String? compareValue, String fieldName) {
    if (value != compareValue) {
      return '$fieldName do not match';
    }
    return null;
  }

  /// Validates numeric input
  static String? numeric(String? value, [String fieldName = 'Field']) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    if (double.tryParse(value) == null) {
      return '$fieldName must be a valid number';
    }

    return null;
  }

  /// Validates integer input
  static String? integer(String? value, [String fieldName = 'Field']) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    if (int.tryParse(value) == null) {
      return '$fieldName must be a valid integer';
    }

    return null;
  }

  /// Combines multiple validators
  static String? Function(String?) combine(List<String? Function(String?)> validators) {
    return (String? value) {
      for (final validator in validators) {
        final result = validator(value);
        if (result != null) return result;
      }
      return null;
    };
  }

  /// Custom validator that accepts a function
  static String? Function(String?) custom(bool Function(String?) test, String errorMessage) {
    return (String? value) {
      if (!test(value)) {
        return errorMessage;
      }
      return null;
    };
  }
}