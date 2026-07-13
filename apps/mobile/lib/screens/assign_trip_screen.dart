import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/driver.dart';

class AssignTripScreen extends StatefulWidget {
  final ApiService apiService;
  final String tripId;
  final String? initialDriverId;
  final String? initialTruckId;

  const AssignTripScreen({
    super.key, 
    required this.apiService, 
    required this.tripId, 
    this.initialDriverId, 
    this.initialTruckId
  });

  @override
  State<AssignTripScreen> createState() => _AssignTripScreenState();
}

class _AssignTripScreenState extends State<AssignTripScreen> {
  String? selectedDriverId;
  String? selectedTruckId;
  bool _isLoading = false;
  List<Driver> _drivers = [];
  List<Map<String, dynamic>> _trucks = [];

  @override
  void initState() {
    super.initState();
    selectedDriverId = widget.initialDriverId;
    selectedTruckId = widget.initialTruckId;
    _loadResources();
  }

  Future<void> _loadResources() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        widget.apiService.fetchDrivers(),
        widget.apiService.fetchTrucks(),
      ]);
      setState(() {
        _drivers = results[0] as List<Driver>;
        _trucks = results[1] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _assign() async {
    setState(() => _isLoading = true);
    try {
      await widget.apiService.assignTrip(
        widget.tripId,
        driverId: selectedDriverId,
        truckId: selectedTruckId,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign Trip')),
      body: _isLoading && _drivers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Driver', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: selectedDriverId,
                    items: _drivers.map((d) => DropdownMenuItem<String>(
                      value: d.id,
                      child: Text(d.name),
                    )).toList(),
                    onChanged: (val) => setState(() => selectedDriverId = val),
                  ),
                  const SizedBox(height: 24),
                  const Text('Select Truck', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: selectedTruckId,
                    items: _trucks.map((t) => DropdownMenuItem<String>(
                      value: t['id'] as String,
                      child: Text(t['plate'] as String),
                    )).toList(),
                    onChanged: (val) => setState(() => selectedTruckId = val),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _assign,
                      child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Assign'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
