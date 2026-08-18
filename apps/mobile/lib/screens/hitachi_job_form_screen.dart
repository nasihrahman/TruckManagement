import 'package:flutter/material.dart';
import '../models/hitachi_job.dart';
import '../services/api_service.dart';
import '../widgets/photo_picker_field.dart';

class HitachiJobFormScreen extends StatefulWidget {
  const HitachiJobFormScreen({super.key, required this.apiService, this.existing});

  final ApiService apiService;
  final HitachiJob? existing;

  @override
  State<HitachiJobFormScreen> createState() => _HitachiJobFormScreenState();
}

class _HitachiJobFormScreenState extends State<HitachiJobFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late final TextEditingController _customerController;
  late final TextEditingController _placeController;
  late final TextEditingController _totalHoursController;
  late final TextEditingController _paymentReceivedController;
  late final TextEditingController _nDieselController;
  late final TextEditingController _hDieselController;
  late final TextEditingController _opBataController;
  late final TextEditingController _otherExpenseMController;
  late final TextEditingController _otherExpenseJController;
  late final TextEditingController _salaryAdvanceController;
  HitachiPayer? _paymentReceivedBy;
  HitachiPayer? _nDieselPaidBy;
  HitachiPayer? _hDieselPaidBy;
  HitachiPayer? _opBataPaidBy;
  String? _photoUrl;
  bool _isLoading = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _date = existing?.date ?? DateTime.now();
    _customerController = TextEditingController(text: existing?.customerName ?? '');
    _placeController = TextEditingController(text: existing?.place ?? '');
    _totalHoursController = TextEditingController(text: existing?.totalHours?.toString() ?? '');
    _paymentReceivedController = TextEditingController(text: existing?.paymentReceived?.toString() ?? '');
    _nDieselController = TextEditingController(text: existing?.nDieselExpense?.toString() ?? '');
    _hDieselController = TextEditingController(text: existing?.hDieselExpense?.toString() ?? '');
    _opBataController = TextEditingController(text: existing?.opBata?.toString() ?? '');
    _otherExpenseMController = TextEditingController(text: existing?.otherExpenseM?.toString() ?? '');
    _otherExpenseJController = TextEditingController(text: existing?.otherExpenseJ?.toString() ?? '');
    _salaryAdvanceController = TextEditingController(text: existing?.salaryAdvance?.toString() ?? '');
    _paymentReceivedBy = existing?.paymentReceivedBy;
    _nDieselPaidBy = existing?.nDieselPaidBy;
    _hDieselPaidBy = existing?.hDieselPaidBy;
    _opBataPaidBy = existing?.opBataPaidBy;
    _photoUrl = existing?.photoUrl;
  }

  @override
  void dispose() {
    _customerController.dispose();
    _placeController.dispose();
    _totalHoursController.dispose();
    _paymentReceivedController.dispose();
    _nDieselController.dispose();
    _hDieselController.dispose();
    _opBataController.dispose();
    _otherExpenseMController.dispose();
    _otherExpenseJController.dispose();
    _salaryAdvanceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime(_date.year + 1),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (_isEditing) {
        await widget.apiService.updateHitachiJob(
          widget.existing!.id,
          date: _date,
          customerName: _customerController.text.trim(),
          place: _placeController.text.trim(),
          totalHours: double.tryParse(_totalHoursController.text.trim()),
          paymentReceived: double.tryParse(_paymentReceivedController.text.trim()),
          paymentReceivedBy: _paymentReceivedBy,
          nDieselExpense: double.tryParse(_nDieselController.text.trim()),
          nDieselPaidBy: _nDieselPaidBy,
          hDieselExpense: double.tryParse(_hDieselController.text.trim()),
          hDieselPaidBy: _hDieselPaidBy,
          opBata: double.tryParse(_opBataController.text.trim()),
          opBataPaidBy: _opBataPaidBy,
          otherExpenseM: double.tryParse(_otherExpenseMController.text.trim()),
          otherExpenseJ: double.tryParse(_otherExpenseJController.text.trim()),
          salaryAdvance: double.tryParse(_salaryAdvanceController.text.trim()),
          photoUrl: _photoUrl,
        );
      } else {
        await widget.apiService.createHitachiJob(
          date: _date,
          customerName: _customerController.text.trim(),
          place: _placeController.text.trim(),
          totalHours: double.tryParse(_totalHoursController.text.trim()),
          paymentReceived: double.tryParse(_paymentReceivedController.text.trim()),
          paymentReceivedBy: _paymentReceivedBy,
          nDieselExpense: double.tryParse(_nDieselController.text.trim()),
          nDieselPaidBy: _nDieselPaidBy,
          hDieselExpense: double.tryParse(_hDieselController.text.trim()),
          hDieselPaidBy: _hDieselPaidBy,
          opBata: double.tryParse(_opBataController.text.trim()),
          opBataPaidBy: _opBataPaidBy,
          otherExpenseM: double.tryParse(_otherExpenseMController.text.trim()),
          otherExpenseJ: double.tryParse(_otherExpenseJController.text.trim()),
          salaryAdvance: double.tryParse(_salaryAdvanceController.text.trim()),
          photoUrl: _photoUrl,
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

  Widget _payerDropdown({
    required String label,
    required HitachiPayer? value,
    required void Function(HitachiPayer?) onChanged,
  }) {
    return DropdownButtonFormField<HitachiPayer>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      hint: const Text('Paid by'),
      items: HitachiPayer.values
          .map((p) => DropdownMenuItem(value: p, child: Text(hitachiPayerLabel(p))))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _amountWithPayer({
    required TextEditingController controller,
    required String label,
    required HitachiPayer? payer,
    required void Function(HitachiPayer?) onPayerChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(labelText: label, prefixText: '₹ '),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _payerDropdown(label: 'Paid by', value: payer, onChanged: onPayerChanged),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Hitachi Job' : 'Log Hitachi Data')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month, size: 18),
                label: Text('${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _customerController,
                decoration: const InputDecoration(labelText: 'Customer Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _placeController,
                decoration: const InputDecoration(labelText: 'Place'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _totalHoursController,
                decoration: const InputDecoration(labelText: 'Total Hours'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 20),
              _amountWithPayer(
                controller: _paymentReceivedController,
                label: 'Payment Received',
                payer: _paymentReceivedBy,
                onPayerChanged: (v) => setState(() => _paymentReceivedBy = v),
              ),
              const SizedBox(height: 16),
              _amountWithPayer(
                controller: _nDieselController,
                label: 'N Diesel (Nissan)',
                payer: _nDieselPaidBy,
                onPayerChanged: (v) => setState(() => _nDieselPaidBy = v),
              ),
              const SizedBox(height: 16),
              _amountWithPayer(
                controller: _hDieselController,
                label: 'H Diesel (Hitachi)',
                payer: _hDieselPaidBy,
                onPayerChanged: (v) => setState(() => _hDieselPaidBy = v),
              ),
              const SizedBox(height: 16),
              _amountWithPayer(
                controller: _opBataController,
                label: 'OP Bata',
                payer: _opBataPaidBy,
                onPayerChanged: (v) => setState(() => _opBataPaidBy = v),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _otherExpenseMController,
                decoration: const InputDecoration(labelText: 'Other Exp (Muthu)', prefixText: '₹ '),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _otherExpenseJController,
                decoration: const InputDecoration(labelText: 'Other Exp (Jamal)', prefixText: '₹ '),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _salaryAdvanceController,
                decoration: const InputDecoration(labelText: 'Salary in Advance', prefixText: '₹ '),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 20),
              const Text('Photo', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              PhotoPickerField(
                apiService: widget.apiService,
                photoUrl: _photoUrl,
                onChanged: (url) => setState(() => _photoUrl = url),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEditing ? 'Save Changes' : 'Log Hitachi Data'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
