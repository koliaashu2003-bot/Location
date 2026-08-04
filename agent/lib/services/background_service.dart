import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_service.dart';
import 'location_service.dart';
import 'screen_time_service.dart';
import 'telegram_service.dart';

/// Notification channel used by the persistent foreground notification.
const String notificationChannelId = 'family_safety_channel';
const int notificationId = 888;

/// How often to collect and send a location update.
const Duration locationInterval = Duration(minutes: 15);

/// Configures the background service singleton. Called once from main().
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const androidChannel = AndroidNotificationChannel(
    notificationChannelId,
    'Family Safety',
    description: 'Keeps family location tracking active.',
    importance: Importance.low,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(androidChannel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: notificationChannelId,
      initialNotificationTitle: 'Family Safety Active',
      initialNotificationContent: 'Location tracking is running.',
      foregroundServiceNotificationId: notificationId,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

/// Entry point that runs inside the background isolate.
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Firebase must be re-initialised inside the background isolate, which runs
  // in its own memory space with no access to the UI isolate's auth session.
  try {
    await Firebase.initializeApp();
    // Sign in anonymously here too — this isolate performs the Firestore
    // writes, so it needs its own authenticated session to pass the rules.
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (_) {
    // Already initialised or config missing — continue; Firestore writes
    // will simply no-op if unavailable.
  }

  // Allow the UI to stop the service.
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  final locationService = LocationService();
  final firebaseService = FirebaseService();
  final screenTimeService = ScreenTimeService();

  // Track the last day we sent a screen-time report to avoid duplicates.
  String? lastScreenTimeDate;

  Future<void> tick() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final tracking = prefs.getBool('tracking') ?? false;
    if (!tracking) return;

    final deviceName = prefs.getString('deviceName') ?? 'Family Member';
    final deviceId = prefs.getString('deviceId') ?? 'default-device';
    final botToken = prefs.getString('botToken') ?? '';
    final chatId = prefs.getString('chatId') ?? '';

    final telegram = TelegramService(botToken: botToken, chatId: chatId);

    // --- Location update ---
    final location = await locationService.getCurrentLocation(deviceName);
    if (location != null) {
      await telegram.sendLocation(location);
      await firebaseService.saveLocation(deviceId, location);

      await prefs.setString(
          'lastLocationTime', location.timestamp.toIso8601String());

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Family Safety Active',
          content:
              'Last update: ${_formatTime(location.timestamp)} • Battery ${location.battery}%',
        );
      }
    }

    // --- Daily screen-time report at 9 PM ---
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';
    if (now.hour == 21 && lastScreenTimeDate != todayKey) {
      lastScreenTimeDate = todayKey;
      final summary = await screenTimeService.getTodaySummary(limit: 10);
      if (summary.topApps.isNotEmpty) {
        await telegram.sendScreenTimeReport(
          deviceName,
          summary.topApps,
          totalMinutes: summary.totalMinutes,
        );
        await firebaseService.saveScreenTime(
            deviceId, deviceName, summary.topApps);
      }
    }
  }

  // Run once immediately so the user sees activity right away.
  await tick();

  // Repeat every 15 minutes.
  Timer.periodic(locationInterval, (timer) async {
    await tick();
  });
}

String _formatTime(DateTime t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
