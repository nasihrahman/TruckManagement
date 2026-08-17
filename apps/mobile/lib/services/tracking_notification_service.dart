import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Reminds a Driver that Duty Status location tracking is active, so it isn't
/// left on by accident after they're done for the day (tracking itself is
/// still foreground-only — see Override 16 — this is just the reminder).
class TrackingNotificationService {
  TrackingNotificationService._();
  static final TrackingNotificationService instance = TrackingNotificationService._();

  static const int _notificationId = 1001;
  static const _channelId = 'duty_status_tracking';
  static const _channelName = 'Duty Status Tracking';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(settings: const InitializationSettings(android: androidSettings));
    _initialized = true;
  }

  Future<void> requestPermission() async {
    if (kIsWeb) return;
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> showTrackingActive() async {
    if (kIsWeb) return;
    await _plugin.show(
      id: _notificationId,
      title: 'Location tracking is active',
      body: "You're Online — remember to go offline once you're done for the day.",
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Reminds you that your location is being tracked while Online',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          silent: true,
        ),
      ),
    );
  }

  Future<void> cancelTrackingActive() async {
    if (kIsWeb) return;
    await _plugin.cancel(id: _notificationId);
  }
}
