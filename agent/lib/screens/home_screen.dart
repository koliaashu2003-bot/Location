import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/location_service.dart';
import '../services/screen_time_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _deviceNameCtrl = TextEditingController();
  final _botTokenCtrl = TextEditingController();
  final _chatIdCtrl = TextEditingController();
  final _projectIdCtrl = TextEditingController();

  final _locationService = LocationService();
  final _screenTimeService = ScreenTimeService();

  bool _tracking = false;
  String? _lastLocationTime;
  bool _usageAccessGranted = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkUsageAccess();
  }

  @override
  void dispose() {
    _deviceNameCtrl.dispose();
    _botTokenCtrl.dispose();
    _chatIdCtrl.dispose();
    _projectIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _deviceNameCtrl.text = prefs.getString('deviceName') ?? '';
      _botTokenCtrl.text = prefs.getString('botToken') ?? '';
      _chatIdCtrl.text = prefs.getString('chatId') ?? '';
      _projectIdCtrl.text = prefs.getString('projectId') ?? '';
      _tracking = prefs.getBool('tracking') ?? false;
      _lastLocationTime = prefs.getString('lastLocationTime');
    });
  }

  Future<void> _checkUsageAccess() async {
    final granted = await _screenTimeService.hasPermission();
    if (mounted) setState(() => _usageAccessGranted = granted);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deviceName', _deviceNameCtrl.text.trim());
    await prefs.setString('botToken', _botTokenCtrl.text.trim());
    await prefs.setString('chatId', _chatIdCtrl.text.trim());
    await prefs.setString('projectId', _projectIdCtrl.text.trim());

    // Derive a stable deviceId from the device name if not already set.
    if (prefs.getString('deviceId') == null) {
      final id = _deviceNameCtrl.text
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      await prefs.setString(
          'deviceId', id.isEmpty ? 'device-${DateTime.now().millisecondsSinceEpoch}' : id);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  Future<bool> _requestPermissions() async {
    // Location permissions (foreground + background).
    try {
      await _locationService.ensurePermissions();
    } on LocationServiceException catch (e) {
      _showError(e.message);
      return false;
    }

    await Permission.locationAlways.request();
    await Permission.notification.request();

    // Battery optimization exemption so Android does not kill the service.
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    return true;
  }

  Future<void> _toggleTracking(bool value) async {
    if (value) {
      // Validate required fields.
      if (_deviceNameCtrl.text.trim().isEmpty ||
          _botTokenCtrl.text.trim().isEmpty ||
          _chatIdCtrl.text.trim().isEmpty) {
        _showError('Please enter device name, bot token and chat ID first.');
        return;
      }

      await _saveSettings();
      final ok = await _requestPermissions();
      if (!ok) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tracking', true);

      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
        await service.startService();
      }

      setState(() => _tracking = true);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tracking', false);

      final service = FlutterBackgroundService();
      service.invoke('stopService');

      setState(() => _tracking = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Safety'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusCard(),
            const SizedBox(height: 16),
            if (!_usageAccessGranted) _usageAccessBanner(),
            const SizedBox(height: 8),
            _textField(_deviceNameCtrl, 'Device Name', 'e.g. Aarav\'s Phone'),
            _textField(_botTokenCtrl, 'Telegram Bot Token',
                '123456:ABC-DEF...', obscure: true),
            _textField(_chatIdCtrl, 'Telegram Chat ID', 'e.g. 987654321'),
            _textField(_projectIdCtrl, 'Firebase Project ID',
                'e.g. family-tracker'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save),
              label: const Text('Save Settings'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard() {
    final lastTime = _lastLocationTime != null
        ? DateFormat('yyyy-MM-dd HH:mm')
            .format(DateTime.parse(_lastLocationTime!))
        : 'Never';
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _tracking ? 'Tracking Active' : 'Stopped',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _tracking ? Colors.green : Colors.grey,
                  ),
                ),
                Switch(
                  value: _tracking,
                  activeColor: Colors.green,
                  onChanged: _toggleTracking,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Last location sent: $lastTime'),
          ],
        ),
      ),
    );
  }

  Widget _usageAccessBanner() {
    return Card(
      color: Colors.amber.shade100,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Screen time permission not granted',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'To collect app usage, grant "Usage access" in Settings. '
              'Tap below, find this app, and enable it.',
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                await _screenTimeService.requestPermission();
                await _checkUsageAccess();
              },
              child: const Text('Open Usage Access Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    String hint, {
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
