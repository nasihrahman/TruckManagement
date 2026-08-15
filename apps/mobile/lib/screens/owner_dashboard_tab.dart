import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../models/driver.dart';
import '../models/truck.dart';
import '../services/api_service.dart';
import '../services/web_download.dart';
import 'owner_trip_detail_screen.dart';
import 'drivers_screen.dart';
import 'trucks_screen.dart';

class OwnerDashboardTab extends StatefulWidget {
  const OwnerDashboardTab({super.key, required this.apiService, required this.onLogout});
  final ApiService apiService;
  final VoidCallback onLogout;

  @override
  State<OwnerDashboardTab> createState() => OwnerDashboardTabState();
}

class OwnerDashboardTabState extends State<OwnerDashboardTab> {
  Future<_DashboardData>? _dataFuture;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    setState(() {
      _dataFuture = _load();
    });
  }

  Future<_DashboardData> _load() async {
    final results = await Future.wait([
      widget.apiService.fetchTrips(),
      widget.apiService.fetchDrivers(),
      widget.apiService.fetchTrucks(),
      widget.apiService.fetchOnlineLocations(),
    ]);
    return _DashboardData(
      trips: results[0] as List<Trip>,
      drivers: results[1] as List<Driver>,
      trucks: results[2] as List<Truck>,
      onlineDrivers: results[3] as List<Map<String, dynamic>>,
    );
  }

  Future<void> _openTripDetail(Trip trip) async {
    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => OwnerTripDetailScreen(apiService: widget.apiService, trip: trip)),
    );
    if (res == true) refresh();
  }

  Future<void> _export() async {
    setState(() => _isExporting = true);
    try {
      final bytes = await widget.apiService.exportTripsExcel();
      downloadBytes(bytes, 'trips-export.xlsx');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export downloaded')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: FutureBuilder<_DashboardData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'Trucks',
                        value: '${data.trucks.length}',
                        icon: Icons.local_shipping,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => TrucksScreen(apiService: widget.apiService)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        label: 'Drivers (${data.activeDriverCount} active)',
                        value: '${data.drivers.length}',
                        icon: Icons.people,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => DriversScreen(apiService: widget.apiService)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(label: 'Assigned', count: data.statusCounts['ASSIGNED'] ?? 0, color: Colors.blue),
                    _StatusChip(label: 'In Transit', count: data.statusCounts['IN_TRANSIT'] ?? 0, color: Colors.orange),
                    _StatusChip(label: 'Delivered', count: data.statusCounts['DELIVERED'] ?? 0, color: Colors.green),
                    _StatusChip(label: 'Failed', count: data.statusCounts['FAILED'] ?? 0, color: Colors.red),
                  ],
                ),
                const SizedBox(height: 16),
                _OnlineDriversCard(drivers: data.onlineDrivers),
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Due Today',
                  emptyLabel: 'Nothing due today',
                  trips: data.dueToday,
                  onTap: _openTripDetail,
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Due Tomorrow',
                  emptyLabel: 'Nothing due tomorrow',
                  trips: data.dueTomorrow,
                  onTap: _openTripDetail,
                ),
                if (data.overdue.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Overdue',
                    emptyLabel: '',
                    trips: data.overdue,
                    onTap: _openTripDetail,
                    accentColor: Colors.red,
                  ),
                ],
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('This Week\'s Expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Total: ₹${data.weeklyExpenseTotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 4),
                        Text(
                          'Fuel ₹${data.weeklyByCategory['FUEL']?.toStringAsFixed(2) ?? '0.00'} · '
                          'Fines ₹${data.weeklyByCategory['FINE']?.toStringAsFixed(2) ?? '0.00'} · '
                          'Other ₹${data.weeklyByCategory['OTHER']?.toStringAsFixed(2) ?? '0.00'}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'Unclosed Trips',
                        value: '${data.unclosedCount}',
                        icon: Icons.lock_open,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        label: 'Failed Trips',
                        value: '${data.statusCounts['FAILED'] ?? 0}',
                        icon: Icons.error_outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isExporting ? null : _export,
                    icon: _isExporting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download),
                    label: const Text('Export Trips to Excel'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardData {
  final List<Trip> trips;
  final List<Driver> drivers;
  final List<Truck> trucks;
  final List<Map<String, dynamic>> onlineDrivers;

  _DashboardData({required this.trips, required this.drivers, required this.trucks, required this.onlineDrivers});

  int get activeDriverCount => drivers.where((d) => d.isActive).length;

  Map<String, int> get statusCounts {
    final map = <String, int>{};
    for (final t in trips) {
      map[t.status] = (map[t.status] ?? 0) + 1;
    }
    return map;
  }

  static bool _isOpenStatus(String status) => status == 'ASSIGNED' || status == 'IN_TRANSIT';

  DateTime get _today {
    final now = DateTime.now();
    return DateTime.utc(now.year, now.month, now.day);
  }

  List<Trip> get dueToday {
    final today = _today;
    return trips.where((t) {
      if (t.scheduledAt == null || !_isOpenStatus(t.status)) return false;
      final d = t.scheduledAt!;
      return d.year == today.year && d.month == today.month && d.day == today.day;
    }).toList();
  }

  List<Trip> get dueTomorrow {
    final tomorrow = _today.add(const Duration(days: 1));
    return trips.where((t) {
      if (t.scheduledAt == null || !_isOpenStatus(t.status)) return false;
      final d = t.scheduledAt!;
      return d.year == tomorrow.year && d.month == tomorrow.month && d.day == tomorrow.day;
    }).toList();
  }

  List<Trip> get overdue {
    final today = _today;
    return trips.where((t) {
      if (t.scheduledAt == null || !_isOpenStatus(t.status)) return false;
      return t.scheduledAt!.isBefore(today);
    }).toList();
  }

  int get unclosedCount => trips.where((t) => !t.financiallyClosed).length;

  double get weeklyExpenseTotal => weeklyByCategory.values.fold(0, (sum, v) => sum + v);

  Map<String, double> get weeklyByCategory {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final totals = <String, double>{};
    for (final trip in trips) {
      for (final expense in trip.expenses) {
        if (expense.createdAt != null && expense.createdAt!.isBefore(cutoff)) continue;
        totals[expense.category] = (totals[expense.category] ?? 0) + expense.amount;
      }
    }
    return totals;
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon, this.onTap});
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: color.withValues(alpha: 0.15),
      label: Text('$label: $count', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _OnlineDriversCard extends StatelessWidget {
  const _OnlineDriversCard({required this.drivers});
  final List<Map<String, dynamic>> drivers;

  String _agoLabel(dynamic isoTime) {
    if (isoTime == null) return 'no location yet';
    final time = DateTime.tryParse(isoTime.toString());
    if (time == null) return 'no location yet';
    final diff = DateTime.now().toUtc().difference(time.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Online Drivers (${drivers.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (drivers.isEmpty)
              Text('No drivers online', style: TextStyle(color: Colors.grey.shade600))
            else
              for (final d in drivers)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 8, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(d['name']?.toString() ?? 'Driver')),
                      Text(
                        _agoLabel(d['lastLocation']?['at']),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.emptyLabel,
    required this.trips,
    required this.onTap,
    this.accentColor,
  });

  final String title;
  final String emptyLabel;
  final List<Trip> trips;
  final ValueChanged<Trip> onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: accentColor),
            ),
            const SizedBox(height: 8),
            if (trips.isEmpty)
              Text(emptyLabel, style: TextStyle(color: Colors.grey.shade600))
            else
              for (final trip in trips)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${trip.origin} → ${trip.destination}'),
                  subtitle: Text('Status: ${trip.status}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onTap(trip),
                ),
          ],
        ),
      ),
    );
  }
}
