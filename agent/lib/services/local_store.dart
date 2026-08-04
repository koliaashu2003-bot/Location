import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/location_data.dart';

/// Stores the last few days of location and screen-time data directly on the
/// phone (SharedPreferences, JSON encoded). No server or database needed.
///
/// Everything older than [retentionDays] is pruned on every read/write, so the
/// device only ever keeps the most recent window of data.
class LocalStore {
  static const String _locKey = 'local_locations';
  static const String _stKey = 'local_screentime';
  static const int retentionDays = 3;

  // ---- Location ----

  Future<void> addLocation(LocationData data) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _readList(prefs, _locKey);
    list.add(data.toMap());
    _pruneByTimestamp(list, 'timestamp');
    await prefs.setString(_locKey, jsonEncode(list));
  }

  Future<List<LocationData>> getLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _readList(prefs, _locKey);
    _pruneByTimestamp(list, 'timestamp');
    final locations = list.map((m) => LocationData.fromMap(m)).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return locations;
  }

  Future<LocationData?> getLastLocation() async {
    final locations = await getLocations();
    return locations.isEmpty ? null : locations.last;
  }

  // ---- Screen time (one entry per day) ----

  Future<void> saveScreenTime(
    String date,
    int totalMinutes,
    List<AppUsage> apps,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _readList(prefs, _stKey)
      ..removeWhere((m) => m['date'] == date); // upsert today's entry
    list.add({
      'date': date,
      'totalMinutes': totalMinutes,
      'apps': apps.map((a) => a.toMap()).toList(),
    });
    _pruneByDate(list);
    await prefs.setString(_stKey, jsonEncode(list));
  }

  Future<List<ScreenTimeDay>> getScreenTimeDays() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _readList(prefs, _stKey);
    _pruneByDate(list);
    final days = list
        .map((m) => ScreenTimeDay(
              date: m['date'] as String? ?? '',
              totalMinutes: (m['totalMinutes'] as num?)?.toInt() ?? 0,
              apps: ((m['apps'] as List?) ?? const [])
                  .map((e) =>
                      AppUsage.fromMap((e as Map).cast<String, dynamic>()))
                  .toList(),
            ))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // newest first
    return days;
  }

  // ---- helpers ----

  List<Map<String, dynamic>> _readList(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _pruneByTimestamp(List<Map<String, dynamic>> list, String field) {
    final cutoff = DateTime.now().subtract(const Duration(days: retentionDays));
    list.removeWhere((m) {
      final ts = DateTime.tryParse(m[field] as String? ?? '');
      return ts == null || ts.isBefore(cutoff);
    });
  }

  void _pruneByDate(List<Map<String, dynamic>> list) {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: retentionDays - 1));
    list.removeWhere((m) {
      final d = DateTime.tryParse('${m['date'] ?? ''}T00:00:00');
      return d == null || d.isBefore(cutoff);
    });
  }
}

/// One day's stored screen-time summary.
class ScreenTimeDay {
  final String date;
  final int totalMinutes;
  final List<AppUsage> apps;

  ScreenTimeDay({
    required this.date,
    required this.totalMinutes,
    required this.apps,
  });
}
