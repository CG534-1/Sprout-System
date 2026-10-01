import 'package:sprout/core/app_exception.dart';
import 'package:sprout/data/mock/mock_auth_service.dart';
import 'package:sprout/data/mock/mock_store.dart';
import 'package:sprout/data/models/care_settings.dart';
import 'package:sprout/data/models/push_note.dart';
import 'package:sprout/data/models/user_profile.dart';
import 'package:sprout/data/services/profile_service.dart';

class MockProfileService extends ProfileService {
  MockProfileService(this._store, this._auth);

  final MockStore _store;
  final MockAuthService _auth;
  CareSettings _settings = CareSettings.defaults;

  @override
  Future<UserProfile> currentProfile() async {
    await _store.pause();
    final user = _store.currentUser;
    if (user == null) {
      throw const AppException('Sign in to view your profile.');
    }
    return user;
  }

  @override
  Future<UserProfile> updateProfile({required String name}) async {
    await _store.pause();
    final current = _store.currentUser;
    if (current == null) {
      throw const AppException('Sign in to update your profile.');
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const AppException('Enter your name.');
    final updated = current.copyWith(name: trimmed);
    _auth.syncProfile(updated);
    notifyListeners();
    return updated;
  }

  @override
  Future<CareSettings> settings() async {
    await _store.pause();
    return _settings;
  }

  @override
  Future<CareSettings> updateSettings(CareSettings settings) async {
    await _store.pause();
    _settings = settings;
    notifyListeners();
    return _settings;
  }

  @override
  Future<void> registerDevice({required String token, required String platform}) async {}

  @override
  Future<List<PushNote>> notifications() async {
    await _store.pause();
    return const [];
  }

  @override
  Future<void> markNotificationsRead() async {}
}
