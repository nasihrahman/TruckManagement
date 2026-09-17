import 'package:flutter/material.dart';
import '../models/daily_expense.dart';
import '../models/expense.dart';
import '../services/api_service.dart';
import '../services/web_download.dart';
import 'daily_expense_form_screen.dart';

class DailyExpensesScreen extends StatefulWidget {
  const DailyExpensesScreen({super.key, required this.apiService, this.isOwner = false});

  final ApiService apiService;
  final bool isOwner;

  @override
  State<DailyExpensesScreen> createState() => _DailyExpensesScreenState();
}

class _DailyExpensesScreenState extends State<DailyExpensesScreen> {
  late Future<List<DailyExpense>> _entriesFuture;
  String? _driverFilterId;
  String _exportPeriod = 'daily';
  bool _isExporting = false;
  bool _isExportingTrips = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _entriesFuture = widget.apiService.fetchDailyExpenses();
    });
  }

  Future<void> _addExpense() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DailyExpenseFormScreen(apiService: widget.apiService, isOwner: widget.isOwner),
      ),
    );
    if (saved == true) _refresh();
  }

  Future<void> _deleteExpense(DailyExpense entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this expense?'),
        content: const Text('This cannot be undone.'),
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
      await widget.apiService.deleteDailyExpense(entry.id);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _export() async {
    setState(() => _isExporting = true);
    try {
      final bytes = await widget.apiService.exportDailyExpenses(period: _exportPeriod);
      final saved = await downloadBytes(bytes, 'daily-expenses-$_exportPeriod.xlsx');
      if (!mounted || !saved) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export downloaded')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Trips for the period, per truck, matched against that truck's logged
  /// daily Fuel/Fine/Other totals — the combined report, since drivers log
  /// one lump total per day rather than per-trip fuel amounts.
  Future<void> _exportTripsByTruck() async {
    setState(() => _isExportingTrips = true);
    try {
      final bytes = await widget.apiService.exportTripsByTruckExcel(period: _exportPeriod);
      final saved = await downloadBytes(bytes, 'trips-by-truck-$_exportPeriod.xlsx');
      if (!mounted || !saved) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export downloaded')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isExportingTrips = false);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  List<MapEntry<String, String>> _driverOptions(List<DailyExpense> entries) {
    final byId = <String, String>{};
    for (final e in entries) {
      if (e.driverId.isEmpty) continue;
      byId.putIfAbsent(e.driverId, () => e.driverName ?? 'Driver');
    }
    final list = byId.entries.toList()..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Expenses'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<DailyExpense>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final allEntries = snapshot.data ?? [];

          final options = widget.isOwner ? _driverOptions(allEntries) : const <MapEntry<String, String>>[];
          final selected = options.any((o) => o.key == _driverFilterId) ? _driverFilterId : null;
          final entries = selected == null ? allEntries : allEntries.where((e) => e.driverId == selected).toList();
          final total = entries.fold<double>(0, (sum, e) => sum + e.amount);

          return Column(
            children: [
              if (widget.isOwner) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: selected,
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: 'Driver',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('All drivers')),
                            ...options.map((o) => DropdownMenuItem<String?>(value: o.key, child: Text(o.value))),
                          ],
                          onChanged: (val) => setState(() => _driverFilterId = val),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: DropdownButtonFormField<String>(
                    initialValue: _exportPeriod,
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: 'Export period',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'daily', child: Text('Today')),
                      DropdownMenuItem(value: 'weekly', child: Text('This Week')),
                      DropdownMenuItem(value: 'monthly', child: Text('This Month')),
                      DropdownMenuItem(value: 'quarterly', child: Text('This Quarter')),
                    ],
                    onChanged: (val) => setState(() => _exportPeriod = val ?? 'daily'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isExportingTrips ? null : _exportTripsByTruck,
                          icon: _isExportingTrips
                              ? const SizedBox(
                                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.local_shipping_outlined, size: 18),
                          label: const Text('Trips + Expenses by Truck'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isExporting ? null : _export,
                          icon: _isExporting
                              ? const SizedBox(
                                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.file_download, size: 18),
                          label: const Text('Daily Expenses Only'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total: ₹${total.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (entries.isEmpty)
                const Expanded(child: Center(child: Text('No daily expenses logged yet')))
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text('${expenseCategoryLabel(entry.category)} · ₹${entry.amount.toStringAsFixed(0)}'),
                          subtitle: Text(
                            [
                              _formatDate(entry.date),
                              if (widget.isOwner) entry.driverName ?? 'Driver',
                              if (entry.truckPlate != null) entry.truckPlate,
                              if (entry.reason != null && entry.reason!.isNotEmpty) entry.reason,
                            ].join(' · '),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete',
                            onPressed: () => _deleteExpense(entry),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpense,
        icon: const Icon(Icons.add),
        label: const Text('Log Daily Expense'),
      ),
    );
  }
}
