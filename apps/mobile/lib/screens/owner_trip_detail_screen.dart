import 'package:flutter/material.dart';
import '../models/driver.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import '../widgets/expenses_list_view.dart';
import 'trip_form_screen.dart';

class OwnerTripDetailScreen extends StatefulWidget {
  const OwnerTripDetailScreen({super.key, required this.apiService, required this.trip});

  final ApiService apiService;
  final Trip trip;

  @override
  State<OwnerTripDetailScreen> createState() => _OwnerTripDetailScreenState();
}

class _OwnerTripDetailScreenState extends State<OwnerTripDetailScreen> {
  late Trip _trip;
  bool _changed = false;
  bool _isLoadingResources = true;
  String? _driverName;
  String? _truckPlate;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _loadAssignmentLabels();
  }

  Future<void> _loadAssignmentLabels() async {
    setState(() => _isLoadingResources = true);
    try {
      final results = await Future.wait([
        widget.apiService.fetchDrivers(),
        widget.apiService.fetchTrucks(),
      ]);
      final drivers = results[0] as List<Driver>;
      final trucks = results[1] as List<Map<String, dynamic>>;
      setState(() {
        _driverName = drivers.where((d) => d.id == _trip.driverId).map((d) => d.name).firstOrNull;
        _truckPlate = trucks.where((t) => t['id'] == _trip.truckId).map((t) => t['plate'] as String).firstOrNull;
      });
    } catch (_) {
      // Non-fatal: assignment labels just stay blank if this lookup fails.
    } finally {
      if (mounted) setState(() => _isLoadingResources = false);
    }
  }

  Future<void> _editTrip() async {
    final updated = await Navigator.push<Trip>(
      context,
      MaterialPageRoute(builder: (_) => TripFormScreen(apiService: widget.apiService, existing: _trip)),
    );
    if (updated == null) return;
    setState(() {
      _trip = updated;
      _changed = true;
    });
    _loadAssignmentLabels();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${_trip.origin} → ${_trip.destination}'),
          actions: [
            IconButton(icon: const Icon(Icons.edit), onPressed: _editTrip, tooltip: 'Edit Trip'),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: ${_trip.status}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _isLoadingResources
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('Driver: ${_driverName ?? 'Unassigned'}'),
                  const SizedBox(height: 4),
                  if (!_isLoadingResources) Text('Truck: ${_truckPlate ?? 'Unassigned'}'),
                ],
              ),
            ),
            const Divider(height: 1),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.grey.shade100,
              child: Row(
                children: const [
                  Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('Live location — coming soon', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Expenses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            Expanded(
              child: ExpensesListView(
                apiService: widget.apiService,
                tripId: _trip.id,
                financiallyClosed: _trip.financiallyClosed,
                readOnly: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
