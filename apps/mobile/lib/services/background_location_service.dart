import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Keeps the Duty Status 60s location ping loop running while the app is
/// backgrounded or closed, via an Android foreground service. Before this,
/// the ping loop was a plain `Timer` on the UI isolate, which Android
/// suspends the moment the app leaves the foreground — that's why pings only
/// ever went out while the app was open. Android only: flutter_background_service
/// has no web support, so DriverTripsScreen keeps the UI-isolate Timer there.
class BackgroundLocationService {
  BackgroundLocationService._();
  static final BackgroundLocationService instance = BackgroundLocationService._();

  static const notificationChannelId = 'duty_status_tracking';
  static const notificationId = 1001;

  /// The background isolate can't read app.env reliably (no root bundle of its
  /// own until plugins register, and a load failure there would silently kill
  /// the whole ping loop), so the resolved URL is handed over via prefs.
  static const baseUrlPrefsKey = 'api_base_url';

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(baseUrlPrefsKey, AppConfig.apiBaseUrl);

    await FlutterBackgroundService().configure(
      iosConfiguration: IosConfiguration(autoStart: false),
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        autoStartOnBoot: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        foregroundServiceNotificationId: notificationId,
        foregroundServiceTypes: const [AndroidForegroundType.location],
        initialNotificationTitle: 'Location tracking is active',
        initialNotificationContent:
            "You're Online — remember to go offline once you're done for the day.",
      ),
    );
  }

  Future<void> start() async {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
  }

  Future<void> stop() async {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stopService');
    }
  }
}

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  service.on('stopService').listen((_) => service.stopSelf());

  // Guards against pings piling up: a cold-starting free-tier API can take
  // ~50s to answer, which would otherwise overlap the next 60s tick.
  var isPinging = false;

  Future<void> ping() async {
    if (isPinging) return;
    isPinging = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _pingLocation(position.latitude, position.longitude);
    } catch (_) {
      // Skip a failed ping silently; the next 60s tick retries.
    } finally {
      isPinging = false;
    }
  }

  await ping();
  Timer.periodic(const Duration(seconds: 60), (_) => ping());
}

/// Standalone request helper for the background isolate — it doesn't share
/// ApiService's in-memory token cache (a fresh isolate starts with none), so
/// it reads/refreshes tokens directly against SharedPreferences, using the
/// same 'auth_token'/'refresh_token' keys ApiService persists there.
Future<void> _pingLocation(double latitude, double longitude) async {
  // Generous because Render's free tier spins the API down after ~15 minutes
  // idle; the first ping that wakes it can take the better part of a minute.
  const timeout = Duration(seconds: 90);
  final prefs = await SharedPreferences.getInstance();
  final baseUrl = prefs.getString(BackgroundLocationService.baseUrlPrefsKey);
  var token = prefs.getString('auth_token');
  if (baseUrl == null || token == null) return;

  Future<http.Response> attempt() => http
      .post(
        Uri.parse('$baseUrl/drivers/me/location'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
      )
      .timeout(timeout);

  final response = await attempt();
  if (response.statusCode != 401) return;

  final refreshToken = prefs.getString('refresh_token');
  if (refreshToken == null) return;
  final refreshResponse = await http
      .post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      )
      .timeout(timeout);
  if (refreshResponse.statusCode >= 400) return;
  final body = jsonDecode(refreshResponse.body) as Map<String, dynamic>;
  token = body['accessToken'] as String;
  await prefs.setString('auth_token', token);
  await prefs.setString('refresh_token', body['refreshToken'] as String);
  await attempt();
}
