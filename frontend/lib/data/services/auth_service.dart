import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:sprout/data/models/user_profile.dart';

abstract class AuthService extends ChangeNotifier {
  UserProfile? get currentUser;

  bool get isSignedIn => currentUser != null;

  bool get onboardingComplete;

  bool get splashSeen;

  /// Email is confirmed, and the account is still waiting for a password.
  bool get pendingSignup => false;

  String? get pendingFirst => null;

  String? get pendingLast => null;

  String? get pendingEmail => null;

  bool get resettingPassword => false;

  void markSplashSeen();

  Future<void> signIn({required String email, required String password});

  Future<void> requestEmailConfirmation({
    required String firstName,
    required String lastName,
    required String email,
  });

  Future<void> confirmEmailCode({required String email, required String code});

  Future<void> confirmRecoveryCode({required String email, required String code});

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
