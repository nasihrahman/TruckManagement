import 'package:flutter/material.dart';
import '../models/driver.dart';
import '../models/trip.dart';
import '../models/truck.dart';
import '../models/material.dart';
import '../models/supplier.dart';
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
  late final TextEditingController _qtyCfController;
  late final TextEditingController _customerNameController;
  String? _selectedDriverId;
  String? _selectedTruckId;
  String? _selectedMaterialId;
  String? _selectedSupplierId;
  DateTime? _deliveryDate;
  bool _isLoading = false;
  bool _isLoadingResources = true;
  List<Driver> _drivers = [];
  List<Truck> _trucks = [];
  List<CargoMaterial> _materials = [];
  List<Supplier> _suppliers = [];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _originController = TextEditingController(text: widget.existing?.origin ?? '');
    _destinationController = TextEditingController(text: widget.existing?.destination ?? '');
    _qtyCfController = TextEditingController(text: widget.existing?.qtyCf?.toString() ?? '');
    _customerNameController = TextEditingController(text: widget.existing?.customerName ?? '');
    _selectedDriverId = widget.selfAssignDriverId ?? widget.existing?.driverId;
    _selectedTruckId = widget.existing?.truckId;
    _selectedMaterialId = widget.existing?.materialId;
    _selectedSupplierId = widget.existing?.supplierId;
    _deliveryDate = widget.existing?.scheduledAt;
    _loadResources();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _qtyCfController.dispose();
    _customerNameController.dispose();
    super.dispose();
  }

  Future<void> _loadResources() async {
    setState(() => _isLoadingResources = true);
    try {
      if (widget.selfAssignDriverId != null) {
        final results = await Future.wait([
          widget.apiService.fetchTrucks(),
          widget.apiService.fetchMyDriverProfile(),
          widget.apiService.fetchCargoMaterials(),
          widget.apiService.fetchSuppliers(),
        ]);
        final trucks = results[0] as List<Truck>;
        final profile = results[1] as Map<String, dynamic>;
        setState(() {
          _trucks = trucks;
          _selectedTruckId ??= profile['defaultTruckId']?.toString();
          _materials = results[2] as List<CargoMaterial>;
          _suppliers = results[3] as List<Supplier>;
        });
      } else {
        final results = await Future.wait([
          widget.apiService.fetchDrivers(),
          widget.apiService.fetchTrucks(),
          widget.apiService.fetchCargoMaterials(),
          widget.apiService.fetchSuppliers(),
        ]);
        setState(() {
          _drivers = results[0] as List<Driver>;
          _trucks = results[1] as List<Truck>;
          _materials = results[2] as List<CargoMaterial>;
          _suppliers = results[3] as List<Supplier>;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoadingResources = false);
    }
  }

  Future<void> _addMaterial() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Material'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Material name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    try {
      final material = await widget.apiService.createCargoMaterial(name);
      if (!mounted) return;
      setState(() {
        _materials = [..._materials, material];
        _selectedMaterialId = material.id;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _addSupplier() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Supplier'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Supplier name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    try {
      final supplier = await widget.apiService.createSupplier(name);
      if (!mounted) return;
      setState(() {
        _suppliers = [..._suppliers, supplier];
        _selectedSupplierId = supplier.id;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
      final qtyCf = double.tryParse(_qtyCfController.text.trim());
      final Trip savedTrip;
      if (_isEditing) {
        savedTrip = await widget.apiService.updateTrip(
          widget.existing!.id,
          origin: _originController.text,
          destination: _destinationController.text,
          driverId: _selectedDriverId,
          truckId: _selectedTruckId,
          scheduledAt: _deliveryDate,
          materialId: _selectedMaterialId,
          supplierId: _selectedSupplierId,
          qtyCf: qtyCf,
          customerName: _customerNameController.text.trim(),
        );
      } else {
        savedTrip = await widget.apiService.createTrip(
          origin: _originController.text,
          destination: _destinationController.text,
          driverId: _selectedDriverId,
          truckId: _selectedTruckId,
          scheduledAt: _deliveryDate,
          materialId: _selectedMaterialId,
          supplierId: _selectedSupplierId,
          qtyCf: qtyCf,
          customerName: _customerNameController.text.trim(),
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
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Material', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        if (widget.selfAssignDriverId == null)
                          TextButton.icon(
                            onPressed: _addMaterial,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add'),
                          ),
                      ],
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedMaterialId,
                      isExpanded: true,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      hint: const Text('None'),
                      items: _materials
                          .map((m) => DropdownMenuItem<String>(value: m.id, child: Text(m.name)))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedMaterialId = val),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Supplier', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        if (widget.selfAssignDriverId == null)
                          TextButton.icon(
                            onPressed: _addSupplier,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add'),
                          ),
                      ],
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSupplierId,
                      isExpanded: true,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      hint: const Text('None'),
                      items: _suppliers
                          .map((s) => DropdownMenuItem<String>(value: s.id, child: Text(s.name)))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedSupplierId = val),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _qtyCfController,
                      decoration: const InputDecoration(labelText: 'Qty (CF) (Optional)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customerNameController,
                      decoration: const InputDecoration(labelText: 'Customer Name (Optional)'),
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
