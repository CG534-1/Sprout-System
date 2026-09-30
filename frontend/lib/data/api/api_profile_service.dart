import 'package:sprout/data/api/api_client.dart';
import 'package:sprout/data/models/care_settings.dart';
import 'package:sprout/data/models/user_profile.dart';
import 'package:sprout/data/services/profile_service.dart';

class ApiProfileService extends ProfileService {
  ApiProfileService(this._client);

  final ApiClient _client;

  @override
  Future<UserProfile> currentProfile() async {
    final data = await _client.send('GET', '/api/me');
    return UserProfile.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<UserProfile> updateProfile({required String name}) async {
    final current = await currentProfile();
    final data = await _client.send(
      'PATCH',
      '/api/me',
      body: {'name': name, 'email': current.email},
    );
    notifyListeners();
    return UserProfile.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<CareSettings> settings() async {
    final data = await _client.send('GET', '/api/me/settings');
    return CareSettings.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<CareSettings> updateSettings(CareSettings settings) async {
    final data = await _client.send('PUT', '/api/me/settings', body: settings.toJson());
    notifyListeners();
    return CareSettings.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<void> registerDevice({required String token, required String platform}) async {
    await _client.send(
      'POST',
      '/api/devices',
      body: {'token': token, 'platform': platform},
    );
  }
}
