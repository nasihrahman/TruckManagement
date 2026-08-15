import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/web_download.dart';

class OperationsReportScreen extends StatefulWidget {
  const OperationsReportScreen({super.key, required this.apiService});
  final ApiService apiService;

  @override
  State<OperationsReportScreen> createState() => _OperationsReportScreenState();
}

class _OperationsReportScreenState extends State<OperationsReportScreen> {
  String _period = 'weekly';
  bool _isExporting = false;
  late Future<Map<String, dynamic>> _reportFuture;

  static const _periodLabels = {
    'weekly': 'This Week',
    'monthly': 'This Month',
    'quarterly': 'This Quarter',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _reportFuture = widget.apiService.fetchOperationsReport(period: _period);
    });
  }

  Future<void> _export() async {
    setState(() => _isExporting = true);
    try {
      final bytes = await widget.apiService.exportOperationsReport(period: _period);
      downloadBytes(bytes, 'operations-report-$_period.xlsx');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export downloaded')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operations Report'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<String>(
              segments: _periodLabels.entries
                  .map((e) => ButtonSegment(value: e.key, label: Text(e.value)))
                  .toList(),
              selected: {_period},
              onSelectionChanged: (selection) {
                setState(() => _period = selection.first);
                _load();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _reportFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }
                final report = snapshot.data!;
                final trips = report['trips'] as Map<String, dynamic>;
                final expenses = report['expenses'] as Map<String, dynamic>;
                final tripsByDriver = (trips['byDriver'] as List).cast<Map<String, dynamic>>();
                final expensesByDriver = (expenses['byDriver'] as List).cast<Map<String, dynamic>>();
                final byCategory = (expenses['byCategory'] as Map).cast<String, dynamic>();
                final completionRate = (trips['completionRate'] as num).toDouble();

                return RefreshIndicator(
                  onRefresh: () async => _load(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        '${_formatDate(report['rangeStart'])} – ${_formatDate(report['rangeEnd'])}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Trips', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _Metric(label: 'Created', value: '${trips['createdTotal']}'),
                                  _Metric(label: 'Delivered', value: '${trips['delivered']}', color: Colors.green),
                                  _Metric(label: 'Failed', value: '${trips['failed']}', color: Colors.red),
                                  _Metric(
                                    label: 'Completion',
                                    value: '${(completionRate * 100).toStringAsFixed(0)}%',
                                  ),
                                ],
                              ),
                              if (tripsByDriver.isNotEmpty) ...[
                                const Divider(height: 24),
                                const Text('By Driver', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                for (final d in tripsByDriver)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(d['name']?.toString() ?? 'Driver')),
                                        Text('${d['delivered']} delivered · ${d['failed']} failed',
                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 8),
                              Text('Total: ₹${(expenses['total'] as num).toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 18)),
                              const SizedBox(height: 4),
                              Text(
                                'Fuel ₹${(byCategory['FUEL'] ?? 0).toStringAsFixed(2)} · '
                                'Fines ₹${(byCategory['FINE'] ?? 0).toStringAsFixed(2)} · '
                                'Other ₹${(byCategory['OTHER'] ?? 0).toStringAsFixed(2)}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              if (expensesByDriver.isNotEmpty) ...[
                                const Divider(height: 24),
                                const Text('By Driver', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                for (final d in expensesByDriver)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(d['name']?.toString() ?? 'Driver')),
                                        Text('₹${(d['total'] as num).toStringAsFixed(2)}',
                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isExporting ? null : _export,
                          icon: _isExporting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.download),
                          label: const Text('Export to Excel'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        ],
      ),
    );
  }
}
