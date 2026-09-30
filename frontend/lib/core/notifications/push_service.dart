import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:sprout/core/config.dart';
import 'package:sprout/data/services/profile_service.dart';

@pragma('vm:entry-point')
Future<void> sproutBackgroundMessage(RemoteMessage message) async {}

class PushService {
  static var _started = false;

  static Future<void> start(ProfileService profile) async {
    final token = await _token(ask: false);
    if (token == null) return;
    await profile.registerDevice(token: token, platform: _platform);
  }

  static Future<void> enable(ProfileService profile) async {
    final token = await _token(ask: true);
    if (token == null) return;
    await profile.registerDevice(token: token, platform: _platform);
  }

  static String get _platform => kIsWeb ? 'web' : 'android';

  static Future<String?> _token({required bool ask}) async {
    final config = SproutConfig.fromEnvironment();
    if (!config.pushReady) return null;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: config.firebaseApiKey,
            appId: config.firebaseAppId,
            messagingSenderId: config.firebaseSenderId,
            projectId: config.firebaseProjectId,
          ),
        );
      }
      if (!_started && !kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(sproutBackgroundMessage);
        _started = true;
      }
      final messaging = FirebaseMessaging.instance;
      if (ask) await messaging.requestPermission();
      final settings = await messaging.getNotificationSettings();
      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed) return null;
      final vapid = config.firebaseVapidKey;
      return await messaging.getToken(vapidKey: kIsWeb && vapid.isNotEmpty ? vapid : null);
    } catch (_) {
      return null;
    }
  }
}
