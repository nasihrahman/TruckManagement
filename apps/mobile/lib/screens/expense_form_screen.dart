import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../services/api_service.dart';

class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key, required this.apiService, required this.tripId, this.existing});

  final ApiService apiService;
  final String tripId;
  final Expense? existing;

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late ExpenseCategory _category;
  late final TextEditingController _amountController;
  late final TextEditingController _odometerController;
  late final TextEditingController _reasonController;
  late final TextEditingController _notesController;
  bool _isLoading = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _category = existing?.category ?? ExpenseCategory.fuel;
    _amountController = TextEditingController(text: existing?.amount.toString() ?? '');
    _odometerController = TextEditingController(text: existing?.odometer?.toString() ?? '');
    _reasonController = TextEditingController(text: existing?.reason ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _odometerController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final amount = double.parse(_amountController.text);
      final odometer = _odometerController.text.isEmpty ? null : int.tryParse(_odometerController.text);

      if (_isEditing) {
        await widget.apiService.updateExpense(
          widget.tripId,
          widget.existing!.id,
          category: _category,
          amount: amount,
          odometer: _category == ExpenseCategory.fuel ? odometer : null,
          reason: _category == ExpenseCategory.fine ? _reasonController.text : null,
          notes: _notesController.text,
        );
      } else {
        await widget.apiService.createExpense(
          widget.tripId,
          category: _category,
          amount: amount,
          odometer: _category == ExpenseCategory.fuel ? odometer : null,
          reason: _category == ExpenseCategory.fine ? _reasonController.text : null,
          notes: _notesController.text,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Expense' : 'Log Expense')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<ExpenseCategory>(
                segments: const [
                  ButtonSegment(value: ExpenseCategory.fuel, label: Text('Fuel')),
                  ButtonSegment(value: ExpenseCategory.fine, label: Text('Fine')),
                  ButtonSegment(value: ExpenseCategory.other, label: Text('Other')),
                ],
                selected: {_category},
                onSelectionChanged: (selection) => setState(() => _category = selection.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final parsed = double.tryParse(value ?? '');
                  if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              if (_category == ExpenseCategory.fuel)
                TextFormField(
                  controller: _odometerController,
                  decoration: const InputDecoration(labelText: 'Odometer (optional)'),
                  keyboardType: TextInputType.number,
                ),
              if (_category == ExpenseCategory.fine)
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  validator: (value) => value == null || value.isEmpty ? 'Enter a reason for the fine' : null,
                ),
              if (_category == ExpenseCategory.other)
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Category / note'),
                  validator: (value) => value == null || value.isEmpty ? 'Enter a note describing this expense' : null,
                ),
              if (_category != ExpenseCategory.other) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  maxLines: 2,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEditing ? 'Save Changes' : 'Log Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
