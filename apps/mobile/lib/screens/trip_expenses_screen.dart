import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import 'expense_form_screen.dart';

class TripExpensesScreen extends StatefulWidget {
  const TripExpensesScreen({super.key, required this.apiService, required this.trip});

  final ApiService apiService;
  final Trip trip;

  @override
  State<TripExpensesScreen> createState() => _TripExpensesScreenState();
}

class _TripExpensesScreenState extends State<TripExpensesScreen> {
  late Future<List<Expense>> _expensesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _expensesFuture = widget.apiService.fetchExpenses(widget.trip.id);
    });
  }

  Future<void> _openForm({Expense? existing}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseFormScreen(
          apiService: widget.apiService,
          tripId: widget.trip.id,
          existing: existing,
        ),
      ),
    );
    if (saved == true) _refresh();
  }

  Future<void> _confirmDelete(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
          'This will permanently remove the ${expenseCategoryLabel(expense.category)} expense of ₹${expense.amount.toStringAsFixed(2)}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.apiService.deleteExpense(widget.trip.id, expense.id);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

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
            child: FutureBuilder<List<Expense>>(
              future: _expensesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }
                final expenses = snapshot.data ?? [];
                if (expenses.isEmpty) {
                  return const Center(child: Text('No expenses logged for this trip yet'));
                }
                final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Total: ₹${total.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final expense = expenses[index];
                          return ListTile(
                            leading: CircleAvatar(child: Text(expenseCategoryLabel(expense.category)[0])),
                            title: Text('${expenseCategoryLabel(expense.category)} — ₹${expense.amount.toStringAsFixed(2)}'),
                            subtitle: Text(
                              [
                                if (expense.odometer != null) 'Odometer: ${expense.odometer}',
                                if (expense.reason != null && expense.reason!.isNotEmpty) expense.reason!,
                                if (expense.notes != null && expense.notes!.isNotEmpty) expense.notes!,
                              ].join(' · '),
                            ),
                            trailing: closed
                                ? null
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18),
                                        onPressed: () => _openForm(existing: expense),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18),
                                        onPressed: () => _confirmDelete(expense),
                                      ),
                                    ],
                                  ),
                            onTap: closed ? null : () => _openForm(existing: expense),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: closed
          ? null
          : FloatingActionButton(
              onPressed: () => _openForm(),
              child: const Icon(Icons.add),
            ),
    );
  }
}
