// core/validators/validators.dart

import '../constants/app_strings.dart';
import '../utils/regex.dart';

abstract class AppValidators {
  static String? email(String? value) {
    if (value == null || value.isEmpty) return AppStrings.errorEmptyField;
    if (!AppRegex.email.hasMatch(value)) return AppStrings.errorInvalidEmail;
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return AppStrings.errorEmptyField;
    if (!AppRegex.password.hasMatch(value)) return AppStrings.errorWeakPassword;
    return null;
  }

  static String? username(String? value) {
    if (value == null || value.isEmpty) return AppStrings.errorEmptyField;
    if (!AppRegex.username.hasMatch(value)) {
      return 'Username must be 3–20 alphanumeric characters.';
    }
    return null;
  }

  static String? required(String? value) {
    if (value == null || value.isEmpty) return AppStrings.errorEmptyField;
    return null;
  }
}