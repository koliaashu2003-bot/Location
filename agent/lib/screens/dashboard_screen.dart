import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/location_data.dart';
import '../services/local_store.dart';
import '../services/screen_time_service.dart';

/// On-device dashboard for the phone being tracked. Shows the last known
/// location, today's total screen time (hours), the per-app breakdown, and the
/// last few days of totals — all read from local phone storage (last 3 days).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _store = LocalStore();
  final _screenTime = ScreenTimeService();

  LocationData? _lastLocation;
  int _locationCount = 0;
  int _todayTotalMinutes = 0;
  List<AppUsage> _todayApps = [];
  List<ScreenTimeDay> _pastDays = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final locations = await _store.getLocations();
    final days = await _store.getScreenTimeDays();

    // Prefer a live screen-time read for today; fall back to stored.
    final liveSummary = await _screenTime.getTodaySummary(limit: 10);
    var todayTotal = liveSummary.totalMinutes;
    var todayApps = liveSummary.topApps;
    if (todayApps.isEmpty && days.isNotEmpty) {
      todayTotal = days.first.totalMinutes;
      todayApps = days.first.apps;
    }

    if (!mounted) return;
    setState(() {
      _lastLocation = locations.isEmpty ? null : locations.last;
      _locationCount = locations.length;
      _todayTotalMinutes = todayTotal;
      _todayApps = todayApps;
      _pastDays = days;
      _loading = false;
    });
  }

  String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _locationCard(),
                  const SizedBox(height: 14),
                  _todayScreenTimeCard(),
                  const SizedBox(height: 14),
                  _pastDaysCard(),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Data is stored on this phone (last '
                      '${LocalStore.retentionDays} days).',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _locationCard() {
    final loc = _lastLocation;
    return _card(
      icon: Icons.location_on,
      title: '📍 Location',
      child: loc == null
          ? const Text('No location recorded yet. Start tracking first.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.deviceName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Battery: ${loc.battery}%'),
                Text('Time: '
                    '${DateFormat('yyyy-MM-dd HH:mm').format(loc.timestamp)}'),
                Text('Points stored (3 days): $_locationCount'),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: loc.mapsUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Map link copied')),
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.map, size: 18, color: Colors.indigo),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          loc.mapsUrl,
                          style: const TextStyle(
                              color: Colors.indigo, fontSize: 12),
                        ),
                      ),
                      const Icon(Icons.copy, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _todayScreenTimeCard() {
    return _card(
      icon: Icons.phone_android,
      title: '📱 Screen time today',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total: ${_fmt(_todayTotalMinutes)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (_todayApps.isEmpty)
            const Text(
              'No screen-time data. Grant "Usage Access" in Settings.',
              style: TextStyle(color: Colors.grey),
            )
          else
            ..._todayApps.asMap().entries.map((e) {
              final i = e.key;
              final app = e.value;
              final maxM = _todayApps
                  .map((a) => a.durationMinutes)
                  .fold<int>(1, (m, v) => v > m ? v : m);
              final pct = (app.durationMinutes / maxM).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${i + 1}. ${app.appName}'),
                        Text(app.formattedDuration,
                            style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation(Colors.indigo),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _pastDaysCard() {
    final past = _pastDays.length > 1 ? _pastDays.sublist(1) : <ScreenTimeDay>[];
    return _card(
      icon: Icons.calendar_today,
      title: 'Previous days',
      child: past.isEmpty
          ? const Text('No earlier days stored yet.',
              style: TextStyle(color: Colors.grey))
          : Column(
              children: past
                  .map((d) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(d.date),
                            Text(_fmt(d.totalMinutes),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.indigo, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
