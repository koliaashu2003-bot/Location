/// Simple model representing a single location reading collected by the agent.
class LocationData {
  final double latitude;
  final double longitude;
  final int battery;
  final DateTime timestamp;
  final String deviceName;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.battery,
    required this.timestamp,
    required this.deviceName,
  });

  /// Firestore document representation.
  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'battery': battery,
      'timestamp': timestamp.toIso8601String(),
      'deviceName': deviceName,
    };
  }

  factory LocationData.fromMap(Map<String, dynamic> map) {
    return LocationData(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      battery: (map['battery'] as num).toInt(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      deviceName: map['deviceName'] as String? ?? 'Unknown',
    );
  }

  /// Google Maps link used inside Telegram messages.
  String get mapsUrl =>
      'https://www.google.com/maps?q=$latitude,$longitude';
}

/// Model representing a single app's daily usage.
class AppUsage {
  final String appName;
  final int durationMinutes;

  AppUsage({required this.appName, required this.durationMinutes});

  Map<String, dynamic> toMap() {
    return {
      'appName': appName,
      'durationMinutes': durationMinutes,
    };
  }

  factory AppUsage.fromMap(Map<String, dynamic> map) {
    return AppUsage(
      appName: map['appName'] as String? ?? 'Unknown',
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
    );
  }

  /// Human friendly duration, e.g. "2h 15m".
  String get formattedDuration {
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
