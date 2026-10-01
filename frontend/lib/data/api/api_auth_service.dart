import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/data/api/api_client.dart';
import 'package:sprout/data/api/auth_errors.dart';
import 'package:sprout/data/api/session_idle.dart';
import 'package:sprout/data/api/web_tab.dart';
import 'package:sprout/data/models/user_profile.dart';
import 'package:sprout/data/services/auth_service.dart';

class ApiAuthService extends AuthService {
  ApiAuthService(this._supabase, this._client);

  final SupabaseClient _supabase;
  final ApiClient _client;
  UserProfile? _user;
  var _splashSeen = false;
  var _replaySplashOnLaunch = false;
  var _splashPlayedThisLaunch = false;
  var _onboardingComplete = false;
  var _pendingSignup = false;
  var _resettingPassword = false;
  String? _pendingFirst;
  String? _pendingLast;
  String? _pendingEmail;
  StreamSubscription<AuthState>? _authSub;
  var _holdRouting = false;
  var _routingDirty = false;
  DateTime? _codeSentAt;
  var _sessionExpired = false;
  SharedPreferences? _prefs;
  Timer? _keepAlive;

  @override
  void holdRouting() => _holdRouting = true;

  @override
  void releaseRouting() {
    _holdRouting = false;
    if (!_routingDirty) return;
    _routingDirty = false;
    super.notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_holdRouting) {
      _routingDirty = true;
      return;
    }
    super.notifyListeners();
  }

  static const _splashKey = 'sprout.splash_seen';
  static const _onboardingKey = 'sprout.onboarding_complete';
  static const _activeKey = 'sprout.last_active';

  @override
  UserProfile? get currentUser => _user;

  @override
  bool get splashSeen => _replaySplashOnLaunch ? _splashPlayedThisLaunch : _splashSeen;

  @override
  bool get onboardingComplete => _onboardingComplete;

  @override
  bool get pendingSignup => _pendingSignup;

  @override
  String? get pendingFirst => _pendingFirst;

  @override
  String? get pendingLast => _pendingLast;

  @override
  String? get pendingEmail => _pendingEmail;

  @override
  bool get resettingPassword => _resettingPassword;

  @override
  DateTime? get codeSentAt => _codeSentAt;

  @override
  bool get sessionExpired => _sessionExpired;

  @override
  void clearSessionExpired() {
    if (!_sessionExpired) return;
    _sessionExpired = false;
  }

  @override
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _splashSeen = prefs.getBool(_splashKey) ?? false;
    _onboardingComplete = prefs.getBool(_onboardingKey) ?? false;
    final lastActive = prefs.getInt(_activeKey);
    _authSub = _supabase.auth.onAuthStateChange.listen((event) async {
      await _adoptSession();
    });
    if (_supabase.auth.currentSession != null) {
      await _adoptSession();
    }
    final idled = idledOut(
      lastActive: lastActive,
      signedIn: _user != null,
      midSetup: _pendingSignup || _resettingPassword,
    );
    if (idled) await _endStaleSession();
    final closedPage = kIsWeb && !webTabStillOpen();
    if (kIsWeb) markWebTabOpen();
    _replaySplashOnLaunch = _user != null && (!kIsWeb || closedPage);
    keepAlive();
    _keepAlive = Timer.periodic(const Duration(seconds: 45), (_) => keepAlive());
    notifyListeners();
  }

  Future<void> _endStaleSession() async {
    try {
      await _supabase.auth.signOut();
    } on AuthException {
      // The session is already gone on the server; the local state still goes.
    }
    _user = null;
    _pendingSignup = false;
    _resettingPassword = false;
    _pendingFirst = null;
    _pendingLast = null;
    _pendingEmail = null;
    _sessionExpired = true;
    _splashSeen = false;
  }

  @override
  void keepAlive() {
    _prefs?.setInt(_activeKey, DateTime.now().millisecondsSinceEpoch);
  }

  @override
  void dispose() {
    _keepAlive?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void markSplashSeen() {
    if (_replaySplashOnLaunch) {
      if (_splashPlayedThisLaunch) return;
      _splashPlayedThisLaunch = true;
      notifyListeners();
      return;
    }
    if (_splashSeen) return;
    _splashSeen = true;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) => prefs.setBool(_splashKey, true));
  }

  @override
  void completeOnboarding() {
    if (_onboardingComplete) return;
    _onboardingComplete = true;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) => prefs.setBool(_onboardingKey, true));
  }

  @override
  void reopenOnboarding() {
    if (!_onboardingComplete) return;
    _onboardingComplete = false;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) => prefs.setBool(_onboardingKey, false));
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _guard(() async {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.session == null) {
        throw const AppException(
          'Those details do not match an account. Check your email and password.',
        );
      }
      keepAlive();
      await _loadProfile();
    }, op: AuthOp.signIn);
  }

  @override
  Future<void> requestEmailConfirmation({
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    await _guard(() async {
      final first = firstName.trim();
      final last = lastName.trim();
      final trimmedEmail = email.trim();
      if (first.isEmpty || last.isEmpty) throw const AppException('Enter your name.');
      if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
        throw const AppException('Enter a valid email.');
      }
      await _supabase.auth.signInWithOtp(
        email: trimmedEmail,
        shouldCreateUser: true,
        data: {
          'name': '$first $last',
          'first_name': first,
          'last_name': last,
          'signup_pending': true,
        },
      );
      _markCodeSent();
    }, op: AuthOp.send);
  }

  @override
  Future<void> confirmEmailCode({required String email, required String code}) async {
    await _guard(() async {
      final token = code.trim();
      if (token.length != 6 || int.tryParse(token) == null) {
        throw const AppException('Enter the 6-digit code from your email.');
      }
      await _supabase.auth.verifyOTP(
        email: email.trim(),
        token: token,
        type: OtpType.email,
      );
      keepAlive();
      await _adoptSession();
    }, op: AuthOp.code);
  }

  @override
  Future<void> confirmRecoveryCode({required String email, required String code}) async {
    await _guard(() async {
      final token = code.trim();
      if (token.length != 6 || int.tryParse(token) == null) {
        throw const AppException('Enter the 6-digit code from your email.');
      }
      await _supabase.auth.verifyOTP(
        email: email.trim(),
        token: token,
        type: OtpType.recovery,
      );
      keepAlive();
      _resettingPassword = true;
      notifyListeners();
    }, op: AuthOp.code);
  }

  @override
  Future<void> requestEmailChange({required String email}) async {
    await _guard(() async {
      final trimmed = email.trim();
      if (trimmed.isEmpty || !trimmed.contains('@')) {
        throw const AppException('Enter a valid email.');
      }
      await _supabase.auth.updateUser(UserAttributes(email: trimmed));
      _markCodeSent();
    }, op: AuthOp.send);
  }

  @override
  Future<String?> confirmEmailChange({required String email, required String code}) async {
    await _guard(() async {
      final token = code.trim();
      if (token.length != 6 || int.tryParse(token) == null) {
        throw const AppException('Enter the 6-digit code from your email.');
      }
      await _supabase.auth.verifyOTP(
        email: email.trim(),
        token: token,
        type: OtpType.emailChange,
      );
      keepAlive();
    }, op: AuthOp.code);
    return _supabase.auth.currentUser?.email;
  }

  @override
  Future<void> resendEmailCode({
    required String email,
    required bool recovery,
    bool emailChange = false,
  }) async {
    await _guard(() async {
      final trimmed = email.trim();
      if (trimmed.isEmpty || !trimmed.contains('@')) {
        throw const AppException('Enter a valid email.');
      }
      if (emailChange) {
        await _supabase.auth.resend(type: OtpType.emailChange, email: trimmed);
        _markCodeSent();
        return;
      }
      if (recovery) {
        await _supabase.auth.resetPasswordForEmail(trimmed);
        _markCodeSent();
        return;
      }
      await _supabase.auth.signInWithOtp(
        email: trimmed,
        shouldCreateUser: true,
      );
      _markCodeSent();
    }, op: AuthOp.send);
  }

  @override
  Future<void> setNewPassword({required String password}) async {
    await _guard(() async {
      if (!_passwordStrong(password)) {
        throw const AppException(
          'Use 8+ characters with a number, a capital letter, and a symbol.',
        );
      }
      await _supabase.auth.updateUser(UserAttributes(password: password));
      // The recovery code signs the session in. Drop it so the new password
      // has to be used on the sign in page.
      await _supabase.auth.signOut();
      _resettingPassword = false;
      _user = null;
      keepAlive();
      notifyListeners();
    }, op: AuthOp.password);
  }

  bool _passwordStrong(String value) {
    return value.length >= 8 &&
        RegExp(r'\d').hasMatch(value) &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }

  void _markCodeSent() {
    _codeSentAt = DateTime.now();
    keepAlive();
  }

  @override
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    String? avatarUrl,
    Uint8List? avatarBytes,
  }) async {
    await _guard(() async {
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) throw const AppException('Enter your name.');
      if (_supabase.auth.currentSession == null) {
        throw const AppException(
          'Enter the code from your email, then create your password.',
        );
      }
      await _supabase.auth.updateUser(
        UserAttributes(
          password: password,
          data: {
            'name': trimmedName,
            'signup_pending': false,
            'password_set': true,
            if (avatarUrl != null) 'avatar': avatarUrl,
          },
        ),
      );
      await _saveDetails(
        name: trimmedName,
        email: email.trim(),
        avatarUrl: avatarUrl,
        avatarBytes: avatarBytes,
      );
      keepAlive();
    }, op: AuthOp.password);
    return false;
  }

  @override
  Future<void> updateDetails({
    required String name,
    required String email,
    String? avatarUrl,
    Uint8List? avatarBytes,
  }) async {
    await _guard(() async {
      final trimmedName = name.trim();
      final trimmedEmail = email.trim();
      if (trimmedName.isEmpty) throw const AppException('Enter your name.');
      if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
        throw const AppException('Enter a valid email.');
      }
      await _saveDetails(
        name: trimmedName,
        email: trimmedEmail,
        avatarUrl: avatarUrl,
        avatarBytes: avatarBytes,
      );
    });
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    await _guard(() async {
      final trimmed = email.trim();
      if (trimmed.isEmpty || !trimmed.contains('@')) {
        throw const AppException('Enter a valid email.');
      }
      await _supabase.auth.resetPasswordForEmail(trimmed);
      _markCodeSent();
    }, op: AuthOp.send);
  }

  @override
  Future<void> signOut() async {
    await _guard(() async {
      await _supabase.auth.signOut();
      _user = null;
      _pendingSignup = false;
      _resettingPassword = false;
      notifyListeners();
    });
  }

  @override
  Future<void> deleteAccount() async {
    await _guard(() async {
      await _client.send('DELETE', '/api/me');
      await _supabase.auth.signOut();
      _user = null;
      notifyListeners();
    });
  }

  Future<void> _saveDetails({
    required String name,
    required String email,
    String? avatarUrl,
    Uint8List? avatarBytes,
  }) async {
    String? avatarPath;
    if (avatarBytes != null) {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw const AppException('Sign in to continue.');
      avatarPath = '$userId/avatar.jpg';
      await _supabase.storage.from('care-media').uploadBinary(
        avatarPath,
        avatarBytes,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
    }
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      if (avatarPath != null) 'avatarPath': avatarPath,
      if (avatarPath == null && avatarUrl != null) 'avatarUrl': avatarUrl,
    };
    final data = await _client.send('PATCH', '/api/me', body: body);
    _pendingSignup = false;
    _user = UserProfile.fromJson(Map<String, dynamic>.from(data as Map));
    notifyListeners();
  }

  Future<void> _adoptSession() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _pendingSignup = false;
      _resettingPassword = false;
      _pendingFirst = null;
      _pendingLast = null;
      _pendingEmail = null;
      if (_user != null) {
        _user = null;
        notifyListeners();
      }
      return;
    }
    final meta = user.userMetadata ?? {};
    final pending = _flag(meta['signup_pending']) && !_flag(meta['password_set']);
    if (pending) {
      _user = null;
      _pendingSignup = true;
      _pendingFirst = meta['first_name']?.toString();
      _pendingLast = meta['last_name']?.toString();
      if ((_pendingFirst == null || _pendingFirst!.isEmpty) && meta['name'] != null) {
        final parts = meta['name'].toString().trim().split(RegExp(r'\s+'));
        _pendingFirst = parts.first;
        _pendingLast = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }
      _pendingEmail = user.email;
      notifyListeners();
      return;
    }
    _pendingSignup = false;
    await _loadProfile();
  }

  bool _flag(Object? value) => value == true || value == 'true';

  Future<void> _loadProfile() async {
    try {
      final data = await _client.send('GET', '/api/me');
      _user = UserProfile.fromJson(Map<String, dynamic>.from(data as Map));
      notifyListeners();
    } on AppException {
      _user = null;
      notifyListeners();
    }
  }

  Future<void> _guard(
    Future<void> Function() action, {
    AuthOp op = AuthOp.general,
  }) async {
    try {
      await action();
    } on AppException {
      rethrow;
    } on AuthException catch (error) {
      throw AppException(authErrorMessage(error, op));
    } on StorageException catch (error) {
      throw AppException('That photo could not be saved. ${error.message}');
    }
  }
}
