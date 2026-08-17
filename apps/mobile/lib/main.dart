import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/app_config.dart';
import 'services/api_service.dart';
import 'services/tracking_notification_service.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await TrackingNotificationService.instance.init();
  runApp(TruckManagementApp());
}

class TruckManagementApp extends StatelessWidget {
  TruckManagementApp({super.key}) : apiService = ApiService(baseUrl: AppConfig.apiBaseUrl) {
    // If the refresh token is missing/invalid, bounce back to the login screen
    // instead of leaving the user stuck on a screen full of failed requests.
    apiService.onSessionExpired = () {
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
    };
  }

  final ApiService apiService;
  final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'MS Trucks',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: LoginScreen(apiService: apiService),
    );
  }
}
