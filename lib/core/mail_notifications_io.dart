import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class MailNotifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static var _ready = false;

  static Future<void> ensure() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const windows = WindowsInitializationSettings(
      appName: 'iBeLucky',
      appUserModelId: 'com.ibelucky.mail',
      guid: 'c3a8c1d2-4e5f-6a7b-8c9d-0e1f2a3b4c5d',
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, windows: windows),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  static Future<void> show({required String title, required String body}) async {
    await ensure();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mail_inbox',
        'Incoming mail',
        channelDescription: 'New messages in the mailbox',
        importance: Importance.high,
        priority: Priority.high,
      ),
      windows: WindowsNotificationDetails(),
    );
    await _plugin.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, details);
  }
}
