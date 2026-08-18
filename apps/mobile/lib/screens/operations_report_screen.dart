import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/web_download.dart';

class OperationsReportScreen extends StatefulWidget {
  const OperationsReportScreen({super.key, required this.apiService});
  final ApiService apiService;

  @override
  State<OperationsReportScreen> createState() => _OperationsReportScreenState();
}

class _PeriodOption {
  _PeriodOption({required this.label, required this.anchorDate});
  final String label;
  final DateTime anchorDate;
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
const _fullMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

DateTime _mondayOf(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

List<_PeriodOption> _weeklyOptions() {
  final thisMonday = _mondayOf(DateTime.now());
  return List.generate(26, (i) {
    final start = thisMonday.subtract(Duration(days: 7 * i));
    final end = start.add(const Duration(days: 6));
    final startLabel = '${_months[start.month - 1]} ${start.day}';
    final endLabel = start.month == end.month ? '${end.day}' : '${_months[end.month - 1]} ${end.day}';
    return _PeriodOption(label: '$startLabel–$endLabel, ${end.year}', anchorDate: start);
  });
}

List<_PeriodOption> _monthlyOptions() {
  final now = DateTime.now();
  final thisMonthStart = DateTime.utc(now.year, now.month, 1);
  return List.generate(24, (i) {
    final d = DateTime.utc(thisMonthStart.year, thisMonthStart.month - i, 1);
    return _PeriodOption(label: '${_fullMonths[d.month - 1]} ${d.year}', anchorDate: d);
  });
}

List<_PeriodOption> _quarterlyOptions() {
  final now = DateTime.now();
  final thisQuarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
  final thisQuarterStart = DateTime.utc(now.year, thisQuarterMonth, 1);
  return List.generate(12, (i) {
    final d = DateTime.utc(thisQuarterStart.year, thisQuarterStart.month - i * 3, 1);
    final quarter = ((d.month - 1) ~/ 3) + 1;
    return _PeriodOption(label: 'Q$quarter ${d.year}', anchorDate: d);
  });
}

class _OperationsReportScreenState extends State<OperationsReportScreen> {
  String _period = 'weekly';
  late List<_PeriodOption> _periodOptions;
  int _selectedIndex = 0;
  bool _isExporting = false;
  bool _isExportingDetail = false;
  bool _isExportingByTruck = false;
  bool _isExportingHitachi = false;
  late Future<Map<String, dynamic>> _reportFuture;

  static const _periodLabels = {
    'weekly': 'This Week',
    'monthly': 'This Month',
    'quarterly': 'This Quarter',
  };

  @override
  void initState() {
    super.initState();
    _periodOptions = _weeklyOptions();
    _load();
  }

  void _regeneratePeriodOptions() {
    switch (_period) {
      case 'weekly':
        _periodOptions = _weeklyOptions();
        break;
      case 'monthly':
        _periodOptions = _monthlyOptions();
        break;
      case 'quarterly':
        _periodOptions = _quarterlyOptions();
        break;
    }
    _selectedIndex = 0;
  }

  DateTime get _anchorDate => _periodOptions[_selectedIndex].anchorDate;

  void _load() {
    setState(() {
      _reportFuture = widget.apiService.fetchOperationsReport(period: _period, date: _anchorDate);
    });
  }

  Future<void> _export() async {
    setState(() => _isExporting = true);
    try {
      final bytes = await widget.apiService.exportOperationsReport(period: _period, date: _anchorDate);
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

  Future<void> _exportDetail() async {
    setState(() => _isExportingDetail = true);
    try {
      final bytes = await widget.apiService.exportOperationsDetail(period: _period, date: _anchorDate);
      downloadBytes(bytes, 'operations-detail-$_period.xlsx');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export downloaded')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isExportingDetail = false);
    }
  }

  Future<void> _exportByTruck() async {
    setState(() => _isExportingByTruck = true);
    try {
      final bytes = await widget.apiService.exportTripsByTruckExcel(period: _period, date: _anchorDate);
      downloadBytes(bytes, 'trips-by-truck-$_period.xlsx');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export downloaded')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isExportingByTruck = false);
    }
  }

  Future<void> _exportHitachi() async {
    setState(() => _isExportingHitachi = true);
    try {
      final bytes = await widget.apiService.exportHitachiJobs(period: _period, date: _anchorDate);
      downloadBytes(bytes, 'hitachi-jobs-$_period.xlsx');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export downloaded')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isExportingHitachi = false);
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
                setState(() {
                  _period = selection.first;
                  _regeneratePeriodOptions();
                });
                _load();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: DropdownButtonFormField<int>(
              initialValue: _selectedIndex,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              items: [
                for (var i = 0; i < _periodOptions.length; i++)
                  DropdownMenuItem(value: i, child: Text(_periodOptions[i].label)),
              ],
              onChanged: (index) {
                if (index == null) return;
                setState(() => _selectedIndex = index);
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
                          label: const Text('Export Summary to Excel'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isExportingDetail ? null : _exportDetail,
                          icon: _isExportingDetail
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.list_alt),
                          label: const Text('Export Full Details (trips + expenses)'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isExportingByTruck ? null : _exportByTruck,
                          icon: _isExportingByTruck
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.local_shipping_outlined),
                          label: const Text('Export by Truck (Fuel/Fine/Other)'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isExportingHitachi ? null : _exportHitachi,
                          icon: _isExportingHitachi
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.construction_outlined),
                          label: const Text('Export Hitachi Jobs'),
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
