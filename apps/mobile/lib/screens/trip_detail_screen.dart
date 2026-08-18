import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import '../widgets/slide_to_act.dart';
import '../widgets/expenses_list_view.dart';

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

  Future<void> _handleTripAction() async {
    final newStatus = _trip.status == 'ASSIGNED' ? 'IN_TRANSIT' : 'DELIVERED';

    try {
      final updated = await widget.apiService.updateTripStatus(_trip.id, newStatus);
      if (!mounted) return;
      setState(() {
        _trip = updated;
        _changed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Trip marked as $newStatus')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
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
    final blockedOffline = _trip.status == 'ASSIGNED' && !widget.isOnline;
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
                  child: Center(
                    child: blockedOffline
                        ? Container(
                            width: 300,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.wifi_off, color: Colors.orange, size: 18),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Go online to start this trip',
                                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SlideToAct(
                            label: _trip.status == 'ASSIGNED' ? 'Slide to Start Trip' : 'Slide to End Trip',
                            thumbColor: _trip.status == 'ASSIGNED' ? Colors.green : Colors.red,
                            onAct: _handleTripAction,
                          ),
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
