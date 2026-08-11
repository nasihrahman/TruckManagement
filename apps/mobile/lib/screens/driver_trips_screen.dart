import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import 'trip_detail_screen.dart';

class DriverTripsScreen extends StatefulWidget {
  const DriverTripsScreen({super.key, required this.apiService});
  final ApiService apiService;

  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen> {
  late Future<List<Trip>> _tripsFuture;

  @override
  void initState() {
    super.initState();
    _refreshTrips();
  }

  void _refreshTrips() {
    setState(() {
      _tripsFuture = widget.apiService.fetchTrips();
    });
  }

  Future<void> _openTripDetail(Trip trip) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TripDetailScreen(apiService: widget.apiService, trip: trip),
      ),
    );
    if (changed == true) _refreshTrips();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        actions: [
          IconButton(
            onPressed: _refreshTrips,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () async {
              await widget.apiService.clearToken();
              if (!mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<List<Trip>>(
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

          final currentTrips = trips.where((t) => t.status == 'ASSIGNED' || t.status == 'IN_TRANSIT').toList();
          final completedTrips = trips.where((t) => t.status == 'DELIVERED' || t.status == 'FAILED').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (currentTrips.isNotEmpty) ...[
                const Text('Current Trip', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                for (final trip in currentTrips)
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        '${trip.origin} → ${trip.destination}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _StatusBadge(status: trip.status),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openTripDetail(trip),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
              if (completedTrips.isNotEmpty) ...[
                const Text('Completed Trips', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                for (final trip in completedTrips)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text('${trip.origin} → ${trip.destination}'),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: _StatusBadge(status: trip.status),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openTripDetail(trip),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  Color get _color {
    switch (status) {
      case 'ASSIGNED':
        return Colors.blue;
      case 'IN_TRANSIT':
        return Colors.orange;
      case 'DELIVERED':
        return Colors.green;
      case 'FAILED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
