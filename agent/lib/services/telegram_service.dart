import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/location_data.dart';

/// Sends messages directly to a Telegram bot via the Bot HTTP API.
///
/// No Cloud Functions are involved — the phone talks straight to
/// `https://api.telegram.org` which keeps everything on the free tier.
class TelegramService {
  final String botToken;
  final String chatId;

  TelegramService({required this.botToken, required this.chatId});

  bool get isConfigured => botToken.isNotEmpty && chatId.isNotEmpty;

  Uri _sendMessageUri() =>
      Uri.parse('https://api.telegram.org/bot$botToken/sendMessage');

  /// Sends a location update message.
  Future<bool> sendLocation(LocationData data) async {
    final time = DateFormat('yyyy-MM-dd HH:mm:ss').format(data.timestamp);
    final message = '📍 Location Update\n'
        "${data.deviceName}'s location:\n"
        '${data.mapsUrl}\n'
        'Battery: ${data.battery}%\n'
        'Time: $time';
    return _send(message);
  }

  /// Sends the daily screen time report.
  Future<bool> sendScreenTimeReport(
    String deviceName,
    List<AppUsage> apps,
  ) async {
    final buffer = StringBuffer()
      ..writeln('📱 Screen Time Report')
      ..writeln("$deviceName's usage today:");
    for (var i = 0; i < apps.length; i++) {
      final app = apps[i];
      buffer.writeln('${i + 1}. ${app.appName} - ${app.formattedDuration}');
    }
    return _send(buffer.toString().trimRight());
  }

  Future<bool> _send(String text) async {
    if (!isConfigured) return false;
    try {
      final response = await http.post(
        _sendMessageUri(),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'text': text,
          'disable_web_page_preview': false,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      // Network errors are non-fatal; the next cycle will retry.
      return false;
    }
  }
}
