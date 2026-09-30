import 'dart:async';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/data/api/api_client.dart';
import 'package:sprout/data/models/user_profile.dart';
import 'package:sprout/data/services/auth_service.dart';

class ApiAuthService extends AuthService {
  ApiAuthService(this._supabase, this._client);

  final SupabaseClient _supabase;
  final ApiClient _client;
  UserProfile? _user;
  var _splashSeen = false;
  var _onboardingComplete = false;
  StreamSubscription<AuthState>? _authSub;

  static const _splashKey = 'sprout.splash_seen';
  static const _onboardingKey = 'sprout.onboarding_complete';

  @override
  UserProfile? get currentUser => _user;

  @override
  bool get splashSeen => _splashSeen;

  @override
  bool get onboardingComplete => _onboardingComplete;

  @override
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _splashSeen = prefs.getBool(_splashKey) ?? false;
    _onboardingComplete = prefs.getBool(_onboardingKey) ?? false;
    _authSub = _supabase.auth.onAuthStateChange.listen((event) async {
      if (event.session == null) {
        if (_user != null) {
          _user = null;
          notifyListeners();
        }
        return;
      }
      await _loadProfile();
    });
    if (_supabase.auth.currentSession != null) {
      await _loadProfile();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void markSplashSeen() {
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
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    String? avatarUrl,
    Uint8List? avatarBytes,
  }) async {
    await _guard(() async {
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) throw const AppException('Enter your name.');
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': trimmedName},
      );
      if (response.session == null) {
        throw const AppException('Confirm your email, then sign in.');
      }
      await _saveDetails(
        name: trimmedName,
        email: email.trim(),
        avatarUrl: avatarUrl,
        avatarBytes: avatarBytes,
      );
    });
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
    _user = UserProfile.fromJson(Map<String, dynamic>.from(data as Map));
    notifyListeners();
  }

  Future<void> _loadProfile() async {
    final data = await _client.send('GET', '/api/me');
    _user = UserProfile.fromJson(Map<String, dynamic>.from(data as Map));
    notifyListeners();
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
