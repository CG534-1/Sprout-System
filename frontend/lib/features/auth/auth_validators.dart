String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Enter your email';
  if (!email.contains('@') || !email.contains('.')) {
    return 'Enter a valid email';
  }
  return null;
}

String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Enter a password';
  if (password.length < 6) return 'Use at least 6 characters';
  return null;
}

String? validateRequired(String? value, String message) {
  if (value == null || value.trim().isEmpty) return message;
  return null;
}
