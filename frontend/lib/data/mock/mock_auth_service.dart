import 'dart:typed_data';

import 'package:sprout/core/app_exception.dart';
import 'package:sprout/data/api/auth_errors.dart';
import 'package:sprout/data/mock/mock_store.dart';
import 'package:sprout/data/models/user_profile.dart';
import 'package:sprout/data/services/auth_service.dart';

class MockAuthService extends AuthService {
  MockAuthService(this._store);

  final MockStore _store;

  @override
  UserProfile? get currentUser => _store.currentUser;

  @override
  bool get onboardingComplete => _store.onboardingComplete;

  bool _splashSeen = false;

  @override
  bool get splashSeen => _splashSeen;

  @override
  void markSplashSeen() {
    if (_splashSeen) return;
    _splashSeen = true;
    notifyListeners();
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _store.pause();
    _requireCredentials(email, password);
    _rememberEmail(email);
    _store.currentUser = MockStore.demoProfile.copyWith(email: email.trim());
    notifyListeners();
  }

  DateTime? _codeSentAt;
  final _takenEmails = <String>{};

  @override
  DateTime? get codeSentAt => _codeSentAt;

  @override
  Future<void> requestEmailConfirmation({
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    await _store.pause();
    if (firstName.trim().isEmpty || lastName.trim().isEmpty) {
      throw const AppException('Enter your name.');
    }
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      throw const AppException('Enter a valid email.');
    }
    _rejectTakenEmail(trimmed);
    _codeSentAt = DateTime.now();
  }

  @override
  Future<void> confirmEmailCode({required String email, required String code}) async {
    await _store.pause();
    _requireCode(email, code);
  }

  @override
  Future<void> confirmRecoveryCode({required String email, required String code}) async {
    await _store.pause();
    _requireCode(email, code);
    _resettingPassword = true;
    notifyListeners();
  }

  @override
  Future<void> requestEmailChange({required String email}) async {
    await _store.pause();
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      throw const AppException('Enter a valid email.');
    }
    _codeSentAt = DateTime.now();
  }

  @override
  Future<String?> confirmEmailChange({required String email, required String code}) async {
    await _store.pause();
    _requireCode(email, code);
    return email.trim();
  }

  @override
  Future<void> resendEmailCode({
    required String email,
    required bool recovery,
    bool emailChange = false,
  }) async {
    await _store.pause();
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      throw const AppException('Enter a valid email.');
    }
    if (!recovery && !emailChange) {
      _rejectTakenEmail(trimmed);
    }
    _codeSentAt = DateTime.now();
  }

  @override
  Future<void> setNewPassword({required String password}) async {
    await _store.pause();
    if (!_strong(password)) {
      throw const AppException(
        'Use 8+ characters with a number, a capital letter, and a symbol.',
      );
    }
    _resettingPassword = false;
    _store.currentUser = null;
    notifyListeners();
  }

  bool _strong(String value) {
    return value.length >= 8 &&
        RegExp(r'\d').hasMatch(value) &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }

  var _resettingPassword = false;

  @override
  bool get resettingPassword => _resettingPassword;

  void _requireCode(String email, String code) {
    final token = code.trim();
    if (email.trim().isEmpty || token.length != 6 || int.tryParse(token) == null) {
      throw const AppException('Enter the 6-digit code from your email.');
    }
  }

  @override
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    String? avatarUrl,
    Uint8List? avatarBytes,
  }) async {
    await _store.pause();
    if (name.trim().isEmpty) {
      throw const AppException('Enter your name.');
    }
    _requireCredentials(email, password);
    _rememberEmail(email);
    _store.currentUser = UserProfile(
      id: MockStore.demoProfile.id,
      name: name.trim(),
      email: email.trim(),
      avatarUrl: avatarBytes == null ? avatarUrl : null,
      avatarBytes: avatarBytes,
    );
    notifyListeners();
    return false;
  }

  @override
  Future<void> updateDetails({
    required String name,
    required String email,
    String? avatarUrl,
    Uint8List? avatarBytes,
  }) async {
    await _store.pause();
    final current = _store.currentUser;
    if (current == null) {
      throw const AppException('Sign in to update your details.');
    }
    final trimmedName = name.trim();
    final trimmedEmail = email.trim();
    if (trimmedName.isEmpty) throw const AppException('Enter your name.');
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      throw const AppException('Enter a valid email.');
    }
    _store.currentUser = UserProfile(
      id: current.id,
      name: trimmedName,
      email: trimmedEmail,
      avatarUrl: avatarBytes == null ? avatarUrl : null,
      avatarBytes: avatarBytes,
    );
    notifyListeners();
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    await _store.pause();
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      throw const AppException('Enter a valid email.');
    }
    _codeSentAt = DateTime.now();
  }

  @override
  Future<void> signOut() async {
    await _store.pause();
    _store.currentUser = null;
    _resettingPassword = false;
    notifyListeners();
  }

  @override
  Future<void> deleteAccount() async {
    await signOut();
  }

  @override
  void completeOnboarding() {
    _store.onboardingComplete = true;
    notifyListeners();
  }

  @override
  void reopenOnboarding() {
    _store.onboardingComplete = false;
    notifyListeners();
  }

  void syncProfile(UserProfile profile) {
    _store.currentUser = profile;
    notifyListeners();
  }

  void _rememberEmail(String email) {
    _takenEmails.add(email.trim().toLowerCase());
  }

  void _rejectTakenEmail(String email) {
    if (_takenEmails.contains(email.trim().toLowerCase())) {
      throw const AppException(takenEmailMessage);
    }
  }

  void _requireCredentials(String email, String password) {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@') || password.length < 6) {
      throw const AppException(
        'Those details do not match an account. '
        'Check your email and password.',
      );
    }
  }
}
