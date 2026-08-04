import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/supabase_service.dart';

/// Lets the user enter the Supabase backend details. The SAME values go on the
/// parent phone (to read) and on every child phone (to write) — they all sign
/// in to one shared family account.
class SupabaseSetupScreen extends StatefulWidget {
  const SupabaseSetupScreen({super.key});

  @override
  State<SupabaseSetupScreen> createState() => _SupabaseSetupScreenState();
}

class _SupabaseSetupScreenState extends State<SupabaseSetupScreen> {
  final _url = TextEditingController();
  final _key = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  String? _testResult;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _url.text = prefs.getString('sb_url') ?? '';
      _key.text = prefs.getString('sb_key') ?? '';
      _email.text = prefs.getString('sb_email') ?? '';
      _password.text = prefs.getString('sb_password') ?? '';
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sb_url', _url.text.trim());
    await prefs.setString('sb_key', _key.text.trim());
    await prefs.setString('sb_email', _email.text.trim());
    await prefs.setString('sb_password', _password.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supabase settings saved')),
      );
    }
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final cfg = SupabaseConfig(
      url: _url.text.trim(),
      anonKey: _key.text.trim(),
      email: _email.text.trim(),
      password: _password.text.trim(),
    );
    final ok = cfg.isComplete && await SupabaseService(cfg).signIn();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = ok
          ? '✅ Connected and signed in successfully.'
          : '❌ Could not sign in. Check all four values.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supabase Setup'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Enter your Supabase project details and the shared family '
            'account. Use the SAME values on the parent phone and every child '
            'phone.',
          ),
          const SizedBox(height: 16),
          _field(_url, 'Project URL', 'https://xxxx.supabase.co'),
          _field(_key, 'Anon public key', 'eyJhbGci...', obscure: true),
          _field(_email, 'Family email', 'family@example.com'),
          _field(_password, 'Family password', '••••••••', obscure: true),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _test,
                  icon: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering),
                  label: const Text('Test'),
                ),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Text(_testResult!, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint,
      {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
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
