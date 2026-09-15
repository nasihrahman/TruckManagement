import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import '../widgets/slide_to_act.dart';
import '../widgets/expenses_list_view.dart';
import 'trip_form_screen.dart';

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.apiService, required this.trip, this.isOnline = false});

  final ApiService apiService;
  final Trip trip;
  /// Whether the driver is currently on Duty Status Online. A trip can only
  /// be started (not ended) while Online, so location tracking is running
  /// for the whole trip rather than picking up partway through.
  final bool isOnline;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final _expensesKey = GlobalKey<ExpensesListViewState>();
  late Trip _trip;
  bool _changed = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// The only slide action now — straight to Delivered, no separate "start"
  /// step. Still works from IN_TRANSIT too (a trip that already went through
  /// the old two-step flow before this change), always landing on DELIVERED.
  Future<void> _handleTripAction() async {
    try {
      final updated = await widget.apiService.updateTripStatus(_trip.id, 'DELIVERED');
      if (!mounted) return;
      setState(() {
        _trip = updated;
        _changed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip marked as DELIVERED')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _markFailed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Failed?'),
        content: const Text('This records the delivery as failed. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark Failed'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final updated = await widget.apiService.updateTripStatus(_trip.id, 'FAILED');
      if (!mounted) return;
      setState(() {
        _trip = updated;
        _changed = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _editTrip() async {
    final updated = await Navigator.push<Trip>(
      context,
      MaterialPageRoute(
        builder: (_) => TripFormScreen(apiService: widget.apiService, existing: _trip, isOwner: false),
      ),
    );
    if (updated == null) return;
    setState(() {
      _trip = updated;
      _changed = true;
    });
  }

  Future<void> _deleteTrip() async {
    final warnings = <String>[];
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

  @override
  Widget build(BuildContext context) {
    final canAct = _trip.status == 'ASSIGNED' || _trip.status == 'IN_TRANSIT';
    final canDelete = _trip.status == 'ASSIGNED';
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
            if (canDelete)
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: ${_trip.status}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
            if (canAct)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SlideToAct(
                        label: 'Slide to Deliver',
                        thumbColor: Colors.green,
                        onAct: _handleTripAction,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _markFailed,
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Mark as Failed'),
                      ),
                    ],
                  ),
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
