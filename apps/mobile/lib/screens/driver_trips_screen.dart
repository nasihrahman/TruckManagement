import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import '../widgets/slide_to_act.dart';
import 'trip_expenses_screen.dart';

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

  Future<void> _handleTripAction(Trip trip) async {
    String newStatus;
    String label;
    Color color;

    if (trip.status == 'ASSIGNED') {
      newStatus = 'IN_TRANSIT';
      label = 'Start Trip';
      color = Colors.green;
    } else if (trip.status == 'IN_TRANSIT') {
      newStatus = 'DELIVERED'; // Defaulting to DELIVERED for now
      label = 'End Trip';
      color = Colors.red;
    } else {
      return;
    }

    try {
      await widget.apiService.updateTripStatus(trip.id, newStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Trip marked as $newStatus')),
      );
      _refreshTrips();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
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
            return const Center(child: Text('No assigned trips found'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              final bool canAct = trip.status == 'ASSIGNED' || trip.status == 'IN_TRANSIT';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${trip.origin} → ${trip.destination}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(trip.status).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              trip.status,
                              style: TextStyle(
                                color: _getStatusColor(trip.status),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (canAct)
                        Center(
                          child: SlideToAct(
                            label: trip.status == 'ASSIGNED' ? 'Slide to Start Trip' : 'Slide to End Trip',
                            thumbColor: trip.status == 'ASSIGNED' ? Colors.green : Colors.red,
                            onAct: () => _handleTripAction(trip),
                          ),
                        )
                      else
                        const Center(
                          child: Text('No actions available for this trip',
                              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                        ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TripExpensesScreen(apiService: widget.apiService, trip: trip),
                              ),
                            );
                          },
                          icon: const Icon(Icons.receipt_long, size: 18),
                          label: Text(trip.financiallyClosed ? 'View Expenses' : 'Log Expenses'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
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
}
