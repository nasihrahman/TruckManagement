import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/truck.dart';
import 'truck_form_screen.dart';

class TrucksScreen extends StatefulWidget {
  const TrucksScreen({super.key, required this.apiService});
  final ApiService apiService;

  @override
  State<TrucksScreen> createState() => _TrucksScreenState();
}

class _TrucksScreenState extends State<TrucksScreen> {
  late Future<List<Truck>> _trucksFuture;

  @override
  void initState() {
    super.initState();
    _refreshTrucks();
  }

  void _refreshTrucks() {
    setState(() {
      _trucksFuture = widget.apiService.fetchTrucks();
    });
  }

  Future<void> _addTruck() async {
    final created = await Navigator.push<Truck>(
      context,
      MaterialPageRoute(builder: (_) => TruckFormScreen(apiService: widget.apiService)),
    );
    if (created != null) _refreshTrucks();
  }

  Future<void> _editTruck(Truck truck) async {
    final updated = await Navigator.push<Truck>(
      context,
      MaterialPageRoute(builder: (_) => TruckFormScreen(apiService: widget.apiService, existing: truck)),
    );
    if (updated != null) _refreshTrucks();
  }

  Future<void> _deleteTruck(Truck truck) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${truck.plate}"?'),
        content: const Text(
          'Trips and drivers that already reference this truck keep their other details — only the truck on them is cleared. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.apiService.deleteTruck(truck.id);
      _refreshTrucks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trucks'),
        actions: [
          IconButton(
            onPressed: _refreshTrucks,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Truck>>(
        future: _trucksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final trucks = snapshot.data ?? [];
          if (trucks.isEmpty) {
            return const Center(child: Text('No trucks found'));
          }
          return ListView.builder(
            itemCount: trucks.length,
            itemBuilder: (context, index) {
              final truck = trucks[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.local_shipping)),
                  title: Text(truck.plate),
                  subtitle: Text(truck.brand?.isNotEmpty == true ? truck.brand! : 'No brand set'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete',
                        onPressed: () => _deleteTruck(truck),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => _editTruck(truck),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTruck,
        child: const Icon(Icons.add),
      ),
    );
  }
}
