import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Owns the Android notification channel and permission used by Duty Status
/// location tracking. The visible "tracking is active" notification itself is
/// posted by the background foreground-service (see BackgroundLocationService),
/// not here — a foreground service must own its own notification, so posting a
/// second one on the same id would detach the service from it and risk the OS
/// killing it.
class TrackingNotificationService {
  TrackingNotificationService._();
  static final TrackingNotificationService instance = TrackingNotificationService._();

  static const _channelId = 'duty_status_tracking';
  static const _channelName = 'Duty Status Tracking';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(settings: const InitializationSettings(android: androidSettings));
    // flutter_background_service requires this channel to already exist before
    // its configure() call, so it's created explicitly rather than on demand.
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Reminds you that your location is being tracked while Online',
          importance: Importance.low,
        ));
    _initialized = true;
  }

  /// Must be granted before the foreground service starts — on Android 13+ its
  /// mandatory notification is silently suppressed without POST_NOTIFICATIONS.
  Future<void> requestPermission() async {
    if (kIsWeb) return;
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }
}
