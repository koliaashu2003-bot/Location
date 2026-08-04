import 'package:usage_stats/usage_stats.dart';

import '../models/location_data.dart';

/// Reads daily app usage via Android's UsageStatsManager.
///
/// Requires the PACKAGE_USAGE_STATS special permission, which the user must
/// grant manually in Settings → Apps → Special access → Usage access.
class ScreenTimeService {
  /// Returns whether usage-access permission has been granted.
  Future<bool> hasPermission() async {
    try {
      final granted = await UsageStats.checkUsagePermission();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system Usage Access settings screen so the user can grant it.
  Future<void> requestPermission() async {
    try {
      await UsageStats.grantUsagePermission();
    } catch (_) {
      // Ignore — the settings screen simply won't open on unsupported devices.
    }
  }

  /// Collects the top [limit] apps by foreground time since midnight today.
  Future<List<AppUsage>> getTodayTopApps({int limit = 10}) async {
    return (await getTodaySummary(limit: limit)).topApps;
  }

  /// Collects today's usage: the total across ALL apps (for total screen time)
  /// plus the top [limit] apps by foreground time. Total is summed over every
  /// app, not just the top ones, so "total screen time" is accurate.
  Future<ScreenTimeSummary> getTodaySummary({int limit = 10}) async {
    final granted = await hasPermission();
    if (!granted) return const ScreenTimeSummary(totalMinutes: 0, topApps: []);

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    try {
      final stats = await UsageStats.queryUsageStats(startOfDay, now);

      // Aggregate total foreground milliseconds per package.
      final Map<String, int> totals = {};
      for (final stat in stats) {
        final pkg = stat.packageName;
        if (pkg == null || pkg.isEmpty) continue;
        final foreground =
            int.tryParse(stat.totalTimeInForeground ?? '0') ?? 0;
        if (foreground <= 0) continue;
        totals[pkg] = (totals[pkg] ?? 0) + foreground;
      }

      // Total screen time across every app (in minutes).
      final totalMs =
          totals.values.fold<int>(0, (sum, ms) => sum + ms);
      final totalMinutes = (totalMs / 60000).round();

      final entries = totals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topApps = entries.take(limit).map((e) {
        return AppUsage(
          appName: _prettyName(e.key),
          durationMinutes: (e.value / 60000).round(),
        );
      }).where((a) => a.durationMinutes > 0).toList();

      return ScreenTimeSummary(totalMinutes: totalMinutes, topApps: topApps);
    } catch (_) {
      return const ScreenTimeSummary(totalMinutes: 0, topApps: []);
    }
  }

  /// Turns a package name like `com.google.android.youtube` into `Youtube`.
  String _prettyName(String packageName) {
    final parts = packageName.split('.');
    if (parts.isEmpty) return packageName;
    final last = parts.last;
    if (last.isEmpty) return packageName;
    return last[0].toUpperCase() + last.substring(1);
  }
}

/// Today's screen time: total across all apps plus the top apps breakdown.
class ScreenTimeSummary {
  final int totalMinutes;
  final List<AppUsage> topApps;

  const ScreenTimeSummary({
    required this.totalMinutes,
    required this.topApps,
  });
}
