import 'package:flutter/foundation.dart';
import 'package:sprout/data/models/care_settings.dart';
import 'package:sprout/data/models/user_profile.dart';

abstract class ProfileService extends ChangeNotifier {
  Future<UserProfile> currentProfile();

  Future<UserProfile> updateProfile({required String name});

  Future<CareSettings> settings();

  Future<CareSettings> updateSettings(CareSettings settings);

  Future<void> registerDevice({required String token, required String platform});
}
