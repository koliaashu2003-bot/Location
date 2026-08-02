import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';

import '../models/location_data.dart';

/// Wraps geolocation and battery reads into a single call that returns a
/// [LocationData] snapshot for the current device.
class LocationService {
  final Battery _battery = Battery();

  /// Ensures location services are on and permission is granted.
  ///
  /// Returns null-safe [LocationPermission]. Throws a descriptive
  /// [LocationServiceException] when tracking cannot proceed so callers can
  /// surface a message to the user.
  Future<void> ensurePermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceException(
          'Location services are disabled. Please enable GPS.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationServiceException('Location permission was denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
          'Location permission is permanently denied. Enable it in Settings.');
    }
  }

  /// Reads the current position and battery level.
  ///
  /// Returns null if the reading fails (e.g. permission revoked mid-run) so
  /// the background loop can skip a cycle without crashing.
  Future<LocationData?> getCurrentLocation(String deviceName) async {
    try {
      await ensurePermissions();
    } catch (_) {
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      int batteryLevel;
      try {
        batteryLevel = await _battery.batteryLevel;
      } catch (_) {
        batteryLevel = -1;
      }

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        battery: batteryLevel,
        timestamp: DateTime.now(),
        deviceName: deviceName,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Thrown when location tracking cannot start.
class LocationServiceException implements Exception {
  final String message;
  const LocationServiceException(this.message);

  @override
  String toString() => message;
}
