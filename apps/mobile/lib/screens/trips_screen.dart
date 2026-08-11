import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import 'drivers_screen.dart';
import 'trucks_screen.dart';
import 'trip_form_screen.dart';
import 'owner_trip_detail_screen.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key, required this.apiService, this.userRole});
  final ApiService apiService;
  final String? userRole;

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  late Future<List<Trip>> _tripsFuture;

  @override
  void initState() {
    super.initState();
    _tripsFuture = widget.apiService.fetchTrips();
  }

  Future<void> _refreshTrips() async {
    setState(() {
      _tripsFuture = widget.apiService.fetchTrips();
    });
  }

  Future<void> _createTrip() async {
    final created = await Navigator.push<Trip>(
      context,
      MaterialPageRoute(builder: (_) => TripFormScreen(apiService: widget.apiService)),
    );
    if (created != null) _refreshTrips();
  }

  Future<void> _openTripDetail(Trip trip) async {
    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => OwnerTripDetailScreen(apiService: widget.apiService, trip: trip),
      ),
    );
    if (res == true) _refreshTrips();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trips'),
        actions: [
          if (widget.userRole == 'OWNER')
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TrucksScreen(apiService: widget.apiService),
                  ),
                );
              },
              icon: const Icon(Icons.local_shipping),
            ),
          if (widget.userRole == 'OWNER')
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DriversScreen(apiService: widget.apiService),
                  ),
                );
              },
              icon: const Icon(Icons.people),
            ),
          IconButton(onPressed: _refreshTrips, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () async {
              await widget.apiService.clearToken();
              if (!mounted) return;
              Navigator.pop(context);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<Trip>>(
          future: _tripsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            final trips = snapshot.data ?? [];
            if (trips.isEmpty) {
              return const Center(child: Text('No trips yet'));
            }
            return ListView.builder(
              itemCount: trips.length,
              itemBuilder: (context, index) {
                final trip = trips[index];
                return Card(
                  child: ListTile(
                    title: Text('${trip.origin} → ${trip.destination}'),
                    subtitle: Text('Status: ${trip.status}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: widget.userRole == 'OWNER' ? () => _openTripDetail(trip) : null,
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: widget.userRole == 'OWNER'
          ? FloatingActionButton.extended(
              onPressed: _createTrip,
              icon: const Icon(Icons.add),
              label: const Text('Create Trip'),
            )
          : null,
    );
  }
}
