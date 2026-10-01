import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:sprout/data/models/user_profile.dart';

abstract class AuthService extends ChangeNotifier {
  UserProfile? get currentUser;

  bool get isSignedIn => currentUser != null;

  bool get onboardingComplete;

  /// True once the carousel is behind us. An account that exists, even a
  /// half-finished one, has already been past it, so the carousel never
  /// reappears mid sign up if the stored flag is missing.
  bool get pastOnboarding => onboardingComplete || isSignedIn || pendingSignup;

  bool get splashSeen;

  /// Email is confirmed, and the account is still waiting for a password.
  bool get pendingSignup => false;

  String? get pendingFirst => null;

  String? get pendingLast => null;

  String? get pendingEmail => null;

  bool get resettingPassword => false;

  /// When the last email code was sent, so a resend countdown survives
  /// leaving and returning to the code page.
  DateTime? get codeSentAt => null;

  /// True once a stale session has been dropped, so sign in can say why.
  bool get sessionExpired => false;

  void clearSessionExpired() {}

  /// Records that the person is still here, for the idle timeout.
  void keepAlive() {}

  /// Keeps the router from rebuilding the code page while a code is checked.
  void holdRouting() {}

  void releaseRouting() {}

  void markSplashSeen();

  Future<void> signIn({required String email, required String password});

  Future<void> requestEmailConfirmation({
    required String firstName,
    required String lastName,
    required String email,
  });

  Future<void> confirmEmailCode({required String email, required String code});

  Future<void> confirmRecoveryCode({required String email, required String code});

  Future<void> requestEmailChange({required String email});

  /// Returns the email on the session after the code is accepted.
  Future<String?> confirmEmailChange({required String email, required String code});

  Future<void> resendEmailCode({
    required String email,
    required bool recovery,
    bool emailChange = false,
  });

  Future<void> setNewPassword({required String password});

  /// Returns true when the account exists but the email still needs confirming.
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    String? avatarUrl,
    Uint8List? avatarBytes,
  });

  Future<void> updateDetails({
    required String name,
    required String email,
    String? avatarUrl,
    Uint8List? avatarBytes,
  });

  Future<void> sendPasswordReset({required String email});

  Future<void> signOut();

  Future<void> deleteAccount();

  Future<void> restore() async {}

  void completeOnboarding();

  void reopenOnboarding();
}
