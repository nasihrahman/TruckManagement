import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';
import 'owner_home_screen.dart';
import 'driver_trips_screen.dart';

/// Checked once at app startup so a previously saved login survives an app
/// restart / page reload instead of always bouncing back to Login, even
/// though the access token is refreshed transparently on every other screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.apiService});
  final ApiService apiService;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final hasSession = await widget.apiService.hasStoredSession();
    final role = hasSession ? await widget.apiService.getStoredRole() : null;
    if (!mounted) return;

    if (!hasSession || role == null) {
      if (hasSession) await widget.apiService.clearToken();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen(apiService: widget.apiService)),
      );
      return;
    }

    final mustChangePassword = await widget.apiService.getStoredMustChangePassword();
    if (!mounted) return;

    if (mustChangePassword) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChangePasswordScreen(apiService: widget.apiService, userRole: role),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => role == 'DRIVER'
            ? DriverTripsScreen(apiService: widget.apiService)
            : OwnerHomeScreen(apiService: widget.apiService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
