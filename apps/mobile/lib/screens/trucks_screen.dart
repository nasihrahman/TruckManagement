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
                  trailing: const Icon(Icons.chevron_right),
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
