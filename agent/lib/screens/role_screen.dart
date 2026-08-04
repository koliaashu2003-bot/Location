import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';
import 'parent_screen.dart';

/// First page of the app. The user picks whether this phone belongs to a
/// Parent (who tracks and shares the app) or a Child (whose phone is tracked).
class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});

  Future<void> _choose(BuildContext context, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', role);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            role == 'parent' ? const ParentScreen() : const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.family_restroom, size: 72, color: Colors.indigo),
              const SizedBox(height: 12),
              const Text(
                'Family Safety',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Who is using this phone?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 40),
              _roleCard(
                context,
                icon: Icons.shield_outlined,
                title: "I'm a Parent",
                subtitle:
                    'Track your family and share the app with your children.',
                color: Colors.indigo,
                onTap: () => _choose(context, 'parent'),
              ),
              const SizedBox(height: 16),
              _roleCard(
                context,
                icon: Icons.phone_android,
                title: "I'm a Child",
                subtitle:
                    'This phone will be tracked. You grant permission to start.',
                color: Colors.teal,
                onTap: () => _choose(context, 'child'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
