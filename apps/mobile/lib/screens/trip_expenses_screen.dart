import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import '../widgets/expenses_list_view.dart';

class TripExpensesScreen extends StatefulWidget {
  const TripExpensesScreen({super.key, required this.apiService, required this.trip});

  final ApiService apiService;
  final Trip trip;

  @override
  State<TripExpensesScreen> createState() => _TripExpensesScreenState();
}

class _TripExpensesScreenState extends State<TripExpensesScreen> {
  final _expensesKey = GlobalKey<ExpensesListViewState>();

  @override
  Widget build(BuildContext context) {
    final closed = widget.trip.financiallyClosed;
    return Scaffold(
      appBar: AppBar(
        title: Text('Expenses: ${widget.trip.origin} → ${widget.trip.destination}'),
      ),
      body: Column(
        children: [
          if (closed)
            Container(
              width: double.infinity,
              color: Colors.grey.shade300,
              padding: const EdgeInsets.all(12),
              child: const Text(
                'This trip is financially closed. Expenses can no longer be added or edited.',
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: ExpensesListView(
              key: _expensesKey,
              apiService: widget.apiService,
              tripId: widget.trip.id,
              financiallyClosed: closed,
            ),
          ),
        ],
      ),
      floatingActionButton: closed
          ? null
          : FloatingActionButton(
              onPressed: () => _expensesKey.currentState?.addExpense(),
              child: const Icon(Icons.add),
            ),
    );
  }
}
