import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import 'owner_dashboard_tab.dart';
import 'trips_screen.dart';
import 'trip_form_screen.dart';
import 'add_driver_screen.dart';
import 'add_owner_screen.dart';
import 'truck_form_screen.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key, required this.apiService});
  final ApiService apiService;

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  int _selectedIndex = 0;
  final _dashboardKey = GlobalKey<OwnerDashboardTabState>();
  final _tripsKey = GlobalKey<TripsScreenState>();

  Future<void> _logout() async {
    await widget.apiService.clearToken();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _refreshAll() {
    _dashboardKey.currentState?.refresh();
    _tripsKey.currentState?.refreshTrips();
  }

  Future<void> _quickCreateTrip() async {
    Navigator.pop(context);
    final created = await Navigator.push<Trip>(
      context,
      MaterialPageRoute(builder: (_) => TripFormScreen(apiService: widget.apiService)),
    );
    if (created != null) _refreshAll();
  }

  Future<void> _quickAddDriver() async {
    Navigator.pop(context);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddDriverScreen(apiService: widget.apiService)),
    );
    _refreshAll();
  }

  Future<void> _quickAddTruck() async {
    Navigator.pop(context);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TruckFormScreen(apiService: widget.apiService)),
    );
    _refreshAll();
  }

  Future<void> _quickAddOwner() async {
    Navigator.pop(context);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddOwnerScreen(apiService: widget.apiService)),
    );
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.add_road),
              title: const Text('Create Trip'),
              onTap: _quickCreateTrip,
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Add Driver'),
              onTap: _quickAddDriver,
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping),
              title: const Text('Add Truck'),
              onTap: _quickAddTruck,
            ),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Add Owner'),
              onTap: _quickAddOwner,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          OwnerDashboardTab(key: _dashboardKey, apiService: widget.apiService, onLogout: _logout),
          TripsScreen(key: _tripsKey, apiService: widget.apiService, onLogout: _logout, userRole: 'OWNER'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickActions,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.dashboard, color: _selectedIndex == 0 ? Theme.of(context).colorScheme.primary : null),
              onPressed: () => setState(() => _selectedIndex = 0),
            ),
            IconButton(
              icon: Icon(Icons.route, color: _selectedIndex == 1 ? Theme.of(context).colorScheme.primary : null),
              onPressed: () => setState(() => _selectedIndex = 1),
            ),
          ],
        ),
      ),
    );
  }
}
