import 'package:flutter/material.dart';
import '../models/hitachi_job.dart';
import '../services/api_service.dart';
import 'hitachi_job_form_screen.dart';

class HitachiJobsScreen extends StatefulWidget {
  const HitachiJobsScreen({super.key, required this.apiService});
  final ApiService apiService;

  @override
  State<HitachiJobsScreen> createState() => _HitachiJobsScreenState();
}

class _HitachiJobsScreenState extends State<HitachiJobsScreen> {
  late Future<List<HitachiJob>> _jobsFuture;

  /// null = "All drivers". Filtered client-side from the loaded list rather
  /// than refetching, matching how the trips screen filters.
  String? _driverFilterId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// Driver options are derived from the jobs themselves, so the dropdown only
  /// ever offers people who actually have entries — no empty result states.
  List<MapEntry<String, String>> _driverOptions(List<HitachiJob> jobs) {
    final byId = <String, String>{};
    for (final job in jobs) {
      if (job.driverId.isEmpty) continue;
      byId.putIfAbsent(job.driverId, () => job.driverName ?? 'Driver');
    }
    final entries = byId.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    return entries;
  }

  void _refresh() {
    setState(() {
      _jobsFuture = widget.apiService.fetchHitachiJobs();
    });
  }

  Future<void> _addJob() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => HitachiJobFormScreen(apiService: widget.apiService)),
    );
    if (saved == true) _refresh();
  }

  Future<void> _editJob(HitachiJob job) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => HitachiJobFormScreen(apiService: widget.apiService, existing: job)),
    );
    if (saved == true) _refresh();
  }

  Future<void> _deleteJob(HitachiJob job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text('This Hitachi job log will be permanently removed. This cannot be undone.'),
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
      await widget.apiService.deleteHitachiJob(job.id);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hitachi Jobs'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<HitachiJob>>(
        future: _jobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final allJobs = snapshot.data ?? [];
          if (allJobs.isEmpty) {
            return const Center(child: Text('No Hitachi jobs logged yet'));
          }

          final options = _driverOptions(allJobs);
          // Guard against a stale selection after a refresh drops that driver.
          final selected = options.any((o) => o.key == _driverFilterId) ? _driverFilterId : null;
          final jobs = selected == null
              ? allJobs
              : allJobs.where((j) => j.driverId == selected).toList();

          return Column(
            children: [
              if (options.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: DropdownButtonFormField<String?>(
                    initialValue: selected,
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: 'Logged by',
                      prefixIcon: const Icon(Icons.person_outline),
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
              if (jobs.isEmpty)
                const Expanded(child: Center(child: Text('No jobs for this driver')))
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: jobs.length,
                    itemBuilder: (context, index) {
                      final job = jobs[index];
                      final title = [job.customerName, job.place]
                          .where((s) => s != null && s.trim().isNotEmpty)
                          .join(' · ');
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(title.isEmpty ? 'Hitachi Job' : title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_formatDate(job.date)}'
                                '${job.truckName != null ? ' · ${job.truckName}' : ''}'
                                '${job.totalHours != null ? ' · ${job.totalHours} hrs' : ''}'
                                ' · Bal (J): ₹${job.balanceJ.toStringAsFixed(0)}',
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.person_outline,
                                      size: 13, color: Theme.of(context).hintColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Logged by ${job.driverName ?? 'Unknown'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).hintColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete',
                            onPressed: () => _deleteJob(job),
                          ),
                          onTap: () => _editJob(job),
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
        onPressed: _addJob,
        icon: const Icon(Icons.add),
        label: const Text('Log Hitachi Data'),
      ),
    );
  }
}
