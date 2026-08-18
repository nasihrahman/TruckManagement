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

  @override
  void initState() {
    super.initState();
    _refresh();
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
          final jobs = snapshot.data ?? [];
          if (jobs.isEmpty) {
            return const Center(child: Text('No Hitachi jobs logged yet'));
          }
          return ListView.builder(
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
                  subtitle: Text(
                    '${_formatDate(job.date)}'
                    '${job.totalHours != null ? ' · ${job.totalHours} hrs' : ''}'
                    ' · Bal (J): ₹${job.balanceJ.toStringAsFixed(0)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                    onPressed: () => _deleteJob(job),
                  ),
                  onTap: () => _editJob(job),
                ),
              );
            },
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
