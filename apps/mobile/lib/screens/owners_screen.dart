import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/owner.dart';
import 'add_owner_screen.dart';

class OwnersScreen extends StatefulWidget {
  const OwnersScreen({super.key, required this.apiService});
  final ApiService apiService;

  @override
  State<OwnersScreen> createState() => _OwnersScreenState();
}

class _OwnersScreenState extends State<OwnersScreen> {
  late Future<List<Owner>> _ownersFuture;

  @override
  void initState() {
    super.initState();
    _refreshOwners();
  }

  void _refreshOwners() {
    setState(() {
      _ownersFuture = widget.apiService.fetchOwners();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owners'),
        actions: [
          IconButton(onPressed: _refreshOwners, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<Owner>>(
        future: _ownersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final owners = snapshot.data ?? [];
          if (owners.isEmpty) {
            return const Center(child: Text('No owners found'));
          }
          return ListView.builder(
            itemCount: owners.length,
            itemBuilder: (context, index) {
              final owner = owners[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(owner.name.isNotEmpty ? owner.name[0].toUpperCase() : '?'),
                  ),
                  title: Text(owner.name),
                  subtitle: Text(owner.email?.isNotEmpty == true ? '${owner.phone} · ${owner.email}' : owner.phone),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddOwnerScreen(apiService: widget.apiService)),
          );
          _refreshOwners();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
