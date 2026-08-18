import 'package:flutter/material.dart';
import '../models/driver.dart';
import '../models/trip.dart';
import '../models/truck.dart';
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
  final _expensesKey = GlobalKey<ExpensesListViewState>();
  late Trip _trip;
  bool _changed = false;
  bool _isLoadingResources = true;
  bool _isUpdatingStatus = false;
  bool _isDeleting = false;
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
      final trucks = results[1] as List<Truck>;
      setState(() {
        _driverName = drivers.where((d) => d.id == _trip.driverId).map((d) => d.name).firstOrNull;
        _truckPlate = trucks.where((t) => t.id == _trip.truckId).map((t) => t.plate).firstOrNull;
      });
    } catch (_) {
      // Non-fatal: assignment labels just stay blank if this lookup fails.
    } finally {
      if (mounted) setState(() => _isLoadingResources = false);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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

  Future<void> _markStatus(String status) async {
    final label = status == 'DELIVERED' ? 'Delivered' : 'Failed';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark as $label?'),
        content: Text(
          'This records the trip as $label on the driver\'s behalf — use this if the driver didn\'t update it themselves.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Mark $label')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isUpdatingStatus = true);
    try {
      final updated = await widget.apiService.updateTripStatus(_trip.id, status);
      if (!mounted) return;
      setState(() {
        _trip = updated;
        _changed = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _deleteTrip() async {
    final warnings = <String>[];
    if (_trip.status != 'ASSIGNED') {
      warnings.add(
        'This trip is already $_statusLabel — deleting it will remove its trip history.',
      );
    }
    if (_trip.expenses.isNotEmpty) {
      warnings.add(
        'This trip has ${_trip.expenses.length} expense(s) totaling ₹${_trip.expenseTotal.toStringAsFixed(2)} that will also be deleted.',
      );
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this trip?'),
        content: Text(
          [
            'This cannot be undone.',
            ...warnings,
          ].join('\n\n'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await widget.apiService.deleteTrip(_trip.id);
      if (!mounted) return;
      _changed = true;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String get _statusLabel {
    switch (_trip.status) {
      case 'IN_TRANSIT':
        return 'in transit';
      case 'DELIVERED':
        return 'delivered';
      case 'FAILED':
        return 'marked failed';
      default:
        return _trip.status.toLowerCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canOverrideStatus = _trip.status == 'IN_TRANSIT';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_trip.displayTitle),
          actions: [
            IconButton(icon: const Icon(Icons.edit), onPressed: _editTrip, tooltip: 'Edit Trip'),
            IconButton(
              icon: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.delete_outline),
              tooltip: 'Delete Trip',
              onPressed: _isDeleting ? null : _deleteTrip,
            ),
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
                  if (_trip.scheduledAt != null) ...[
                    const SizedBox(height: 4),
                    Text('Delivery Date: ${_formatDate(_trip.scheduledAt!)}'),
                  ],
                  if (_trip.completedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${_trip.status == 'FAILED' ? 'Failed' : 'Delivered'} on: ${_formatDate(_trip.completedAt!)}',
                    ),
                  ],
                  if (canOverrideStatus) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isUpdatingStatus ? null : () => _markStatus('DELIVERED'),
                            child: const Text('Mark Delivered'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            onPressed: _isUpdatingStatus ? null : () => _markStatus('FAILED'),
                            child: const Text('Mark Failed'),
                          ),
                        ),
                      ],
                    ),
                  ],
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
                key: _expensesKey,
                apiService: widget.apiService,
                tripId: _trip.id,
                financiallyClosed: _trip.financiallyClosed,
              ),
            ),
          ],
        ),
        floatingActionButton: _trip.financiallyClosed
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _expensesKey.currentState?.addExpense(),
                icon: const Icon(Icons.add),
                label: const Text('Add Expense'),
              ),
      ),
    );
  }
}
