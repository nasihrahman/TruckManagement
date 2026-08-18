import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_brand_title.dart';
import 'owner_home_screen.dart';
import 'change_password_screen.dart';
import 'driver_trips_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.apiService});
  final ApiService apiService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final loginResult = await widget.apiService.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;

      if (loginResult['mustChangePassword'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChangePasswordScreen(
              apiService: widget.apiService,
              userRole: loginResult['role'],
            ),
          ),
        );
      } else {
        if (loginResult['role'] == 'DRIVER') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DriverTripsScreen(apiService: widget.apiService),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OwnerHomeScreen(apiService: widget.apiService),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppBrandTitle(title: 'MS Trucks')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email or Phone Number'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isLoading ? null : _login,
              icon: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.login),
              label: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
