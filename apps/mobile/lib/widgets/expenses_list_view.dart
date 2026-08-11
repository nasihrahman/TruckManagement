import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../services/api_service.dart';
import '../screens/expense_form_screen.dart';

class ExpensesListView extends StatefulWidget {
  const ExpensesListView({
    super.key,
    required this.apiService,
    required this.tripId,
    required this.financiallyClosed,
    this.readOnly = false,
  });

  final ApiService apiService;
  final String tripId;
  final bool financiallyClosed;
  /// When true (e.g. the Owner viewing a trip), hides edit/delete controls —
  /// only the driver who logged an expense may edit or delete it.
  final bool readOnly;

  @override
  State<ExpensesListView> createState() => ExpensesListViewState();
}

class ExpensesListViewState extends State<ExpensesListView> {
  late Future<List<Expense>> _expensesFuture;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    setState(() {
      _expensesFuture = widget.apiService.fetchExpenses(widget.tripId);
    });
  }

  Future<void> _openForm({Expense? existing}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseFormScreen(
          apiService: widget.apiService,
          tripId: widget.tripId,
          existing: existing,
        ),
      ),
    );
    if (saved == true) refresh();
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
      await widget.apiService.deleteExpense(widget.tripId, expense.id);
      refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final closed = widget.financiallyClosed || widget.readOnly;
    return FutureBuilder<List<Expense>>(
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
    );
  }

  Future<void> addExpense() => _openForm();
}
