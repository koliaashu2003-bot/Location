import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/location_data.dart';
import '../services/supabase_service.dart';

/// Parent's REMOTE dashboard. Reads every child device's data from Supabase
/// (location + screen time), so the parent sees it from their own phone.
class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  SupabaseService? _service;
  List<Map<String, String>> _devices = [];
  String? _selectedId;

  LocationData? _location;
  List<Map<String, dynamic>> _screenDays = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final cfg = SupabaseConfig(
      url: prefs.getString('sb_url') ?? '',
      anonKey: prefs.getString('sb_key') ?? '',
      email: prefs.getString('sb_email') ?? '',
      password: prefs.getString('sb_password') ?? '',
    );
    if (!cfg.isComplete) {
      setState(() {
        _loading = false;
        _error = 'Supabase is not set up. Fill in the Supabase fields on the '
            'Parent screen first.';
      });
      return;
    }
    _service = SupabaseService(cfg);
    final ok = await _service!.signIn();
    if (!ok) {
      setState(() {
        _loading = false;
        _error = 'Could not sign in to Supabase. Check the URL, key, email '
            'and password.';
      });
      return;
    }
    await _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _loading = true);
    final devices = await _service!.fetchDevices();
    if (!mounted) return;
    setState(() {
      _devices = devices;
      _selectedId ??= devices.isNotEmpty ? devices.first['deviceId'] : null;
      _loading = false;
    });
    if (_selectedId != null) await _loadDevice(_selectedId!);
  }

  Future<void> _loadDevice(String deviceId) async {
    setState(() => _loading = true);
    final loc = await _service!.fetchLatestLocation(deviceId);
    final days = await _service!.fetchScreenTime(deviceId);
    if (!mounted) return;
    setState(() {
      _location = loc;
      _screenDays = days;
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
        title: const Text('Family Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDevices,
          ),
        ],
      ),
      body: _error != null
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(_error!)),
            )
          : _loading && _devices.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _devices.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No devices yet. Once a child phone starts tracking '
                          'with the same Supabase account, it appears here.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : _body(),
    );
  }

  Widget _body() {
    return RefreshIndicator(
      onRefresh: () async {
        if (_selectedId != null) await _loadDevice(_selectedId!);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Text('Device: ',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedId,
                  items: _devices
                      .map((d) => DropdownMenuItem(
                            value: d['deviceId'],
                            child: Text(d['deviceName'] ?? d['deviceId']!),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedId = v);
                    _loadDevice(v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _locationCard(),
          const SizedBox(height: 14),
          _screenTimeCard(),
        ],
      ),
    );
  }

  Widget _locationCard() {
    final loc = _location;
    return _card(
      title: '📍 Location',
      child: loc == null
          ? const Text('No location yet.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Battery: ${loc.battery}%'),
                Text('Time: '
                    '${DateFormat('yyyy-MM-dd HH:mm').format(loc.timestamp)}'),
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
                        child: Text(loc.mapsUrl,
                            style: const TextStyle(
                                color: Colors.indigo, fontSize: 12)),
                      ),
                      const Icon(Icons.copy, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _screenTimeCard() {
    if (_screenDays.isEmpty) {
      return _card(
        title: '📱 Screen time',
        child: const Text('No screen-time data yet.'),
      );
    }
    final today = _screenDays.first;
    final apps = (today['apps'] as List).cast<AppUsage>();
    final maxM = apps.isEmpty
        ? 1
        : apps
            .map((a) => a.durationMinutes)
            .fold<int>(1, (m, v) => v > m ? v : m);
    return _card(
      title: '📱 Screen time (${today['date']})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total: ${_fmt(today['totalMinutes'] as int)}',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...apps.asMap().entries.map((e) {
            final i = e.key;
            final app = e.value;
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
                      valueColor:
                          const AlwaysStoppedAnimation(Colors.indigo),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (_screenDays.length > 1) ...[
            const Divider(height: 24),
            const Text('Previous days',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ..._screenDays.skip(1).map((d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(d['date'] as String),
                      Text(_fmt(d['totalMinutes'] as int),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
