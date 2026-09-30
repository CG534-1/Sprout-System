import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/data/api/api_client.dart';
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
  String? _pendingFirst;
  String? _pendingLast;
  String? _pendingEmail;
  StreamSubscription<AuthState>? _authSub;

  static const _apkConfirmRedirect = 'sprout://onboarding';
  static const _splashKey = 'sprout.splash_seen';
  static const _onboardingKey = 'sprout.onboarding_complete';
  static const _pendingOnboardingUserKey = 'sprout.pending_onboarding_user';

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
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _splashSeen = prefs.getBool(_splashKey) ?? false;
    _onboardingComplete = prefs.getBool(_onboardingKey) ?? false;
    _authSub = _supabase.auth.onAuthStateChange.listen((event) async {
      await _adoptSession();
    });
    if (_supabase.auth.currentSession != null) {
      await _adoptSession();
    }
    final closedPage = kIsWeb && !webTabStillOpen();
    if (kIsWeb) markWebTabOpen();
    _replaySplashOnLaunch = _user != null && (!kIsWeb || closedPage);
    notifyListeners();
  }

  @override
  void dispose() {
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
    final userId = _supabase.auth.currentUser?.id;
    SharedPreferences.getInstance().then((prefs) async {
      await prefs.setBool(_onboardingKey, true);
      if (_pendingSignup && userId != null) {
        await prefs.setString(_pendingOnboardingUserKey, userId);
      }
    });
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
        throw const AppException('Check your email and password.');
      }
      await _loadProfile();
    });
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
        emailRedirectTo: kIsWeb ? '${Uri.base.origin}/#/onboarding' : _apkConfirmRedirect,
        data: {
          'name': '$first $last',
          'first_name': first,
          'last_name': last,
          'signup_pending': true,
        },
      );
    });
  }

  @override
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    String? avatarUrl,
    Uint8List? avatarBytes,
  }) async {
    var needsConfirmation = false;
    await _guard(() async {
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) throw const AppException('Enter your name.');
      if (_supabase.auth.currentSession != null) {
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
        return;
      }
      AuthResponse response;
      try {
        response = await _supabase.auth.signUp(
          email: email.trim(),
          password: password,
          data: {
            'name': trimmedName,
            'signup_pending': false,
            'password_set': true,
            if (avatarUrl != null) 'avatar': avatarUrl,
          },
          emailRedirectTo: kIsWeb ? Uri.base.origin : null,
        );
      } on AuthException catch (error) {
        final message = error.message.toLowerCase();
        if (message.contains('already') || message.contains('registered')) {
          throw const AppException(
            'Open the confirmation link in your email, then create your password.',
          );
        }
        rethrow;
      }
      if (response.session == null) {
        needsConfirmation = true;
        return;
      }
      await _saveDetails(
        name: trimmedName,
        email: email.trim(),
        avatarUrl: avatarUrl,
        avatarBytes: avatarBytes,
      );
    });
    return needsConfirmation;
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
      if (_user != null && trimmedEmail != _user!.email) {
        await _supabase.auth.updateUser(UserAttributes(email: trimmedEmail));
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
    });
  }

  @override
  Future<void> signOut() async {
    await _guard(() async {
      await _supabase.auth.signOut();
      _user = null;
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
      final prefs = await SharedPreferences.getInstance();
      final seenFor = prefs.getString(_pendingOnboardingUserKey);
      if (seenFor != user.id && _onboardingComplete) {
        _onboardingComplete = false;
        await prefs.setBool(_onboardingKey, false);
      }
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

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on AppException {
      rethrow;
    } on AuthException catch (error) {
      throw AppException(error.message);
    } on StorageException catch (error) {
      throw AppException(error.message);
    }
  }
}
