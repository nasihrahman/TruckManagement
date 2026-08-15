import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/driver.dart';
import 'add_driver_screen.dart';

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key, required this.apiService});
  final ApiService apiService;

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  late Future<List<Driver>> _driversFuture;

  @override
  void initState() {
    super.initState();
    _refreshDrivers();
  }

  void _refreshDrivers() {
    setState(() {
      _driversFuture = widget.apiService.fetchDrivers();
    });
  }

  Future<void> _handleDeactivate(String id) async {
    try {
      await widget.apiService.deactivateDriver(id);
      _refreshDrivers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _handleReactivate(String id) async {
    try {
      await widget.apiService.reactivateDriver(id);
      _refreshDrivers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _handleResetPassword(Driver driver) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password?'),
        content: Text('This generates a new temporary password for ${driver.name} and signs them out of their current session.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final tempPassword = await widget.apiService.resetDriverPassword(driver.id);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Password Reset'),
          content: Text('The new temporary password for ${driver.name} is: $tempPassword\nPlease share this with them.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _editDriver(Driver driver) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddDriverScreen(apiService: widget.apiService, existing: driver),
      ),
    );
    _refreshDrivers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drivers'),
        actions: [
          IconButton(
            onPressed: _refreshDrivers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Driver>>(
        future: _driversFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final drivers = snapshot.data ?? [];
          if (drivers.isEmpty) {
            return const Center(child: Text('No drivers found'));
          }
          return ListView.builder(
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(driver.name.isNotEmpty 
                        ? driver.name[0].toUpperCase() 
                        : '?'),
                  ),
                  title: Text(driver.name),
                  subtitle: Text(driver.phone),
                  onTap: () => _editDriver(driver),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editDriver(driver);
                      } else if (value == 'deactivate') {
                        _handleDeactivate(driver.id);
                      } else if (value == 'reactivate') {
                        _handleReactivate(driver.id);
                      } else if (value == 'reset-password') {
                        _handleResetPassword(driver);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      const PopupMenuItem(
                        value: 'reset-password',
                        child: Text('Reset Password'),
                      ),
                      if (!driver.isActive)
                        const PopupMenuItem(
                          value: 'reactivate',
                          child: Text('Reactivate'),
                        ),
                      if (driver.isActive)
                        const PopupMenuItem(
                          value: 'deactivate',
                          child: Text('Deactivate'),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddDriverScreen(apiService: widget.apiService),
            ),
          );
          _refreshDrivers();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
