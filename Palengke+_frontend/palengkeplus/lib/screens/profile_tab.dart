import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/leaf_mark.dart';
import '../services/api_service.dart';

class ProfileTab extends StatefulWidget {
  final VoidCallback onSettings;
  const ProfileTab({super.key, required this.onSettings});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final settings = {
    'Price Alerts': true,
    'Weekly Report': true,
    'Budget Warning': true,
  };
  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
      children: [
        const Text(
          'MY ACCOUNT',
          style: TextStyle(
            color: green,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Text(
          '👤 Profile',
          style: TextStyle(
            color: navy,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: navy,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 27,
                backgroundColor: Color(0xFF10A39B),
                child: Text('👩‍🍳', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consumer access',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Public browsing · no account required',
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Official DA-4A CALABARZON reference data',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              LeafMark(
                size: 32,
                color: Colors.white.withValues(alpha: 0.18),
                rotation: 0.35,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _settingsCard(
          'Alert Preferences',
          '🔔',
          settings.entries
              .map(
                (entry) => SwitchListTile(
                  title: Text(entry.key),
                  subtitle: Text(
                    _settingDescription(entry.key),
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 12,
                    ),
                  ),
                  value: entry.value,
                  activeThumbColor: green,
                  onChanged: (value) =>
                      setState(() => settings[entry.key] = value),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        _settingsCard('Preferences', '⚙️', [
          ListTile(
            leading: const Icon(Icons.dns_outlined, color: navy),
            title: const Text('Server connection'),
            subtitle: Text(
              ApiService.activeBaseUrl,
              style: const TextStyle(fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.onSettings,
          ),
          const ListTile(
            leading: Icon(Icons.language, color: navy),
            title: Text('Language'),
            trailing: Text('Filipino / English'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline, color: navy),
            title: Text('App Version'),
            trailing: Text('v1.0.0'),
          ),
        ]),
      ],
    ),
  );
  Widget _settingsCard(String title, String icon, List<Widget> children) =>
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ...children,
          ],
        ),
      );
  String _settingDescription(String key) => switch (key) {
    'Price Alerts' ||
    'Price Surge Alert' ||
    'Price Drop Alert' => 'When prices move ±5%',
    'Weekly Report' || 'Weekly Summary' => 'Market summary every Sunday',
    'Budget Warning' => 'When planned spend reaches 80%',
    'Forecast Updates' => 'Daily ARIMA forecast refreshes',
    _ => 'Market updates are shown in Palengke+.',
  };
}

