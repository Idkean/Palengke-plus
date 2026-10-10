import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../widgets/leaf_mark.dart';
import '../services/api_service.dart';
import 'home_tab.dart';
import 'analytics_tab.dart';
import 'budget_tab.dart';
import 'markets_tab.dart';
import 'profile_tab.dart';

class PalengkePlusApp extends StatelessWidget {
  const PalengkePlusApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Palengke+ DA Reference',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        primary: navy,
        secondary: accent,
        surface: Colors.white,
      ),
      textTheme: GoogleFonts.nunitoTextTheme(),
      dividerColor: line,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE8F1E7),
        height: 66,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? navy
                : Colors.black54,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: green, width: 1.5),
        ),
      ),
    ),
    builder: (context, child) => ColoredBox(
      color: canvas,
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamilyFallback: [
            'Noto Color Emoji',
            'Segoe UI Emoji',
            'Apple Color Emoji',
          ],
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448),
            child: Stack(
              children: [
                Positioned(
                  left: -24,
                  top: 180,
                  child: LeafMark(
                    size: 76,
                    color: green.withValues(alpha: 0.035),
                    rotation: -0.55,
                  ),
                ),
                Positioned(
                  right: -24,
                  bottom: 125,
                  child: LeafMark(
                    size: 82,
                    color: green.withValues(alpha: 0.03),
                    rotation: 0.6,
                  ),
                ),
                child!,
              ],
            ),
          ),
        ),
      ),
    ),
    home: const Shell(),
  );
}


class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int selectedTab = 0;
  final api = ApiService();
  String role = 'consumer'; // consumer | vendor
  String vendorUser = '';
  @override
  void initState(){super.initState(); _loadRole();}
  Future<void> _loadRole() async {
    final p=await SharedPreferences.getInstance();
    setState((){role=p.getString('palengke_role')??'consumer'; vendorUser=p.getString('palengke_vendor_user')??'';});
  }
  Future<void> _setRole(String r) async {
    final p=await SharedPreferences.getInstance();
    await p.setString('palengke_role', r);
    setState(()=>role=r);
  }

  void openServerSettings() {
    final controller = TextEditingController(text: ApiService.activeBaseUrl);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Server connection'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _serverOption(dialogContext, '☁️ Cloud (Render)', ApiService.cloudUrl, isCloud: true),
              const Divider(),
              _serverOption(dialogContext, 'USB / desktop', ApiService.usbUrl),
              _serverOption(dialogContext, 'Wi-Fi phone', ApiService.wifiUrl),
              _serverOption(dialogContext, 'Android emulator', ApiService.emulatorUrl),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Custom API URL', hintText: 'https://.../api'),
              ),
              const SizedBox(height: 8),
              Text('Active: ${ApiService.activeBaseUrl}', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await ApiService.setActiveBaseUrl(controller.text);
              }
              if (!dialogContext.mounted || !mounted) return;
              Navigator.pop(dialogContext);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _serverOption(BuildContext context, String label, String url, {bool isCloud = false}) =>
      ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(isCloud ? Icons.cloud_done_outlined : Icons.dns_outlined, color: isCloud ? green : navy),
        title: Text(label, style: TextStyle(fontWeight: isCloud ? FontWeight.bold : FontWeight.normal)),
        subtitle: Text(url, style: const TextStyle(fontSize: 11)),
        onTap: () async {
          await ApiService.setActiveBaseUrl(url);
          if (!context.mounted || !mounted) return;
          Navigator.pop(context);
          setState(() {});
        },
      );

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(api: api, onSettings: openServerSettings),
      AnalyticsTab(api: api),
      MarketsTab(api: api, isVendor: role=='vendor', vendorUser: vendorUser),
      BudgetTab(api: api),
      ProfileTab(onSettings: openServerSettings, role: role, vendorUser: vendorUser, onRoleChanged: (r,u) async {
        final p=await SharedPreferences.getInstance();
        await p.setString('palengke_role', r);
        await p.setString('palengke_vendor_user', u);
        setState(()=>{role=r, vendorUser=u});
      }),
    ];
    return Scaffold(
      body: IndexedStack(index: selectedTab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) => setState(() => selectedTab = index),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE6F2F4),
        destinations: const [
          NavigationDestination(
            icon: Text('🏠', style: TextStyle(fontSize: 18)),
            selectedIcon: Text('🏠', style: TextStyle(fontSize: 18)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Text('📈', style: TextStyle(fontSize: 18)),
            selectedIcon: Text('📈', style: TextStyle(fontSize: 18)),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Text('🛒', style: TextStyle(fontSize: 18)),
            selectedIcon: Text('🛒', style: TextStyle(fontSize: 18)),
            label: 'Markets',
          ),
          NavigationDestination(
            icon: Text('💰', style: TextStyle(fontSize: 18)),
            selectedIcon: Text('💰', style: TextStyle(fontSize: 18)),
            label: 'Budget',
          ),
          NavigationDestination(
            icon: Text('👤', style: TextStyle(fontSize: 18)),
            selectedIcon: Text('👤', style: TextStyle(fontSize: 18)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

