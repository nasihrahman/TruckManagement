import 'package:flutter/material.dart';
import '../models/driver.dart';
import '../models/trip.dart';
import '../models/truck.dart';
import '../services/api_service.dart';

class TripFormScreen extends StatefulWidget {
  const TripFormScreen({super.key, required this.apiService, this.existing, this.selfAssignDriverId});

  final ApiService apiService;
  /// null = create mode, non-null = edit mode (pre-filled, PATCHes on submit).
  final Trip? existing;
  /// When set (a Driver creating their own trip), the driver dropdown is hidden
  /// and the trip is always assigned to this id.
  final String? selfAssignDriverId;

  @override
  State<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends State<TripFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _originController;
  late final TextEditingController _destinationController;
  String? _selectedDriverId;
  String? _selectedTruckId;
  DateTime? _deliveryDate;
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
    _selectedDriverId = widget.selfAssignDriverId ?? widget.existing?.driverId;
    _selectedTruckId = widget.existing?.truckId;
    _deliveryDate = widget.existing?.scheduledAt;
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
      if (widget.selfAssignDriverId != null) {
        final results = await Future.wait([
          widget.apiService.fetchTrucks(),
          widget.apiService.fetchMyDriverProfile(),
        ]);
        final trucks = results[0] as List<Truck>;
        final profile = results[1] as Map<String, dynamic>;
        setState(() {
          _trucks = trucks;
          _selectedTruckId ??= profile['defaultTruckId']?.toString();
        });
      } else {
        final results = await Future.wait([
          widget.apiService.fetchDrivers(),
          widget.apiService.fetchTrucks(),
        ]);
        setState(() {
          _drivers = results[0] as List<Driver>;
          _trucks = results[1] as List<Truck>;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoadingResources = false);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickDeliveryDateFromCalendar() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _deliveryDate = DateTime.utc(picked.year, picked.month, picked.day));
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
          scheduledAt: _deliveryDate,
        );
      } else {
        savedTrip = await widget.apiService.createTrip(
          origin: _originController.text,
          destination: _destinationController.text,
          driverId: _selectedDriverId,
          truckId: _selectedTruckId,
          scheduledAt: _deliveryDate,
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
                    if (widget.selfAssignDriverId == null) ...[
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
                    ],
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
                    const SizedBox(height: 20),
                    const Text('Delivery Date', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Builder(builder: (context) {
                      final now = DateTime.now();
                      final today = DateTime.utc(now.year, now.month, now.day);
                      final tomorrow = today.add(const Duration(days: 1));
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Today'),
                            selected: _deliveryDate != null && _isSameDay(_deliveryDate!, today),
                            onSelected: (_) => setState(() => _deliveryDate = today),
                          ),
                          ChoiceChip(
                            label: const Text('Tomorrow'),
                            selected: _deliveryDate != null && _isSameDay(_deliveryDate!, tomorrow),
                            onSelected: (_) => setState(() => _deliveryDate = tomorrow),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.calendar_month, size: 18),
                            label: Text(
                              _deliveryDate != null &&
                                      !_isSameDay(_deliveryDate!, today) &&
                                      !_isSameDay(_deliveryDate!, tomorrow)
                                  ? '${_deliveryDate!.year}-${_deliveryDate!.month.toString().padLeft(2, '0')}-${_deliveryDate!.day.toString().padLeft(2, '0')}'
                                  : 'Choose Date',
                            ),
                            onPressed: _pickDeliveryDateFromCalendar,
                          ),
                        ],
                      );
                    }),
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
