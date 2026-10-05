import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:sprout/core/config.dart';
import 'package:sprout/core/notifications/local_push.dart';
import 'package:sprout/data/services/profile_service.dart';

@pragma('vm:entry-point')
Future<void> sproutBackgroundMessage(RemoteMessage message) async {}

class PushService {
  static var _started = false;
  static var _refreshBound = false;
  static var _asked = false;
  static var _foregroundBound = false;
  static final _local = createLocalPush();

  static Future<void> start(ProfileService profile) async {
    try {
      final settings = await profile.settings();
      if (!settings.wantsPush) {
        _listenRefresh(profile);
        return;
      }
    } catch (_) {}
    await enable(profile);
  }

  static void reset() {
    _asked = false;
  }

  static Future<void> enable(ProfileService profile) async {
    final token = await _token(ask: true);
    if (token != null) {
      await profile.registerDevice(token: token, platform: _platform);
    }
    _listenRefresh(profile);
    _listenForeground();
  }

  static String get _platform => kIsWeb ? 'web' : 'android';

  static void _listenRefresh(ProfileService profile) {
    if (_refreshBound || Firebase.apps.isEmpty) return;
    _refreshBound = true;
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      profile.registerDevice(token: token, platform: _platform);
    });
  }

  static void _listenForeground() {
    if (_foregroundBound || kIsWeb || Firebase.apps.isEmpty) return;
    _foregroundBound = true;
    FirebaseMessaging.onMessage.listen((message) async {
      final note = message.notification;
      if (note == null) return;
      await _local.show(
        id: note.hashCode,
        title: note.title,
        body: note.body,
      );
    });
  }

  static Future<String?> _token({required bool ask}) async {
    final config = SproutConfig.fromEnvironment();
    if (!config.pushReady && kIsWeb) return null;
    try {
      if (Firebase.apps.isEmpty) {
        // Android reads google-services.json. Passing the web app id here
        // breaks FCM on the phone even when the project itself is correct.
        if (kIsWeb) {
          if (!config.pushReady) return null;
          await Firebase.initializeApp(
            options: FirebaseOptions(
              apiKey: config.firebaseApiKey,
              appId: config.firebaseAppId,
              messagingSenderId: config.firebaseSenderId,
              projectId: config.firebaseProjectId,
            ),
          );
        } else {
          await Firebase.initializeApp();
        }
      }
      if (!_started && !kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(sproutBackgroundMessage);
        _started = true;
      }
      if (!kIsWeb) await _local.prepare();
      final messaging = FirebaseMessaging.instance;
      if (ask && !_asked) {
        _asked = true;
        await messaging.requestPermission();
      }
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
