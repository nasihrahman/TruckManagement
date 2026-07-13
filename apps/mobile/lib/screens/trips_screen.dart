import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import 'drivers_screen.dart';
import 'assign_trip_screen.dart';
import '../config/app_config.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key, required this.apiService, this.userRole});
  final ApiService apiService;
  final String? userRole;

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  late Future<List<Trip>> _tripsFuture;
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();

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
    try {
      await widget.apiService.createTrip(
        origin: _originController.text,
        destination: _destinationController.text,
      );
      _originController.clear();
      _destinationController.clear();
      await _refreshTrips();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
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
        child: Column(
          children: [
            if (widget.userRole == 'OWNER')
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(controller: _originController, decoration: const InputDecoration(labelText: 'Origin')),
                      const SizedBox(height: 8),
                      TextField(controller: _destinationController, decoration: const InputDecoration(labelText: 'Destination')),
                      const SizedBox(height: 12),
                      FilledButton.icon(onPressed: _createTrip, icon: const Icon(Icons.add), label: const Text('Create trip')),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
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
                          trailing: const Icon(Icons.local_shipping),
                          onTap: widget.userRole == 'OWNER' 
                            ? () async {
                                final res = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AssignTripScreen(
                                      apiService: widget.apiService,
                                      tripId: trip.id,
                                      initialDriverId: trip.driverId,
                                      initialTruckId: trip.truckId,
                                    ),
                                  ),
                                );
                                if (res == true) _refreshTrips();
                              }
                            : null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
