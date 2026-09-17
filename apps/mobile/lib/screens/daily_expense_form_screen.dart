import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/driver.dart';
import '../models/truck.dart';
import '../services/api_service.dart';
import '../widgets/photo_picker_field.dart';

class DailyExpenseFormScreen extends StatefulWidget {
  const DailyExpenseFormScreen({super.key, required this.apiService, this.isOwner = false});

  final ApiService apiService;
  /// Owners must pick which driver the expense is for; Drivers are always
  /// attributed to themselves server-side, so no picker is shown for them.
  final bool isOwner;

  @override
  State<DailyExpenseFormScreen> createState() => _DailyExpenseFormScreenState();
}

class _DailyExpenseFormScreenState extends State<DailyExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  ExpenseCategory _category = ExpenseCategory.fuel;
  DateTime _date = DateTime.now();
  late final TextEditingController _amountController;
  late final TextEditingController _reasonController;
  late final TextEditingController _notesController;
  String? _photoUrl;
  String? _selectedDriverId;
  String? _selectedTruckId;
  List<Driver> _drivers = [];
  List<Truck> _trucks = [];
  bool _isLoading = false;
  bool _isLoadingDrivers = false;
  bool _isLoadingTrucks = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _reasonController = TextEditingController();
    _notesController = TextEditingController();
    _loadTrucks();
    if (widget.isOwner) {
      _loadDrivers();
    } else {
      _prefillOwnTruck();
    }
  }

  /// Drivers get their own assigned truck pre-filled (still changeable) —
  /// same default-truck convention as the Trip Form.
  Future<void> _prefillOwnTruck() async {
    try {
      final profile = await widget.apiService.fetchMyDriverProfile();
      if (!mounted) return;
      final defaultTruckId = profile['defaultTruckId']?.toString();
      if (defaultTruckId != null) setState(() => _selectedTruckId = defaultTruckId);
    } catch (_) {
      // Non-fatal: the truck field just stays empty if this fails.
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoadingDrivers = true);
    try {
      final drivers = await widget.apiService.fetchDrivers();
      if (!mounted) return;
      setState(() => _drivers = drivers);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoadingDrivers = false);
    }
  }

  Future<void> _loadTrucks() async {
    setState(() => _isLoadingTrucks = true);
    try {
      final trucks = await widget.apiService.fetchTrucks();
      if (!mounted) return;
      setState(() => _trucks = trucks);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoadingTrucks = false);
    }
  }

  /// Owner picking a driver pre-fills that driver's default truck (still
  /// changeable) — same as the Trip Form's driver-picks-truck convention.
  void _onDriverChanged(String? driverId) {
    setState(() {
      _selectedDriverId = driverId;
      final matches = _drivers.where((d) => d.id == driverId);
      if (matches.isNotEmpty && matches.first.defaultTruckId != null) {
        _selectedTruckId = matches.first.defaultTruckId;
      }
    });
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _submit() async {
    if (widget.isOwner && _selectedDriverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick which driver this expense is for')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final amount = double.parse(_amountController.text);
      await widget.apiService.createDailyExpense(
        date: _date,
        category: _category,
        amount: amount,
        reason: _reasonController.text,
        notes: _notesController.text,
        photoUrl: _photoUrl,
        driverId: widget.isOwner ? _selectedDriverId : null,
        truckId: _selectedTruckId,
      );
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
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    return Scaffold(
      appBar: AppBar(title: const Text('Log Daily Expense')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isOwner) ...[
                const Text('Driver', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _isLoadingDrivers
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        initialValue: _selectedDriverId,
                        isExpanded: true,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        hint: const Text('Select driver'),
                        items: _drivers
                            .map((d) => DropdownMenuItem<String>(value: d.id, child: Text(d.name)))
                            .toList(),
                        onChanged: _onDriverChanged,
                      ),
                const SizedBox(height: 20),
              ],
              const Text('Truck', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _isLoadingTrucks
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      initialValue: _selectedTruckId,
                      isExpanded: true,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      hint: const Text('Unassigned'),
                      items: _trucks
                          .map((t) => DropdownMenuItem<String>(value: t.id, child: Text(t.displayName)))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedTruckId = val),
                    ),
              const SizedBox(height: 20),
              const Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Today'),
                    selected: _isSameDay(_date, today),
                    onSelected: (_) => setState(() => _date = today),
                  ),
                  ChoiceChip(
                    label: const Text('Yesterday'),
                    selected: _isSameDay(_date, yesterday),
                    onSelected: (_) => setState(() => _date = yesterday),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.calendar_month, size: 18),
                    label: Text(
                      !_isSameDay(_date, today) && !_isSameDay(_date, yesterday)
                          ? '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'
                          : 'Choose Date',
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(today.year - 1),
                        lastDate: today,
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
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
                decoration: const InputDecoration(labelText: 'Total Amount', prefixText: '₹ '),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final parsed = double.tryParse(value ?? '');
                  if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(labelText: 'Reason (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              const Text('Receipt Photo (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              PhotoPickerField(
                apiService: widget.apiService,
                photoUrl: _photoUrl,
                onChanged: (url) => setState(() => _photoUrl = url),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Log Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
