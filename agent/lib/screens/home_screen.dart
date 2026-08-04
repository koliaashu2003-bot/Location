import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/location_service.dart';
import '../services/screen_time_service.dart';
import 'dashboard_screen.dart';
import 'supabase_setup_screen.dart';

/// Child-side screen: set up once, then tap "Grant Access" to start.
/// Stopping is locked behind a Parent PIN so only the parent/owner can stop it.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _deviceNameCtrl = TextEditingController();
  final _botTokenCtrl = TextEditingController();
  final _chatIdCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

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
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _deviceNameCtrl.text = prefs.getString('deviceName') ?? '';
      _botTokenCtrl.text = prefs.getString('botToken') ?? '';
      _chatIdCtrl.text = prefs.getString('chatId') ?? '';
      _pinCtrl.text = prefs.getString('parentPin') ?? '';
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
    await prefs.setString('parentPin', _pinCtrl.text.trim());

    if (prefs.getString('deviceId') == null) {
      final id = _deviceNameCtrl.text
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      await prefs.setString('deviceId',
          id.isEmpty ? 'device-${DateTime.now().millisecondsSinceEpoch}' : id);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  Future<bool> _requestPermissions() async {
    try {
      await _locationService.ensurePermissions();
    } on LocationServiceException catch (e) {
      _showError(e.message);
      return false;
    }

    await Permission.locationAlways.request();
    await Permission.notification.request();

    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    return true;
  }

  /// Starts tracking. One-way for the child — there is no "stop" here without
  /// the Parent PIN.
  Future<void> _grantAndStart() async {
    if (_deviceNameCtrl.text.trim().isEmpty ||
        _botTokenCtrl.text.trim().isEmpty ||
        _chatIdCtrl.text.trim().isEmpty) {
      _showError('Enter device name, bot token and chat ID first.');
      return;
    }
    if (_pinCtrl.text.trim().length < 4) {
      _showError('Set a Parent PIN (at least 4 digits) so only you can stop it.');
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
  }

  /// Stopping requires the Parent PIN — the child cannot stop on their own.
  Future<void> _stopWithPin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('parentPin') ?? '';

    if (!mounted) return;
    final entered = await showDialog<String>(
      context: context,
      builder: (context) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Enter Parent PIN to stop'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Parent PIN'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Stop'),
            ),
          ],
        );
      },
    );

    if (entered == null) return; // cancelled
    if (entered != savedPin) {
      _showError('Wrong PIN. Only the parent can stop tracking.');
      return;
    }

    await prefs.setBool('tracking', false);
    FlutterBackgroundService().invoke('stopService');
    setState(() => _tracking = false);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _openDashboard() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Child · Family Safety'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard),
            tooltip: 'Dashboard',
            onPressed: _openDashboard,
          ),
        ],
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
            _textField(_pinCtrl, 'Parent PIN (needed to stop tracking)',
                'e.g. 1234', obscure: true, number: true),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _tracking
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SupabaseSetupScreen()),
                      ),
              icon: const Icon(Icons.cloud_outlined),
              label: const Text('Supabase setup (optional, for dashboard)'),
            ),
            const SizedBox(height: 8),
            if (!_tracking)
              ElevatedButton.icon(
                onPressed: _grantAndStart,
                icon: const Icon(Icons.verified_user),
                label: const Text('Grant Access & Start Tracking'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: const Text('Save Settings'),
                style: OutlinedButton.styleFrom(
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
              children: [
                Icon(
                  _tracking ? Icons.shield : Icons.shield_outlined,
                  color: _tracking ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  _tracking ? 'Tracking Active' : 'Not Tracking',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _tracking ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Last location sent: $lastTime'),
            if (_tracking) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openDashboard,
                      icon: const Icon(Icons.dashboard),
                      label: const Text('Dashboard'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _stopWithPin,
                      icon: const Icon(Icons.lock),
                      label: const Text('Stop (PIN)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
    bool number = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        enabled: !_tracking, // lock config while tracking is active
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
