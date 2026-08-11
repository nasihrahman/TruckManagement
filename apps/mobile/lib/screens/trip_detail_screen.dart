import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import '../widgets/slide_to_act.dart';
import '../widgets/expenses_list_view.dart';

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.apiService, required this.trip});

  final ApiService apiService;
  final Trip trip;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final _expensesKey = GlobalKey<ExpensesListViewState>();
  late Trip _trip;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
  }

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

  @override
  Widget build(BuildContext context) {
    final canAct = _trip.status == 'ASSIGNED' || _trip.status == 'IN_TRANSIT';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${_trip.origin} → ${_trip.destination}'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Status: ${_trip.status}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    child: SlideToAct(
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
