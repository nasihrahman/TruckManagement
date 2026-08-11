import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/driver.dart';
import '../models/truck.dart';

class AddDriverScreen extends StatefulWidget {
  const AddDriverScreen({super.key, required this.apiService, this.existing});
  final ApiService apiService;
  /// null = create mode, non-null = edit mode (pre-filled, PATCHes on submit).
  final Driver? existing;

  @override
  State<AddDriverScreen> createState() => _AddDriverScreenState();
}

class _AddDriverScreenState extends State<AddDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _licenseController;
  final _passwordController = TextEditingController();
  String? _selectedTruckId;

  bool _isLoading = false;
  bool _isLoadingTrucks = true;
  List<Truck> _trucks = [];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _phoneController = TextEditingController(text: widget.existing?.phone ?? '');
    _emailController = TextEditingController(text: widget.existing?.email ?? '');
    _licenseController = TextEditingController(text: widget.existing?.licenseNumber ?? '');
    _selectedTruckId = widget.existing?.defaultTruckId;
    _loadTrucks();
  }

  Future<void> _loadTrucks() async {
    setState(() => _isLoadingTrucks = true);
    try {
      final trucks = await widget.apiService.fetchTrucks();
      setState(() => _trucks = trucks);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoadingTrucks = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (_isEditing) {
        await widget.apiService.updateDriver(
          widget.existing!.id,
          name: _nameController.text,
          phone: _phoneController.text,
          email: _emailController.text.isEmpty ? null : _emailController.text,
          licenseNumber: _licenseController.text.isEmpty ? null : _licenseController.text,
          defaultTruckId: _selectedTruckId,
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      final result = await widget.apiService.createDriver(
        name: _nameController.text,
        phone: _phoneController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        licenseNumber: _licenseController.text.isEmpty ? null : _licenseController.text,
        initialPassword: _passwordController.text.isEmpty ? null : _passwordController.text,
        defaultTruckId: _selectedTruckId,
      );

      if (!mounted) return;

      // Show temp password dialog
      final tempPassword = result['tempPassword'];
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Driver Created'),
          content: Text('The temporary password for the driver is: $tempPassword\nPlease share this with them.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to DriversScreen
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _licenseController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Driver' : 'Add New Driver')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (value) => value == null || value.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                validator: (value) => value == null || value.isEmpty ? 'Enter phone' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email (Optional)'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _licenseController,
                decoration: const InputDecoration(labelText: 'License Number (Optional)'),
              ),
              if (!_isEditing) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Initial Password (Optional)'),
                  obscureText: true,
                ),
              ],
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Default Truck (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              _isLoadingTrucks
                  ? const LinearProgressIndicator()
                  : DropdownButtonFormField<String>(
                      initialValue: _selectedTruckId,
                      isExpanded: true,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      hint: const Text('None'),
                      items: _trucks
                          .map((t) => DropdownMenuItem<String>(value: t.id, child: Text(t.displayName)))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedTruckId = val),
                    ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: Text(_isEditing ? 'Save Changes' : 'Create Driver'),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
