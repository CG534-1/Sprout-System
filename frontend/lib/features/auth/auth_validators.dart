String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Enter your email';
  if (!email.contains('@') || !email.contains('.')) {
    return 'Enter a valid email';
  }
  return null;
}

/// Sign in only needs something typed. Length rules belong on the pages that
/// create a password, so an existing account never sees a rule it cannot meet.
String? validatePassword(String? value) {
  if ((value ?? '').isEmpty) return 'Enter your password';
  return null;
}
