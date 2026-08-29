import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import '../services/background_location_service.dart';
import '../services/tracking_notification_service.dart';
import '../widgets/confirm_logout.dart';
import '../widgets/app_brand_title.dart';
import 'trip_detail_screen.dart';
import 'trip_form_screen.dart';
import 'hitachi_jobs_screen.dart';

class DriverTripsScreen extends StatefulWidget {
  const DriverTripsScreen({super.key, required this.apiService});
  final ApiService apiService;

  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen> {
  late Future<List<Trip>> _tripsFuture;
  String? _myDriverId;
  bool _isOnline = false;
  bool _isTogglingOnline = false;
  bool _isLoadingProfile = true;
  Timer? _locationTimer;
  final _searchController = TextEditingController();
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _refreshTrips();
    _loadProfile();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _searchController.dispose();
    // Intentionally not cancelling the tracking notification here: this
    // screen is disposed on logout too, and Duty Status (server-side) stays
    // Online across app restarts, so the reminder should persist with it.
    super.dispose();
  }

  /// Retries on failure because the API sleeps when idle and its first request
  /// can be slow or fail outright. Without a retry, one failed call left
  /// _myDriverId null forever, which hid the Create Trip button until the app
  /// was force-restarted — the refresh button doesn't reload the profile.
  Future<void> _loadProfile({int attempt = 0}) async {
    if (mounted) setState(() => _isLoadingProfile = true);
    try {
      final profile = await widget.apiService.fetchMyDriverProfile();
      if (!mounted) return;
      setState(() {
        _myDriverId = profile['id']?.toString();
        _isOnline = profile['isOnline'] == true;
        _isLoadingProfile = false;
      });
      if (_isOnline) {
        if (kIsWeb) {
          _startLocationTimer();
        } else {
          await BackgroundLocationService.instance.start();
        }
      }
    } catch (_) {
      if (attempt < 2) {
        await Future.delayed(Duration(seconds: 3 * (attempt + 1)));
        if (!mounted) return;
        return _loadProfile(attempt: attempt + 1);
      }
      // Out of retries — leave the button enabled so tapping it can try again,
      // rather than silently disabling the screen's main action.
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  void _refreshTrips() {
    setState(() {
      _tripsFuture = widget.apiService.fetchTrips();
    });
  }

  Future<void> _openTripDetail(Trip trip) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TripDetailScreen(apiService: widget.apiService, trip: trip, isOnline: _isOnline),
      ),
    );
    if (changed == true) _refreshTrips();
  }

  Future<void> _createTrip() async {
    // The profile may have failed to load (usually the API waking from idle).
    // Retry on demand instead of leaving a button that does nothing when tapped.
    if (_myDriverId == null) {
      await _loadProfile();
      if (!mounted) return;
      if (_myDriverId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load your profile. Check your connection and try again.')),
        );
        return;
      }
    }
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Go online to create a trip')),
      );
      return;
    }
    final created = await Navigator.push<Trip>(
      context,
      MaterialPageRoute(
        builder: (_) => TripFormScreen(apiService: widget.apiService, selfAssignDriverId: _myDriverId),
      ),
    );
    if (created != null) _refreshTrips();
  }

  Future<Position?> _getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<void> _sendPing() async {
    try {
      final position = await _getCurrentPosition();
      if (position == null) return;
      await widget.apiService.pingLocation(position.latitude, position.longitude);
    } catch (_) {
      // Skip a failed ping silently; the next 60s tick will retry.
    }
  }

  void _startLocationTimer() {
    _locationTimer?.cancel();
    _sendPing();
    _locationTimer = Timer.periodic(const Duration(seconds: 60), (_) => _sendPing());
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() => _isTogglingOnline = true);
    try {
      if (value) {
        final position = await _getCurrentPosition();
        if (position == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is needed to go online')),
          );
        }
        await widget.apiService.goOnline();
        if (kIsWeb) {
          _startLocationTimer();
        } else {
          // Permission first: on Android 13+ the foreground service's mandatory
          // notification is suppressed without POST_NOTIFICATIONS, and a
          // foreground service with no visible notification gets killed.
          await TrackingNotificationService.instance.requestPermission();
          await BackgroundLocationService.instance.start();
        }
      } else {
        _locationTimer?.cancel();
        if (!kIsWeb) await BackgroundLocationService.instance.stop();
        await widget.apiService.goOffline();
      }
      if (!mounted) return;
      setState(() => _isOnline = value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isTogglingOnline = false);
    }
  }

  List<Trip> _applyFilters(List<Trip> trips) {
    final query = _searchController.text.trim().toLowerCase();
    return trips.where((t) {
      if (_statusFilter != 'ALL' && t.status != _statusFilter) return false;
      if (query.isEmpty) return true;
      return t.displayTitle.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppBrandTitle(title: 'My Trips'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HitachiJobsScreen(apiService: widget.apiService)),
            ),
            tooltip: 'Hitachi Jobs',
            icon: const Icon(Icons.construction),
          ),
          IconButton(
            onPressed: () {
              _refreshTrips();
              _loadProfile(); // also recover the profile, not just the trip list
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () async {
              if (!await confirmLogout(context)) return;
              if (!mounted) return;
              _locationTimer?.cancel();
              if (!kIsWeb) await BackgroundLocationService.instance.stop();
              await widget.apiService.clearToken();
              if (!mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Icon(Icons.circle, size: 10, color: _isOnline ? Colors.green : Colors.grey),
                const SizedBox(width: 6),
                Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                _isTogglingOnline
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Switch(value: _isOnline, onChanged: _toggleOnline),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search trips',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final status in const ['ALL', 'ASSIGNED', 'IN_TRANSIT', 'DELIVERED', 'FAILED'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(status == 'ALL' ? 'All' : status),
                        selected: _statusFilter == status,
                        onSelected: (_) => setState(() => _statusFilter = status),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: FutureBuilder<List<Trip>>(
              future: _tripsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }
                final trips = _applyFilters(snapshot.data ?? []);
                if (trips.isEmpty) {
                  return const Center(child: Text('No trips match'));
                }

                final currentTrips = trips.where((t) => t.status == 'ASSIGNED' || t.status == 'IN_TRANSIT').toList();
                final completedTrips = trips.where((t) => t.status == 'DELIVERED' || t.status == 'FAILED').toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    if (currentTrips.isNotEmpty) ...[
                      const Text('Current Trip', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      for (final trip in currentTrips)
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              trip.displayTitle,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _StatusBadge(status: trip.status),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openTripDetail(trip),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                    if (completedTrips.isNotEmpty) ...[
                      const Text('Completed Trips', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      for (final trip in completedTrips)
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(trip.displayTitle),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: _StatusBadge(status: trip.status),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openTripDetail(trip),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
      // Always rendered: hiding it on a failed profile load made the screen's
      // main action vanish with no way back short of restarting the app.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoadingProfile ? null : _createTrip,
        icon: _isLoadingProfile
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.add),
        label: const Text('Create Trip'),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  Color get _color {
    switch (status) {
      case 'ASSIGNED':
        return Colors.blue;
      case 'IN_TRANSIT':
        return Colors.orange;
      case 'DELIVERED':
        return Colors.green;
      case 'FAILED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
