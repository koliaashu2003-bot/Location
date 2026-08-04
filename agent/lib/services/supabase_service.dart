import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/location_data.dart';

/// Runtime Supabase configuration (entered by the user, stored in prefs).
class SupabaseConfig {
  final String url; // e.g. https://abcd.supabase.co
  final String anonKey;
  final String email; // shared "family" account
  final String password;

  const SupabaseConfig({
    required this.url,
    required this.anonKey,
    required this.email,
    required this.password,
  });

  bool get isComplete =>
      url.isNotEmpty &&
      anonKey.isNotEmpty &&
      email.isNotEmpty &&
      password.isNotEmpty;
}

/// Talks to Supabase over its REST + Auth HTTP APIs.
///
/// The parent and every child phone sign in to the SAME family account
/// (email/password). Row Level Security ties every row to that account, so the
/// data is private to the family and readable only after signing in.
class SupabaseService {
  final SupabaseConfig cfg;
  String? _accessToken;

  SupabaseService(this.cfg);

  Uri _rest(String path) => Uri.parse('${cfg.url}/rest/v1/$path');

  Map<String, String> _headers() => {
        'apikey': cfg.anonKey,
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      };

  /// Signs in with the family account and caches the access token.
  Future<bool> signIn() async {
    if (!cfg.isComplete) return false;
    try {
      final res = await http.post(
        Uri.parse('${cfg.url}/auth/v1/token?grant_type=password'),
        headers: {'apikey': cfg.anonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({'email': cfg.email, 'password': cfg.password}),
      );
      if (res.statusCode == 200) {
        _accessToken = jsonDecode(res.body)['access_token'] as String?;
        return _accessToken != null;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> _ensureAuth() async {
    if (_accessToken != null) return true;
    return signIn();
  }

  // ---- Writes (child side) ----

  Future<void> insertLocation(String deviceId, LocationData d) async {
    if (!cfg.isComplete || !await _ensureAuth()) return;
    final body = jsonEncode({
      'device_id': deviceId,
      'device_name': d.deviceName,
      'latitude': d.latitude,
      'longitude': d.longitude,
      'battery': d.battery,
      'created_at': d.timestamp.toUtc().toIso8601String(),
    });
    await _postWithRetry('locations', body);
  }

  Future<void> upsertScreenTime(
    String deviceId,
    String deviceName,
    String date,
    int totalMinutes,
    List<AppUsage> apps,
  ) async {
    if (!cfg.isComplete || !await _ensureAuth()) return;
    // Keep one row per (device, date): delete today's then insert.
    await _delete('screen_time?device_id=eq.$deviceId&date=eq.$date');
    final body = jsonEncode({
      'device_id': deviceId,
      'device_name': deviceName,
      'date': date,
      'total_minutes': totalMinutes,
      'apps': apps.map((a) => a.toMap()).toList(),
    });
    await _postWithRetry('screen_time', body);
  }

  /// Deletes rows older than [days] for a device (client-side retention).
  Future<void> pruneOld(String deviceId, {int days = 3}) async {
    if (!cfg.isComplete || !await _ensureAuth()) return;
    final cutoff =
        DateTime.now().toUtc().subtract(Duration(days: days)).toIso8601String();
    await _delete('locations?device_id=eq.$deviceId&created_at=lt.$cutoff');
    final dateCutoff = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String()
        .substring(0, 10);
    await _delete('screen_time?device_id=eq.$deviceId&date=lt.$dateCutoff');
  }

  // ---- Reads (parent side) ----

  /// Returns the distinct devices seen, newest first: [{deviceId, deviceName}].
  Future<List<Map<String, String>>> fetchDevices() async {
    if (!cfg.isComplete || !await _ensureAuth()) return [];
    final rows = await _get(
        'locations?select=device_id,device_name,created_at&order=created_at.desc&limit=500');
    final seen = <String>{};
    final devices = <Map<String, String>>[];
    for (final r in rows) {
      final id = r['device_id'] as String?;
      if (id == null || seen.contains(id)) continue;
      seen.add(id);
      devices.add({
        'deviceId': id,
        'deviceName': (r['device_name'] as String?) ?? id,
      });
    }
    return devices;
  }

  Future<LocationData?> fetchLatestLocation(String deviceId) async {
    if (!cfg.isComplete || !await _ensureAuth()) return null;
    final rows = await _get(
        'locations?device_id=eq.$deviceId&order=created_at.desc&limit=1');
    if (rows.isEmpty) return null;
    final r = rows.first;
    return LocationData(
      latitude: (r['latitude'] as num).toDouble(),
      longitude: (r['longitude'] as num).toDouble(),
      battery: (r['battery'] as num?)?.toInt() ?? -1,
      timestamp:
          DateTime.tryParse(r['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      deviceName: (r['device_name'] as String?) ?? deviceId,
    );
  }

  /// Screen-time days for a device (newest first): each is
  /// {date, totalMinutes, apps:[AppUsage]}.
  Future<List<Map<String, dynamic>>> fetchScreenTime(String deviceId) async {
    if (!cfg.isComplete || !await _ensureAuth()) return [];
    final rows = await _get(
        'screen_time?device_id=eq.$deviceId&order=date.desc&limit=3');
    return rows.map((r) {
      final apps = ((r['apps'] as List?) ?? const [])
          .map((e) => AppUsage.fromMap((e as Map).cast<String, dynamic>()))
          .toList();
      return {
        'date': r['date'] as String? ?? '',
        'totalMinutes': (r['total_minutes'] as num?)?.toInt() ?? 0,
        'apps': apps,
      };
    }).toList();
  }

  // ---- low-level helpers ----

  Future<void> _postWithRetry(String path, String body) async {
    var res = await http.post(_rest(path),
        headers: {..._headers(), 'Prefer': 'return=minimal'}, body: body);
    if (res.statusCode == 401 && await signIn()) {
      await http.post(_rest(path),
          headers: {..._headers(), 'Prefer': 'return=minimal'}, body: body);
    }
  }

  Future<void> _delete(String pathWithQuery) async {
    try {
      var res = await http.delete(_rest(pathWithQuery), headers: _headers());
      if (res.statusCode == 401 && await signIn()) {
        await http.delete(_rest(pathWithQuery), headers: _headers());
      }
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _get(String pathWithQuery) async {
    try {
      var res = await http.get(_rest(pathWithQuery), headers: _headers());
      if (res.statusCode == 401 && await signIn()) {
        res = await http.get(_rest(pathWithQuery), headers: _headers());
      }
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as List;
        return decoded
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
