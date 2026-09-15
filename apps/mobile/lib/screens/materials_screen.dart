import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/material.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key, required this.apiService});
  final ApiService apiService;

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  late Future<void> _loadFuture;
  List<CargoMaterial> _materials = [];
  bool _isReordering = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _refresh();
  }

  Future<void> _refresh() async {
    final materials = await widget.apiService.fetchCargoMaterials();
    if (!mounted) return;
    setState(() => _materials = materials);
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
      await widget.apiService.createCargoMaterial(name);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _deleteMaterial(CargoMaterial material) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${material.name}"?'),
        content: const Text(
          'Trips that already used this material keep their other details — only the material on them is cleared. This cannot be undone.',
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
      await widget.apiService.deleteCargoMaterial(material.id);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  /// Reorders optimistically (the drag already shows the new order), then
  /// persists it — on failure, re-fetches to snap back to the real order
  /// rather than leaving the UI showing something the server rejected.
  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final reordered = List<CargoMaterial>.from(_materials);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    setState(() {
      _materials = reordered;
      _isReordering = true;
    });
    try {
      await widget.apiService.reorderMaterials(reordered.map((m) => m.id).toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      await _refresh();
    } finally {
      if (mounted) setState(() => _isReordering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Materials'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _materials.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && _materials.isEmpty) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (_materials.isEmpty) {
            return const Center(child: Text('No materials yet'));
          }
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Drag to reorder — this is the order shown in the Trip Form dropdown.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ),
              Expanded(
                child: AbsorbPointer(
                  absorbing: _isReordering,
                  child: ReorderableListView.builder(
                    itemCount: _materials.length,
                    onReorder: _handleReorder,
                    itemBuilder: (context, index) {
                      final material = _materials[index];
                      return Card(
                        key: ValueKey(material.id),
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: const Icon(Icons.drag_handle),
                          title: Text(material.name),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete',
                            onPressed: () => _deleteMaterial(material),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMaterial,
        child: const Icon(Icons.add),
      ),
    );
  }
}
