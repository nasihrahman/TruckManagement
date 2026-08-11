import 'package:flutter/material.dart';
import '../models/driver.dart';
import '../models/trip.dart';
import '../models/truck.dart';
import '../services/api_service.dart';

class TripFormScreen extends StatefulWidget {
  const TripFormScreen({super.key, required this.apiService, this.existing});

  final ApiService apiService;
  /// null = create mode, non-null = edit mode (pre-filled, PATCHes on submit).
  final Trip? existing;

  @override
  State<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends State<TripFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _originController;
  late final TextEditingController _destinationController;
  String? _selectedDriverId;
  String? _selectedTruckId;
  bool _isLoading = false;
  bool _isLoadingResources = true;
  List<Driver> _drivers = [];
  List<Truck> _trucks = [];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _originController = TextEditingController(text: widget.existing?.origin ?? '');
    _destinationController = TextEditingController(text: widget.existing?.destination ?? '');
    _selectedDriverId = widget.existing?.driverId;
    _selectedTruckId = widget.existing?.truckId;
    _loadResources();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _loadResources() async {
    setState(() => _isLoadingResources = true);
    try {
      final results = await Future.wait([
        widget.apiService.fetchDrivers(),
        widget.apiService.fetchTrucks(),
      ]);
      setState(() {
        _drivers = results[0] as List<Driver>;
        _trucks = results[1] as List<Truck>;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoadingResources = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final Trip savedTrip;
      if (_isEditing) {
        savedTrip = await widget.apiService.updateTrip(
          widget.existing!.id,
          origin: _originController.text,
          destination: _destinationController.text,
          driverId: _selectedDriverId,
          truckId: _selectedTruckId,
        );
      } else {
        savedTrip = await widget.apiService.createTrip(
          origin: _originController.text,
          destination: _destinationController.text,
          driverId: _selectedDriverId,
          truckId: _selectedTruckId,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, savedTrip);
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
      appBar: AppBar(title: Text(_isEditing ? 'Edit Trip' : 'Create Trip')),
      body: _isLoadingResources
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _originController,
                      decoration: const InputDecoration(labelText: 'Origin'),
                      validator: (value) => value == null || value.isEmpty ? 'Enter origin' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _destinationController,
                      decoration: const InputDecoration(labelText: 'Destination'),
                      validator: (value) => value == null || value.isEmpty ? 'Enter destination' : null,
                    ),
                    const SizedBox(height: 20),
                    const Text('Driver', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDriverId,
                      isExpanded: true,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      hint: const Text('Unassigned'),
                      items: _drivers
                          .map((d) => DropdownMenuItem<String>(value: d.id, child: Text(d.name)))
                          .toList(),
                      onChanged: (val) => setState(() {
                        _selectedDriverId = val;
                        final matches = _drivers.where((d) => d.id == val);
                        if (matches.isNotEmpty && matches.first.defaultTruckId != null) {
                          _selectedTruckId = matches.first.defaultTruckId;
                        }
                      }),
                    ),
                    const SizedBox(height: 20),
                    const Text('Truck', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTruckId,
                      isExpanded: true,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      hint: const Text('Unassigned'),
                      items: _trucks
                          .map((t) => DropdownMenuItem<String>(
                                value: t.id,
                                child: Text(t.displayName),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedTruckId = val),
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_isEditing ? 'Save Changes' : 'Create Trip'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
