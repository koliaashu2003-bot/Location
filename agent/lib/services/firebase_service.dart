import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/location_data.dart';

/// Persists location and screen time data to Cloud Firestore.
///
/// Layout:
///   locations/{deviceId}/history/{timestamp}
///   screentime/{deviceId}/daily/{date}
class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Saves a single location reading under the device's history sub-collection.
  Future<void> saveLocation(String deviceId, LocationData data) async {
    final docId = data.timestamp.toIso8601String();
    try {
      await _db
          .collection('locations')
          .doc(deviceId)
          .collection('history')
          .doc(docId)
          .set(data.toMap());

      // Keep a denormalised "latest" doc for quick dashboard reads.
      await _db.collection('locations').doc(deviceId).set(
        {
          'deviceName': data.deviceName,
          'lastLatitude': data.latitude,
          'lastLongitude': data.longitude,
          'lastBattery': data.battery,
          'lastUpdate': data.timestamp.toIso8601String(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Swallow errors so a failed write does not kill the background loop.
    }
  }

  /// Saves the daily screen time summary for a device.
  Future<void> saveScreenTime(
    String deviceId,
    String deviceName,
    List<AppUsage> apps,
  ) async {
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      await _db
          .collection('screentime')
          .doc(deviceId)
          .collection('daily')
          .doc(date)
          .set({
        'date': date,
        'deviceName': deviceName,
        'apps': apps.map((a) => a.toMap()).toList(),
        'totalMinutes':
            apps.fold<int>(0, (sum, a) => sum + a.durationMinutes),
      });

      await _db.collection('screentime').doc(deviceId).set(
        {'deviceName': deviceName, 'lastDate': date},
        SetOptions(merge: true),
      );
    } catch (_) {
      // Non-fatal.
    }
  }
}
