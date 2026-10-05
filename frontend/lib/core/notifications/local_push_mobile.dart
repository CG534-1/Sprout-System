import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalPush {
  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> prepare() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
    );
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'sprout_care',
        'Sprout care',
        description: 'Care reminders and overdue alerts',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> show({
    required int id,
    required String? title,
    required String? body,
  }) async {
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'sprout_care',
          'Sprout care',
          channelDescription: 'Care reminders and overdue alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}

LocalPush createLocalPush() => LocalPush();
