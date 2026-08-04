import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'parent_dashboard_screen.dart';
import 'supabase_setup_screen.dart';

/// Parent-side screen. The parent does not track from this phone — everything
/// arrives in their Telegram. This screen helps them share the app with their
/// children (up to 4 phones) and explains the one-time setup.
class ParentScreen extends StatelessWidget {
  const ParentScreen({super.key});

  /// Direct, login-free download link to the agent APK (published as a
  /// GitHub Release). Send this to each child's phone.
  static const String apkLink =
      'https://github.com/koliaashu2003-bot/Location/releases/download/agent-apk/family-safety.apk';

  void _copy(BuildContext context, String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            icon: Icons.info_outline,
            title: 'How it works',
            child: const Text(
              'Your children\'s location and screen time arrive in your '
              'Telegram. You do not track from this phone — install the app on '
              'each child\'s phone (up to 4), choose "Child" there, enter your '
              'Telegram bot details, and they tap Allow to start.',
            ),
          ),
          _sectionCard(
            icon: Icons.dashboard_customize,
            title: 'Family Dashboard (Supabase)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'For an in-app dashboard of every child\'s location and '
                  'screen time, set up the free Supabase backend (same details '
                  'on this phone and each child phone).',
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SupabaseSetupScreen()),
                  ),
                  icon: const Icon(Icons.settings),
                  label: const Text('Supabase setup'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const ParentDashboardScreen()),
                  ),
                  icon: const Icon(Icons.dashboard),
                  label: const Text('Open Family Dashboard'),
                ),
              ],
            ),
          ),
          _sectionCard(
            icon: Icons.link,
            title: '1. Share the app with your child',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Send this download link to the child\'s phone and open it '
                  'in Chrome to install the app:',
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const SelectableText(
                    apkLink,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => _copy(context, apkLink, 'App link'),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy app link'),
                ),
              ],
            ),
          ),
          _sectionCard(
            icon: Icons.tune,
            title: '2. On each child phone',
            child: const Text(
              '• Install the app from the link.\n'
              '• Open it and choose "I\'m a Child".\n'
              '• Enter a Device Name (e.g. "Aarav\'s Phone"), your Telegram '
              'Bot Token and Chat ID.\n'
              '• Tap Start and allow Location, Notifications, Battery and '
              'Usage Access.\n\n'
              'Repeat on up to 4 phones — give each a different Device Name. '
              'They all report to your one Telegram chat.',
            ),
          ),
          _sectionCard(
            icon: Icons.verified_user_outlined,
            title: 'Consent',
            child: const Text(
              'The child\'s phone shows a permanent "Family Safety Active" '
              'notification while tracking, so the person always knows it is '
              'on. Only track people who know and agree, and follow your local '
              'laws.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.indigo, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
