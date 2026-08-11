import 'package:flutter/material.dart';
import '../models/truck.dart';
import '../services/api_service.dart';

class TruckFormScreen extends StatefulWidget {
  const TruckFormScreen({super.key, required this.apiService, this.existing});

  final ApiService apiService;
  /// null = create mode, non-null = edit mode (pre-filled, PATCHes on submit).
  final Truck? existing;

  @override
  State<TruckFormScreen> createState() => _TruckFormScreenState();
}

class _TruckFormScreenState extends State<TruckFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _plateController;
  late final TextEditingController _brandController;
  late final TextEditingController _vinController;
  bool _isLoading = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _plateController = TextEditingController(text: widget.existing?.plate ?? '');
    _brandController = TextEditingController(text: widget.existing?.brand ?? '');
    _vinController = TextEditingController(text: widget.existing?.vin ?? '');
  }

  @override
  void dispose() {
    _plateController.dispose();
    _brandController.dispose();
    _vinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final Truck savedTruck;
      if (_isEditing) {
        savedTruck = await widget.apiService.updateTruck(
          widget.existing!.id,
          plate: _plateController.text,
          brand: _brandController.text,
          vin: _vinController.text,
        );
      } else {
        savedTruck = await widget.apiService.createTruck(
          plate: _plateController.text,
          brand: _brandController.text,
          vin: _vinController.text,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, savedTruck);
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
      appBar: AppBar(title: Text(_isEditing ? 'Edit Truck' : 'Add Truck')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _plateController,
                decoration: const InputDecoration(labelText: 'Truck Number'),
                validator: (value) => value == null || value.isEmpty ? 'Enter truck number' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(labelText: 'Brand Name'),
                validator: (value) => value == null || value.isEmpty ? 'Enter brand name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vinController,
                decoration: const InputDecoration(labelText: 'VIN (Optional)'),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEditing ? 'Save Changes' : 'Add Truck'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
