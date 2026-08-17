import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import '../widgets/app_brand_title.dart';
import 'owner_trip_detail_screen.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key, required this.apiService, required this.onLogout, this.userRole});
  final ApiService apiService;
  final VoidCallback onLogout;
  final String? userRole;

  @override
  State<TripsScreen> createState() => TripsScreenState();
}

class TripsScreenState extends State<TripsScreen> {
  late Future<List<Trip>> _tripsFuture;
  final _searchController = TextEditingController();
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tripsFuture = widget.apiService.fetchTrips();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> refreshTrips() async {
    setState(() {
      _tripsFuture = widget.apiService.fetchTrips();
    });
  }

  Future<void> _openTripDetail(Trip trip) async {
    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => OwnerTripDetailScreen(apiService: widget.apiService, trip: trip),
      ),
    );
    if (res == true) refreshTrips();
  }

  List<Trip> _applyFilters(List<Trip> trips) {
    final query = _searchController.text.trim().toLowerCase();
    return trips.where((t) {
      if (_statusFilter != 'ALL' && t.status != _statusFilter) return false;
      if (query.isEmpty) return true;
      return t.origin.toLowerCase().contains(query) || t.destination.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppBrandTitle(title: 'Trips'),
        actions: [
          IconButton(onPressed: refreshTrips, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search trips',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final status in const ['ALL', 'ASSIGNED', 'IN_TRANSIT', 'DELIVERED', 'FAILED'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(status == 'ALL' ? 'All' : status),
                        selected: _statusFilter == status,
                        onSelected: (_) => setState(() => _statusFilter = status),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
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
                final trips = _applyFilters(snapshot.data ?? []);
                if (trips.isEmpty) {
                  return const Center(child: Text('No trips match'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: trips.length,
                  itemBuilder: (context, index) {
                    final trip = trips[index];
                    return Card(
                      child: ListTile(
                        title: Text('${trip.origin} → ${trip.destination}'),
                        subtitle: Text(
                          'Status: ${trip.status} · Expenses: ₹${trip.expenseTotal.toStringAsFixed(2)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openTripDetail(trip),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
