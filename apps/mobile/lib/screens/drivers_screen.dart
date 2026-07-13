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
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'deactivate') {
                        _handleDeactivate(driver.id);
                      } else if (value == 'reactivate') {
                        _handleReactivate(driver.id);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
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
